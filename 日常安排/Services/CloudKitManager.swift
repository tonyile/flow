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
            print("批量保存日程到CloudKit失败: \(error)")
            throw error
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
        
        let query = CKQuery(recordType: "ScheduleItem", predicate: NSPredicate(format: "isDeleted == NO"))
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
                    print("获取记录失败: \(error)")
                }
            }
            
            return scheduleItems
        } catch {
            print("从CloudKit获取日程失败: \(error)")
            throw error
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
