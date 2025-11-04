import Foundation
import Combine
import CloudKit
import SwiftUI

class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()
    
    private let container = CKContainer.default()
    let database: CKDatabase
    
    @Published var isSignedIn = false
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var isCloudSyncEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isCloudSyncEnabled, forKey: "isCloudSyncEnabled")
        }
    }
    // 熔断控制：在服务器多次拒绝后暂时跳过CloudKit操作
    @Published var isCloudKitTemporarilyDisabled: Bool = false
    private var rejectionCount: Int = 0
    private var circuitOpenUntil: Date?
    private let circuitThreshold: Int = 3
    private let circuitOpenDuration: TimeInterval = 30 * 60 // 30分钟
    
    private init() {
        self.database = container.privateCloudDatabase
        // 默认开启云同步，如果用户之前没有设置过
        if UserDefaults.standard.object(forKey: "isCloudSyncEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "isCloudSyncEnabled")
        }
        self.isCloudSyncEnabled = UserDefaults.standard.bool(forKey: "isCloudSyncEnabled")
        checkAccountStatus()
    }

    // MARK: - 熔断辅助
    private var isCircuitOpen: Bool {
        if let until = circuitOpenUntil {
            if Date() < until { return true }
            // 熔断期过后自动恢复
            circuitOpenUntil = nil
            isCloudKitTemporarilyDisabled = false
            rejectionCount = 0
        }
        return false
    }

    private func recordServerRejection() {
        rejectionCount += 1
        if rejectionCount >= circuitThreshold && !isCircuitOpen {
            circuitOpenUntil = Date().addingTimeInterval(circuitOpenDuration)
            isCloudKitTemporarilyDisabled = true
            let minutes = Int(circuitOpenDuration / 60)
            print("CloudKit请求被服务器连续拒绝，开启熔断：未来 \(minutes) 分钟跳过云操作")
        } else {
            print("CloudKit服务器拒绝计数：\(rejectionCount)/\(circuitThreshold)")
        }
    }

    private func clearRejectionCountersOnSuccess() {
        if rejectionCount > 0 || isCloudKitTemporarilyDisabled {
            print("CloudKit操作成功，重置熔断状态")
        }
        rejectionCount = 0
        circuitOpenUntil = nil
        isCloudKitTemporarilyDisabled = false
    }
    
    // 检查iCloud账户状态
    func checkAccountStatus() {
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                switch status {
                case .available:
                    self?.isSignedIn = true
                    print("iCloud账户状态: 可用")
                case .noAccount, .restricted, .couldNotDetermine:
                    self?.isSignedIn = false
                    let statusText = (status == .noAccount ? "无账户" : (status == .restricted ? "受限" : "无法确定"))
                    print("iCloud账户状态: 不可用 (\(statusText))")
                case .temporarilyUnavailable:
                    self?.isSignedIn = false
                    print("iCloud账户状态: 暂时不可用")
                @unknown default:
                    self?.isSignedIn = false
                    print("iCloud账户状态: 未知")
                }
            }
        }
    }
    
    // 保存单个日程到CloudKit
    func saveScheduleItem(_ item: ScheduleItem) async throws {
        guard isCloudSyncEnabled else {
            return // 如果云同步被禁用，跳过保存
        }
        
        guard isSignedIn else {
            throw CloudKitError.notSignedIn
        }
        
        if isCircuitOpen {
            print("CloudKit熔断中，跳过单条保存")
            return
        }
        
        let record = item.toCKRecord()
        
        do {
            let savedRecord = try await database.save(record)
            print("成功保存日程到CloudKit: \(savedRecord.recordID)")
            clearRejectionCountersOnSuccess()
        } catch {
            if let ckError = error as? CKError, ckError.code == .serverRejectedRequest {
                print("保存日程到CloudKit失败(服务器拒绝): \(describeCKError(error)))")
                recordServerRejection()
            } else {
                print("保存日程到CloudKit失败: \(describeCKError(error)))")
            }
            throw error
        }
    }
    
    // 批量保存日程到CloudKit
    func saveScheduleItems(_ items: [ScheduleItem]) async throws {
        guard isCloudSyncEnabled else {
            return // 如果云同步被禁用，跳过保存
        }
        
        guard isSignedIn else {
            throw CloudKitError.notSignedIn
        }
        
        if isCircuitOpen {
            print("CloudKit熔断中，跳过批量保存")
            return
        }
        
        let records = items.map { $0.toCKRecord() }
        
        do {
            let savedRecords = try await database.modifyRecords(saving: records, deleting: [])
            print("成功批量保存 \(savedRecords.saveResults.count) 个日程到CloudKit")
            clearRejectionCountersOnSuccess()
        } catch {
            // 如果批量保存被服务器拒绝或参数无效，尝试逐条保存以增加成功率
            if let ckError = error as? CKError, (ckError.code == .serverRejectedRequest || ckError.code == .invalidArguments || ckError.code == .partialFailure) {
                print("批量保存日程到CloudKit失败(降级逐条保存): \(describeCKError(error)))")
                var successCount = 0
                var failureCount = 0
                for record in records {
                    do {
                        _ = try await database.save(record)
                        successCount += 1
                    } catch {
                        failureCount += 1
                        print("单条保存失败: \(describeCKError(error)))")
                        if let singleErr = error as? CKError, singleErr.code == .serverRejectedRequest {
                            recordServerRejection()
                        }
                    }
                }
                print("逐条保存完成：成功 \(successCount)，失败 \(failureCount)")
                // 若全部失败，则抛出原始错误；否则视为整体成功
                if successCount == 0 {
                    // 针对服务器拒绝的常见原因提供提示
                    print("CloudKit保存被服务器拒绝：请确认两端使用同一 iCloud 账号，处于同一 CloudKit 环境（开发/生产），并在 CloudKit 控制台为容器 \(self.container) 部署 ScheduleItem 记录类型及其字段到对应环境")
                    recordServerRejection()
                    throw ckError
                } else {
                    clearRejectionCountersOnSuccess()
                }
            } else {
                print("批量保存日程到CloudKit失败: \(describeCKError(error)))")
                throw error
            }
        }
    }
    
    // 从CloudKit获取所有日程
    func fetchAllScheduleItems() async throws -> [ScheduleItem] {
        guard isCloudSyncEnabled else {
            return [] // 如果云同步被禁用，返回空数组
        }
        
        guard isSignedIn else {
            throw CloudKitError.notSignedIn
        }
        
        if isCircuitOpen {
            print("CloudKit熔断中，跳过查询并返回空列表")
            return []
        }
        
        let query = CKQuery(recordType: "ScheduleItem", predicate: NSPredicate(format: "isDeleted == NO"))
        // 优先带排序；若服务器因缺少索引拒绝，则回退到无排序查询
        query.sortDescriptors = [NSSortDescriptor(key: "modifiedDate", ascending: false)]
        
        do {
            let (matchResults, _) = try await database.records(matching: query)
            var scheduleItems: [ScheduleItem] = []
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    if let item = ScheduleItem.fromCKRecord(record) {
                        scheduleItems.append(item)
                    }
                case .failure(let error):
                    print("获取记录失败: \(error.localizedDescription)")
                }
            }
            clearRejectionCountersOnSuccess()
            return scheduleItems
        } catch {
            if let ckError = error as? CKError, (ckError.code == .serverRejectedRequest || ckError.code == .invalidArguments) {
                // 回退到无排序查询，避免因索引缺失导致首次启动报错
                do {
                    let fallbackQuery = CKQuery(recordType: "ScheduleItem", predicate: NSPredicate(value: true))
                    let (matchResults, _) = try await database.records(matching: fallbackQuery)
                    // 本地过滤 isDeleted == false，并按 modifiedDate 排序
                    var scheduleItems: [ScheduleItem] = []
                    for (_, result) in matchResults {
                        switch result {
                        case .success(let record):
                            if let item = ScheduleItem.fromCKRecord(record), item.isDeleted == false {
                                scheduleItems.append(item)
                            }
                        case .failure(let error):
                            print("获取记录失败: \(error.localizedDescription)")
                        }
                    }
                    // 本地排序，避免索引问题
                    scheduleItems.sort { (a, b) in
                        a.modifiedDate > b.modifiedDate
                    }
                    clearRejectionCountersOnSuccess()
                    return scheduleItems
                } catch {
                    if let innerErr = error as? CKError, innerErr.code == .serverRejectedRequest {
                        print("从CloudKit获取日程失败(回退查询): \(describeCKError(error)) —— 无查询索引，返回空列表并继续")
                        recordServerRejection()
                        return []
                    } else {
                        print("从CloudKit获取日程失败(回退查询): \(describeCKError(error))")
                        throw error
                    }
                }
            } else {
                print("从CloudKit获取日程失败: \(describeCKError(error))")
                throw error
            }
        }
    }
    
    // 删除CloudKit中的日程（软删除）
    func deleteScheduleItem(_ item: ScheduleItem) async throws {
        guard isSignedIn else {
            throw CloudKitError.notSignedIn
        }
        
        // 检查云同步开关
        guard isCloudSyncEnabled else {
            return // 如果云同步被禁用，直接返回成功
        }
        
        if isCircuitOpen {
            print("CloudKit熔断中，跳过删除(软删除)请求")
            return
        }
        
        var updatedItem = item
        updatedItem.isDeleted = true
        updatedItem.modifiedDate = Date()
        
        // 添加重试机制
        var retryCount = 0
        let maxRetries = 3
        
        while retryCount < maxRetries {
            do {
                try await saveScheduleItem(updatedItem)
                return // 成功则退出
            } catch {
                retryCount += 1
                print("CloudKit删除失败 (尝试 \(retryCount)/\(maxRetries)): \(error.localizedDescription)")
                
                if retryCount >= maxRetries {
                    // 转换为更具体的错误类型
                    if let ckError = error as? CKError {
                        switch ckError.code {
                        case .networkUnavailable, .networkFailure:
                            throw CloudKitError.networkUnavailable
                        case .quotaExceeded:
                            throw CloudKitError.quotaExceeded
                        default:
                            throw CloudKitError.unknown(error)
                        }
                    } else {
                        throw CloudKitError.unknown(error)
                    }
                }
                
                // 等待后重试
                try await Task.sleep(nanoseconds: UInt64(retryCount * 1_000_000_000)) // 1秒 * 重试次数
            }
        }
    }
    
    // 同步本地数据到CloudKit
    func syncToCloud(_ items: [ScheduleItem]) async throws {
        await MainActor.run {
            self.isSyncing = true
        }
        
        defer {
            Task { @MainActor in
                self.isSyncing = false
                self.lastSyncDate = Date()
            }
        }
        
        try await saveScheduleItems(items)
    }
    
    // 从CloudKit同步数据到本地
    func syncFromCloud() async throws -> [ScheduleItem] {
        await MainActor.run {
            self.isSyncing = true
        }
        
        defer {
            Task { @MainActor in
                self.isSyncing = false
                self.lastSyncDate = Date()
            }
        }
        
        return try await fetchAllScheduleItems()
    }
    
    // 双向同步
    func performFullSync(localItems: [ScheduleItem]) async throws -> [ScheduleItem] {
        guard isSignedIn else {
            throw CloudKitError.notSignedIn
        }
        
        await MainActor.run {
            self.isSyncing = true
        }
        
        defer {
            Task { @MainActor in
                self.isSyncing = false
                self.lastSyncDate = Date()
            }
        }
        
        // 1. 获取云端数据
        let cloudItems = try await fetchAllScheduleItems()
        
        // 2. 合并本地和云端数据
        let mergedItems = mergeScheduleItems(local: localItems, cloud: cloudItems)
        
        // 3. 将合并后的数据保存到云端
        try await saveScheduleItems(mergedItems)
        
        return mergedItems
    }
    
    // 合并本地和云端数据
    private func mergeScheduleItems(local: [ScheduleItem], cloud: [ScheduleItem]) -> [ScheduleItem] {
        var mergedItems: [UUID: ScheduleItem] = [:]
        
        // 先添加本地数据
        for item in local {
            mergedItems[item.id] = item
        }
        
        // 然后处理云端数据
        for cloudItem in cloud {
            if let localItem = mergedItems[cloudItem.id] {
                // 如果本地也有这个项目，比较修改时间
                if cloudItem.modifiedDate > localItem.modifiedDate {
                    mergedItems[cloudItem.id] = cloudItem
                }
            } else {
                // 如果本地没有，直接添加云端数据
                mergedItems[cloudItem.id] = cloudItem
            }
        }
        
        // 过滤掉已删除的项目
        return Array(mergedItems.values).filter { !$0.isDeleted }
    }
}

// MARK: - CloudKit错误类型
enum CloudKitError: LocalizedError {
    case notSignedIn
    case networkUnavailable
    case quotaExceeded
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "未登录iCloud账户"
        case .networkUnavailable:
            return "网络不可用"
        case .quotaExceeded:
            return "iCloud存储空间不足"
        case .unknown(let error):
            return "未知错误: \(error.localizedDescription)"
        }
    }
}

// MARK: - 错误描述辅助
private func describeCKError(_ error: Error) -> String {
    if let ckError = error as? CKError {
        var parts: [String] = []
        parts.append("\(ckError.localizedDescription) (CKError: \(ckError.code.rawValue))")
        let userInfo = ckError.userInfo
        if !userInfo.isEmpty {
            // 简化输出，避免过长日志：只列出关键键
            var infoSummary: [String] = []
            for (key, value) in userInfo {
                let v = String(describing: value)
                // 只截取前120字符，避免巨长内容影响日志可读性
                let clipped = v.count > 120 ? String(v.prefix(120)) + "…" : v
                infoSummary.append("\(key)=\(clipped)")
            }
            parts.append("[userInfo: \(infoSummary.joined(separator: ", "))]")
        }
        return parts.joined(separator: " ")
    }
    return error.localizedDescription
}
