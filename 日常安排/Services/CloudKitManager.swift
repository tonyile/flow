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
    
    private init() {
        self.database = container.privateCloudDatabase
        // 默认开启云同步，如果用户之前没有设置过
        if UserDefaults.standard.object(forKey: "isCloudSyncEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "isCloudSyncEnabled")
        }
        self.isCloudSyncEnabled = UserDefaults.standard.bool(forKey: "isCloudSyncEnabled")
        checkAccountStatus()
    }
    
    // 检查iCloud账户状态
    func checkAccountStatus() {
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                switch status {
                case .available:
                    self?.isSignedIn = true
                case .noAccount, .restricted, .couldNotDetermine:
                    self?.isSignedIn = false
                case .temporarilyUnavailable:
                    self?.isSignedIn = false
                @unknown default:
                    self?.isSignedIn = false
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
        
        let record = item.toCKRecord()
        
        do {
            let savedRecord = try await database.save(record)
            print("成功保存日程到CloudKit: \(savedRecord.recordID)")
        } catch {
            print("保存日程到CloudKit失败: \(error)")
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
        
        let records = items.map { $0.toCKRecord() }
        
        do {
            let savedRecords = try await database.modifyRecords(saving: records, deleting: [])
            print("成功批量保存 \(savedRecords.saveResults.count) 个日程到CloudKit")
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
                    }
                }
                print("逐条保存完成：成功 \(successCount)，失败 \(failureCount)")
                // 若全部失败，则抛出原始错误；否则视为整体成功
                if successCount == 0 {
                    throw ckError
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
        
        var query = CKQuery(recordType: "ScheduleItem", predicate: NSPredicate(format: "isDeleted == NO"))
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
            return scheduleItems
        } catch {
            if let ckError = error as? CKError, (ckError.code == .serverRejectedRequest || ckError.code == .invalidArguments) {
                // 回退到无排序查询，避免因索引缺失导致首次启动报错
                do {
                    // 使用 TRUEPREDICATE，避免任何字段索引依赖；再在本地过滤/排序
                    let fallbackQuery = CKQuery(recordType: "ScheduleItem", predicate: NSPredicate(value: true))
                    let (fallbackResults, _) = try await database.records(matching: fallbackQuery)
                    var items: [ScheduleItem] = []
                    for (_, result) in fallbackResults {
                        switch result {
                        case .success(let record):
                            if let item = ScheduleItem.fromCKRecord(record) {
                                items.append(item)
                            }
                        case .failure(let error):
                            print("获取记录失败(回退查询): \(error.localizedDescription)")
                        }
                    }
                    // 本地过滤未删除项，并按 modifiedDate 降序
                    let filteredSorted = items
                        .filter { !$0.isDeleted }
                        .sorted { ($0.modifiedDate ?? Date.distantPast) > ($1.modifiedDate ?? Date.distantPast) }
                    return filteredSorted
                } catch {
                    if let ckError2 = error as? CKError, (ckError2.code == .serverRejectedRequest || ckError2.code == .invalidArguments) {
                        // 若回退仍因索引缺失被拒绝，则静默降级返回空列表，避免用户弹窗
                        print("从CloudKit获取日程失败(回退查询): \(describeCKError(error)) —— 无查询索引，返回空列表并继续")
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
        return "\(ckError.localizedDescription) (CKError: \(ckError.code.rawValue))"
    }
    return error.localizedDescription
}
