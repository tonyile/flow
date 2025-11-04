import Foundation
import SwiftUI
import CloudKit
import Combine

class FlowStore: ObservableObject {
    static let shared = FlowStore()
    
    @Published var flowItems: [FlowItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let cloudKitManager = CloudKitManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadFlowItems()
        setupCloudKitSync()
    }
    
    // MARK: - Data Loading
    private func loadFlowItems() {
        isLoading = true
        
        // 从本地存储加载
        if let data = UserDefaults.standard.data(forKey: "flowItems"),
           let items = try? JSONDecoder().decode([FlowItem].self, from: data) {
            self.flowItems = items.filter { !$0.isDeleted }
        }
        
        // 从CloudKit同步
        syncFromCloudKit()
    }
    
    private func saveToLocal() {
        if let data = try? JSONEncoder().encode(flowItems) {
            UserDefaults.standard.set(data, forKey: "flowItems")
        }
    }
    
    // MARK: - CRUD Operations
    func addFlowItem(_ item: FlowItem) {
        item.updateModifiedDate()
        flowItems.append(item)
        saveToLocal()
        
        // 同步到CloudKit
        syncToCloudKit(item)
    }
    
    func updateFlowItem(_ item: FlowItem) {
        item.updateModifiedDate()
        if let index = flowItems.firstIndex(where: { $0.id == item.id }) {
            flowItems[index] = item
            saveToLocal()
            
            // 同步到CloudKit
            syncToCloudKit(item)
        }
    }
    
    func deleteItem(_ item: FlowItem) {
        // 从本地删除
        flowItems.removeAll { $0.id == item.id }
        saveToLocal()
        
        // 从CloudKit删除
        if let recordID = item.recordID {
            Task {
                do {
                    try await cloudKitManager.database.deleteRecord(withID: recordID)
                } catch {
                    await MainActor.run {
                        self.errorMessage = "删除失败: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    func deleteFlowItems(with ids: [UUID]) {
        for id in ids {
            if let item = flowItems.first(where: { $0.id == id }) {
                deleteItem(item)
            }
        }
    }
    
    // MARK: - Query Methods
    func flowItemsForDate(_ date: Date) -> [FlowItem] {
        let calendar = Calendar.current
        return flowItems.filter { item in
            calendar.isDate(item.date, inSameDayAs: date)
        }.sorted { $0.date < $1.date }
    }
    
    func flowItemsForDateRange(from startDate: Date, to endDate: Date) -> [FlowItem] {
        return flowItems.filter { item in
            item.date >= startDate && item.date <= endDate
        }.sorted { $0.date < $1.date }
    }
    
    func flowItemsByType(_ type: FlowType) -> [FlowItem] {
        return flowItems.filter { $0.type == type }.sorted { $0.date > $1.date }
    }
    
    func flowItemsWithPerson(_ person: String) -> [FlowItem] {
        return flowItems.filter { item in
            item.relatedPeople.contains(person)
        }.sorted { $0.date > $1.date }
    }
    
    func flowItemsWithItem(_ itemName: String) -> [FlowItem] {
        return flowItems.filter { item in
            item.relatedItems.contains(itemName)
        }.sorted { $0.date > $1.date }
    }
    
    func searchFlowItems(_ searchText: String) -> [FlowItem] {
        guard !searchText.isEmpty else { return flowItems }
        
        let lowercasedSearch = searchText.lowercased()
        return flowItems.filter { item in
            item.title.lowercased().contains(lowercasedSearch) ||
            item.notes.lowercased().contains(lowercasedSearch) ||
            item.relatedPeople.contains { $0.lowercased().contains(lowercasedSearch) } ||
            item.relatedItems.contains { $0.lowercased().contains(lowercasedSearch) } ||
            item.tags.contains { $0.lowercased().contains(lowercasedSearch) }
        }.sorted { $0.date > $1.date }
    }
    
    // MARK: - Statistics
    func totalAmountByType(_ type: FlowType, in dateRange: ClosedRange<Date>? = nil) -> Double {
        var items = flowItemsByType(type)
        
        if let range = dateRange {
            items = items.filter { range.contains($0.date) }
        }
        
        return items.compactMap { $0.amount }.reduce(0, +)
    }
    
    func monthlyStatistics(for date: Date) -> [FlowType: Double] {
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: date)?.start ?? date
        let endOfMonth = calendar.dateInterval(of: .month, for: date)?.end ?? date
        
        var statistics: [FlowType: Double] = [:]
        
        for type in FlowType.allCases {
            statistics[type] = totalAmountByType(type, in: startOfMonth...endOfMonth)
        }
        
        return statistics
    }
    
    // MARK: - CloudKit Sync
    private func setupCloudKitSync() {
        // 监听CloudKit状态变化
        cloudKitManager.$isSignedIn
            .sink { [weak self] isSignedIn in
                if isSignedIn {
                    self?.syncFromCloudKit()
                }
            }
            .store(in: &cancellables)
    }
    
    private func syncToCloudKit(_ item: FlowItem) {
        guard cloudKitManager.isSignedIn else { return }
        
        Task {
            do {
                // 使用CloudKitManager的database属性
                let record = item.toCKRecord()
                let savedRecord = try await cloudKitManager.database.save(record)
                await MainActor.run {
                    item.recordID = savedRecord.recordID
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "同步失败: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func syncFromCloudKit() {
        // 必须登录且开启云同步
        guard cloudKitManager.isSignedIn, cloudKitManager.isCloudSyncEnabled else {
            isLoading = false
            return
        }
        
        Task {
            do {
                let predicate = NSPredicate(value: true)
                var query = CKQuery(recordType: "FlowItem", predicate: predicate)
                // 优先尝试带排序的查询（需要 CloudKit 上配置相应查询索引）
                query.sortDescriptors = [NSSortDescriptor(key: "modifiedDate", ascending: false)]
                
                var (matchResults, _) = try await cloudKitManager.database.records(matching: query)
                
                var cloudItems: [FlowItem] = []
                for (_, result) in matchResults {
                    switch result {
                    case .success(let record):
                        let item = FlowItem.fromCKRecord(record)
                        cloudItems.append(item)
                    case .failure(let error):
                        // 获取记录失败，记录错误信息
                        print("CloudKit获取记录失败: \(error.localizedDescription)")
                        break
                    }
                }
                
                await MainActor.run {
                    self.isLoading = false
                    self.mergeCloudKitData(cloudItems)
                }
            } catch {
                // 如果服务器因缺少查询索引或参数问题拒绝请求，回退到无排序查询
                if let ckError = error as? CKError, (ckError.code == .serverRejectedRequest || ckError.code == .invalidArguments) {
                    do {
                        let predicate = NSPredicate(value: true)
                        let fallbackQuery = CKQuery(recordType: "FlowItem", predicate: predicate)
                        let (fallbackResults, _) = try await cloudKitManager.database.records(matching: fallbackQuery)
                        var cloudItems: [FlowItem] = []
                        for (_, result) in fallbackResults {
                            switch result {
                            case .success(let record):
                                let item = FlowItem.fromCKRecord(record)
                                cloudItems.append(item)
                            case .failure(let error):
                                print("CloudKit获取记录失败(回退查询): \(error.localizedDescription)")
                            }
                        }
                        await MainActor.run {
                            self.isLoading = false
                            self.mergeCloudKitData(cloudItems)
                        }
                    } catch {
                        // 对初次失败的索引/参数错误不弹窗，避免首次进入页面打扰用户
                        if let ckError2 = error as? CKError, shouldSuppressAlert(for: ckError2.code) {
                            await MainActor.run {
                                self.isLoading = false
                            }
                        } else {
                            await MainActor.run {
                                self.isLoading = false
                                self.errorMessage = "同步失败: \(self.describeCKError(error))"
                            }
                        }
                    }
                } else {
                    // 其它错误保留提示
                    await MainActor.run {
                        self.isLoading = false
                        self.errorMessage = "同步失败: \(self.describeCKError(error))"
                    }
                }
            }
        }
    }

    // 更清晰的错误描述（包含 CKError 数值编码）
    private func describeCKError(_ error: Error) -> String {
        if let ckError = error as? CKError {
            return "\(ckError.localizedDescription) (CKError: \(ckError.code.rawValue))"
        }
        return error.localizedDescription
    }
    
    private func shouldSuppressAlert(for code: CKError.Code) -> Bool {
        // 视为非致命的错误：服务器拒绝请求（常见：缺少查询索引）、参数无效
        return code == .serverRejectedRequest || code == .invalidArguments
    }
    
    private func mergeCloudKitData(_ cloudItems: [FlowItem]) {
        var updatedItems = flowItems
        
        for cloudItem in cloudItems {
            if cloudItem.isDeleted {
                // 删除本地项目
                updatedItems.removeAll { $0.recordID == cloudItem.recordID }
            } else {
                // 更新或添加项目
                if let index = updatedItems.firstIndex(where: { $0.recordID == cloudItem.recordID }) {
                    // 比较修改时间，使用最新的
                    if cloudItem.modifiedDate > updatedItems[index].modifiedDate {
                        updatedItems[index] = cloudItem
                    }
                } else {
                    // 新项目
                    updatedItems.append(cloudItem)
                }
            }
        }
        
        self.flowItems = updatedItems.filter { !$0.isDeleted }
        saveToLocal()
    }
    
    // MARK: - Utility Methods
    func getAllRelatedPeople() -> [String] {
        let allPeople = flowItems.flatMap { $0.relatedPeople }
        return Array(Set(allPeople)).sorted()
    }
    
    func getAllRelatedItems() -> [String] {
        let allItems = flowItems.flatMap { $0.relatedItems }
        return Array(Set(allItems)).sorted()
    }
    
    func getAllTags() -> [String] {
        let allTags = flowItems.flatMap { $0.tags }
        return Array(Set(allTags)).sorted()
    }
    
    func clearError() {
        errorMessage = nil
    }
}