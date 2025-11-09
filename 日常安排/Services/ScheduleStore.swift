import Foundation
import SwiftUI
import Combine
import CloudKit

@MainActor
class ScheduleStore: ObservableObject {
    static let shared = ScheduleStore()
    
    @Published var scheduleItems: [ScheduleItem] = []
    @Published var isLoading = true
    @Published var errorMessage: String?
    
    private let saveKey = "SavedSchedules"
    private let cloudKitManager = CloudKitManager.shared
    private let notificationManager = NotificationManager.shared
    
    private init() {
        loadSchedules()
    }
    
    // MARK: - 数据加载
    
    func loadSchedules() {
        loadFromLocal()
        // 在 SwiftUI 预览环境中跳过 CloudKit 同步，避免预览构建超时
        // Xcode 会在预览时设置环境变量 XCODE_RUNNING_FOR_PREVIEWS=1
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return
        }

        Task {
            await syncWithCloudKit()
        }
    }
    
    private func loadFromLocal() {
        if let data = UserDefaults.standard.data(forKey: saveKey) {
            if let decodedItems = try? JSONDecoder().decode([ScheduleItem].self, from: data) {
                print("📱 成功加载 \(decodedItems.count) 个日程项目")
                DispatchQueue.main.async {
                    self.scheduleItems = decodedItems
                    self.isLoading = false
                }
                return
            } else {
                print("📱 ❌ 数据解码失败")
            }
        }
        
        // 如果没有本地数据，创建默认示例数据
        DispatchQueue.main.async {
            self.seedSampleData()
            self.isLoading = false
            print("📱 已创建示例数据")
        }
    }
    
    private func saveToLocal() {
        print("💾 开始保存到本地，当前日程数量: \(scheduleItems.count)")
        if let encoded = try? JSONEncoder().encode(scheduleItems) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
            print("💾 成功保存到UserDefaults")
        } else {
            print("💾 错误：编码失败")
        }
    }
    
    // MARK: - CloudKit同步
    
    @MainActor
    private func syncWithCloudKit() async {
        guard cloudKitManager.isCloudSyncEnabled else {
            print("云同步已禁用，跳过同步")
            return
        }
        
        guard cloudKitManager.isSignedIn else {
            print("未登录iCloud，跳过同步")
            return
        }
        
        do {
            let syncedItems = try await cloudKitManager.performFullSync(localItems: scheduleItems)
            scheduleItems = syncedItems
            saveToLocal()
            
            // 重新安排所有通知
            await scheduleAllNotifications()
            
        } catch {
            if let ckError = error as? CKError, (ckError.code == .serverRejectedRequest || ckError.code == .invalidArguments) {
                // 由于查询索引缺失导致的请求被拒绝，视为可忽略错误：记录日志但不弹窗
                print("CloudKit同步失败(可忽略): \(ckError) — 建议在 CloudKit 控制台为 ScheduleItem 添加查询索引")
            } else {
                errorMessage = "同步失败: \(error.localizedDescription)"
                print("CloudKit同步失败: \(error)")
            }
        }
    }
    
    // 手动同步
    func manualSync() {
        Task {
            await syncWithCloudKit()
        }
    }
    
    // MARK: - 重置功能（用于测试）
    
    func resetToDefaults() {
        // 清除本地存储
        UserDefaults.standard.removeObject(forKey: saveKey)
        
        // 清除当前数据
        scheduleItems.removeAll()
        
        // 重新创建默认数据
        seedSampleData()
    }
    
    // MARK: - 日程管理
    
    func addSchedule(_ item: ScheduleItem) {
        var newItem = item
        newItem.modifiedDate = Date()
        newItem.notificationId = UUID().uuidString
        
        print("📝 添加日程: \(newItem.title) - isRecurring: \(newItem.isRecurring) - isFestival: \(newItem.isFestival) - isYearlyRecurring: \(newItem.isYearlyRecurring)")
        
        // 检查重复项
        if let existingItem = findDuplicateSchedule(newItem) {
            handleDuplicateSchedule(newItem, existingItem: existingItem)
        } else {
            if newItem.isRecurring {
                addRecurringSchedule(newItem)
            } else {
                scheduleItems.append(newItem)
            }
        }
        
        saveToLocal()
        
        // 安排通知
        Task {
            notificationManager.scheduleNotification(for: newItem)
        }
        
        // 同步到CloudKit
        Task {
            if cloudKitManager.isCloudSyncEnabled {
                do {
                    try await cloudKitManager.saveScheduleItem(newItem)
                } catch {
                    print("CloudKit保存失败: \(error)")
                }
            }
        }
    }
    
    // MARK: - 重复任务检测和处理
    
    private func findDuplicateSchedule(_ newItem: ScheduleItem) -> ScheduleItem? {
        let calendar = Calendar.current
        
        for existingItem in scheduleItems {
            // 跳过自己
            if existingItem.id == newItem.id {
                continue
            }
            
            // 统一日程检测：相同名称和时间点，且在同一天
            if existingItem.title == newItem.title {
                let existingTimeComponents = calendar.dateComponents([.hour, .minute], from: existingItem.startTime)
                let newTimeComponents = calendar.dateComponents([.hour, .minute], from: newItem.startTime)
                
                if existingTimeComponents.hour == newTimeComponents.hour &&
                   existingTimeComponents.minute == newTimeComponents.minute &&
                   calendar.isDate(existingItem.startTime, inSameDayAs: newItem.startTime) {
                    return existingItem
                }
            }
            
            // 重复检测逻辑
            // 检查标题是否相同
            if existingItem.title == newItem.title {
                // 对于相同标题的任务，检查时间是否重复
                let timeDifference = abs(existingItem.startTime.timeIntervalSince(newItem.startTime))
                
                // 如果时间差在3分钟内，认为是重复
                if timeDifference <= 180 { // 3分钟 = 180秒
                    return existingItem
                }
                
                // 如果备注和分类也相同，使用更宽松的时间阈值
                if existingItem.notes == newItem.notes &&
                   existingItem.category == newItem.category &&
                   timeDifference <= 300 { // 5分钟 = 300秒
                    return existingItem
                }
                
                // 检查是否在同一天且时间段重叠
                if calendar.isDate(existingItem.startTime, inSameDayAs: newItem.startTime) {
                    // 安全检查：确保 endTime 不早于 startTime
                    let existingStart = existingItem.startTime
                    let existingEnd = max(existingItem.endTime, existingItem.startTime)
                    let newStart = newItem.startTime
                    let newEnd = max(newItem.endTime, newItem.startTime)
                    
                    let existingRange = existingStart...existingEnd
                    let newRange = newStart...newEnd
                    
                    // 检查时间段是否重叠
                    if existingRange.overlaps(newRange) {
                        return existingItem
                    }
                }
            }
        }
        
        return nil
    }
    
    private func handleDuplicateSchedule(_ newItem: ScheduleItem, existingItem: ScheduleItem) {
        // 提供用户选择：合并、替换或取消
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        
        DispatchQueue.main.async {
            self.errorMessage = """
            发现相似的日程："\(existingItem.title)"
            
            时间：\(timeFormatter.string(from: existingItem.startTime)) - \(timeFormatter.string(from: existingItem.endTime))
            
            建议：检查是否重复添加，或考虑合并相关任务。
            """
        }
        
        // 不添加重复的日程项
        print("🔍 [DEBUG] 检测到重复日程，已阻止添加: \(newItem.title)")
    }
    
    // MARK: - 统一日程管理功能
    
    /// 查找所有相同名称和时间点的日程（统一安排）
    func findUnifiedSchedules(for schedule: ScheduleItem) -> [ScheduleItem] {
        let calendar = Calendar.current
        let targetTimeComponents = calendar.dateComponents([.hour, .minute], from: schedule.startTime)
        
        return scheduleItems.filter { item in
            // 相同名称
            guard item.title.lowercased() == schedule.title.lowercased() else { return false }
            
            // 相同时间点（精确到分钟）
            let itemTimeComponents = calendar.dateComponents([.hour, .minute], from: item.startTime)
            return itemTimeComponents.hour == targetTimeComponents.hour &&
                   itemTimeComponents.minute == targetTimeComponents.minute
        }
    }
    
    /// 统一修改所有相同名称和时间点的日程
    func updateUnifiedSchedules(_ updatedSchedule: ScheduleItem) {
        // 优先根据“原始时间”定位统一修改的集合，避免因更改时间导致找不到集合
        let calendar = Calendar.current
        let originalItem = scheduleItems.first(where: { $0.id == updatedSchedule.id })
        let unifiedSchedules: [ScheduleItem]
        if let originalItem = originalItem {
            let targetHour = calendar.component(.hour, from: originalItem.startTime)
            let targetMinute = calendar.component(.minute, from: originalItem.startTime)
            unifiedSchedules = scheduleItems.filter { item in
                item.title.lowercased() == originalItem.title.lowercased() &&
                calendar.component(.hour, from: item.startTime) == targetHour &&
                calendar.component(.minute, from: item.startTime) == targetMinute
            }
        } else {
            // 回退到基于更新后时间的查找
            unifiedSchedules = findUnifiedSchedules(for: updatedSchedule)
        }
        
        for schedule in unifiedSchedules {
            var modifiedSchedule = schedule
            
            // 更新基本信息，但保持各自的日期
            modifiedSchedule.title = updatedSchedule.title
            modifiedSchedule.notes = updatedSchedule.notes
            modifiedSchedule.category = updatedSchedule.category
            modifiedSchedule.priority = updatedSchedule.priority
            modifiedSchedule.hasReminder = updatedSchedule.hasReminder
        modifiedSchedule.reminderMinutesBefore = updatedSchedule.reminderMinutesBefore
        modifiedSchedule.reminderSound = updatedSchedule.reminderSound
        modifiedSchedule.customSoundURL = updatedSchedule.customSoundURL
            
            // 更新时间，但保持原有的日期
            let originalDateComponents = calendar.dateComponents([.year, .month, .day], from: schedule.startTime)
            let newTimeComponents = calendar.dateComponents([.hour, .minute, .second], from: updatedSchedule.startTime)
            
            var newStartComponents = originalDateComponents
            newStartComponents.hour = newTimeComponents.hour
            newStartComponents.minute = newTimeComponents.minute
            newStartComponents.second = newTimeComponents.second
            
            if let newStartTime = calendar.date(from: newStartComponents) {
                modifiedSchedule.startTime = newStartTime
                
                // 计算结束时间的偏移量
                let duration = updatedSchedule.endTime.timeIntervalSince(updatedSchedule.startTime)
                modifiedSchedule.endTime = newStartTime.addingTimeInterval(duration)
            }
            
            // 更新日程
            if let index = scheduleItems.firstIndex(where: { $0.id == schedule.id }) {
                scheduleItems[index] = modifiedSchedule
            }
        }
        
        saveToLocal()
        
        // 重新安排通知
        Task {
            await scheduleAllNotifications()
        }
        
        // 同步到CloudKit
        Task {
            await syncWithCloudKit()
        }
    }
    
    /// 统一删除所有相同名称和时间点的日程
    func deleteUnifiedSchedules(for schedule: ScheduleItem) {
        let unifiedSchedules = findUnifiedSchedules(for: schedule)
        let idsToDelete = unifiedSchedules.map { $0.id }
        
        deleteSchedules(with: idsToDelete)
    }

    // MARK: - 日程合并功能
    
    /// 合并多个日程为一个新日程
    func mergeSchedules(_ scheduleIds: [UUID]) -> Bool {
        let schedulesToMerge = scheduleItems.filter { scheduleIds.contains($0.id) }
        guard schedulesToMerge.count >= 2 else { return false }
        
        // 创建合并后的日程
        let mergedSchedule = createMergedSchedule(from: schedulesToMerge)
        
        // 删除原日程
        for schedule in schedulesToMerge {
            if schedule.isRecurring {
                deleteAllRepeatingSchedules(with: schedule.parentId ?? schedule.id)
            } else {
                deleteSingleSchedule(with: schedule.id)
            }
        }
        
        // 添加合并后的日程
        addSchedule(mergedSchedule)
        
        return true
    }
    
    /// 创建合并后的日程
    private func createMergedSchedule(from schedules: [ScheduleItem]) -> ScheduleItem {
        guard !schedules.isEmpty else {
            fatalError("Cannot merge empty schedule list")
        }
        
        // 合并标题
        let titles = schedules.map { $0.title }
        let mergedTitle = titles.joined(separator: " + ")
        
        // 合并备注
        let notes = schedules.compactMap { $0.notes.isEmpty ? nil : $0.notes }
        let mergedNotes = notes.joined(separator: "\n")
        
        // 选择最早开始时间和最晚结束时间
        let earliestStart = schedules.map { $0.startTime }.min()!
        let latestEnd = schedules.map { $0.endTime }.max()!
        
        // 选择最高优先级
        let priorities = schedules.map { $0.priority }
        let highestPriority: SchedulePriority = priorities.contains(.high) ? .high : 
                             priorities.contains(.medium) ? .medium : .low
        
        // 使用第一个日程的分类
        let category = schedules.first!.category
        
        // 合并提醒设置
        let hasReminder = schedules.contains { $0.reminderTime != nil }
        let reminderTime = hasReminder ? schedules.compactMap { $0.reminderTime }.min() : nil
        
        // 合并重复提醒设置
        // 注意：这些变量暂时未使用，但保留用于未来功能扩展
        let _ = false  // hasRepeatingReminder
        let _: Int? = nil  // repeatingReminderInterval
        
        var mergedItem = ScheduleItem(
            title: mergedTitle,
            notes: mergedNotes,
            category: category,
            priority: highestPriority,
            startTime: earliestStart,
            endTime: latestEnd,
            isCompleted: false
        )
        
        // 设置提醒相关属性
        mergedItem.hasReminder = hasReminder
        mergedItem.reminderTime = reminderTime
        
        return mergedItem
    }
    
    /// 查找可能重复的日程
    func findPotentialDuplicates() -> [ScheduleItem] {
        var duplicates: [ScheduleItem] = []
        let calendar = Calendar.current
        
        // 按日期分组
        let groupedByDate = Dictionary(grouping: scheduleItems) { schedule in
            calendar.startOfDay(for: schedule.startTime)
        }
        
        for (_, daySchedules) in groupedByDate {
            // 查找同一天内的重复日程
            for i in 0..<daySchedules.count {
                for j in (i+1)..<daySchedules.count {
                    let schedule1 = daySchedules[i]
                    let schedule2 = daySchedules[j]
                    
                    if isDuplicate(schedule1, schedule2) {
                        if !duplicates.contains(where: { $0.id == schedule1.id }) {
                            duplicates.append(schedule1)
                        }
                        if !duplicates.contains(where: { $0.id == schedule2.id }) {
                            duplicates.append(schedule2)
                        }
                    }
                }
            }
        }
        
        return duplicates.sorted { $0.startTime < $1.startTime }
    }
    
    /// 判断两个日程是否为重复
    private func isDuplicate(_ schedule1: ScheduleItem, _ schedule2: ScheduleItem) -> Bool {
        // 标题完全相同
        if schedule1.title.lowercased() == schedule2.title.lowercased() {
            // 时间重叠或相近（15分钟内）
            let timeGap = abs(schedule1.startTime.timeIntervalSince(schedule2.startTime))
            if timeGap <= 900 { // 15分钟
                return true
            }
        }
        
        // 标题、分类、时间都相同
        if schedule1.title == schedule2.title &&
           schedule1.category == schedule2.category &&
           abs(schedule1.startTime.timeIntervalSince(schedule2.startTime)) <= 300 { // 5分钟
            return true
        }
        
        return false
    }
    
    /// 自动清理重复日程
    func autoCleanDuplicates() -> Int {
        let duplicates = findPotentialDuplicates()
        var cleanedCount = 0
        
        // 按标题和时间分组
        let groupedDuplicates = Dictionary(grouping: duplicates) { schedule in
            "\(schedule.title.lowercased())_\(Int(schedule.startTime.timeIntervalSince1970 / 300) * 300)" // 5分钟精度
        }
        
        for (_, group) in groupedDuplicates {
            if group.count > 1 {
                // 保留最新创建的，删除其他的
                let sortedGroup = group.sorted { $0.id.uuidString < $1.id.uuidString }
                let _ = sortedGroup.last! // 保留最新的
                let toDelete = sortedGroup.dropLast()
                
                for schedule in toDelete {
                    if schedule.isRecurring {
                        deleteAllRepeatingSchedules(with: schedule.parentId ?? schedule.id)
                    } else {
                        deleteSingleSchedule(with: schedule.id)
                    }
                }
                cleanedCount += toDelete.count
            }
        }
        
        return cleanedCount
    }

    func updateSchedule(_ item: ScheduleItem) {
        var updatedItem = item
        updatedItem.modifiedDate = Date()
        
        print("🔄 [DEBUG] updateSchedule called for: \(item.title)")
        print("🔄 [DEBUG] Item ID: \(item.id)")
        print("🔄 [DEBUG] Is recurring: \(item.isRecurring)")
        print("🔄 [DEBUG] Recurring weekdays: \(item.recurringWeekdays)")
        
        // 首先尝试通过ID找到项目
        if let index = scheduleItems.firstIndex(where: { $0.id == item.id }) {
            let oldItem = scheduleItems[index]
            print("🔄 [DEBUG] Found item by ID")
            
            // 检查是否是重复日程且天数发生了变化
            if oldItem.isRecurring && updatedItem.isRecurring {
                let oldWeekdays = oldItem.recurringWeekdays
                let newWeekdays = updatedItem.recurringWeekdays
                
                print("🔄 [DEBUG] Old weekdays: \(oldWeekdays), New weekdays: \(newWeekdays)")
                
                // 如果重复天数发生变化，需要重新创建整个系列
                if oldWeekdays != newWeekdays {
                    print("🔄 [DEBUG] Weekdays changed, updating series")
                    updateRecurringScheduleSeries(updatedItem)
                    return
                }
            }
            
            // 检查从非重复变为重复，或从重复变为非重复
            if oldItem.isRecurring != updatedItem.isRecurring {
                if updatedItem.isRecurring {
                    // 从单天变为重复：删除原项目，创建重复系列
                    print("🔄 从单天变为重复：\(updatedItem.title)")
                    print("🔄 重复天数：\(updatedItem.recurringWeekdays)")
                    
                    // 确保设置了重复相关的属性
                    if updatedItem.recurringStartDate == nil {
                        updatedItem.recurringStartDate = Calendar.current.dateInterval(of: .day, for: updatedItem.startTime)?.start
                    }
                    if updatedItem.recurringEndDate == nil {
                        updatedItem.recurringEndDate = Calendar.current.date(byAdding: .month, value: 3, to: updatedItem.recurringStartDate ?? updatedItem.startTime)
                    }
                    
                    deleteSingleSchedule(with: oldItem.id)
                    createRecurringScheduleSeries(updatedItem)
                } else {
                    // 从重复变为单天：删除整个系列，只保留当前项目
                    deleteAllRepeatingSchedules(with: oldItem.parentId ?? oldItem.id)
                    updatedItem.isRecurring = false
                    updatedItem.parentId = nil
                    updatedItem.recurringWeekdays = []
                    scheduleItems.append(updatedItem)
                }
                saveToLocal()
                return
            }
        } else {
            // 如果通过ID找不到，尝试通过标题找到相关项目
            print("🔄 [DEBUG] Item not found by ID, searching by title")
            let relatedItems = scheduleItems.filter { existingItem in
                existingItem.title == item.title
            }
            
            if !relatedItems.isEmpty {
                print("🔄 [DEBUG] Found \(relatedItems.count) related items by title")
                
                let firstRelated = relatedItems.first!
                
                // 检查是否从单天变为重复
                if !firstRelated.isRecurring && item.isRecurring {
                    print("🔄 [DEBUG] Converting single day to recurring: \(item.title)")
                    print("🔄 [DEBUG] Recurring weekdays: \(item.recurringWeekdays)")
                    print("🔄 [DEBUG] Original item ID: \(firstRelated.id)")
                    print("🔄 [DEBUG] Modified item ID: \(item.id)")
                    
                    // 设置重复相关的属性
                    var updatedItem = item
                    updatedItem.id = firstRelated.id  // 保持原ID
                    if updatedItem.recurringStartDate == nil {
                        updatedItem.recurringStartDate = Calendar.current.dateInterval(of: .day, for: updatedItem.startTime)?.start
                    }
                    if updatedItem.recurringEndDate == nil {
                        updatedItem.recurringEndDate = Calendar.current.date(byAdding: .month, value: 3, to: updatedItem.recurringStartDate ?? updatedItem.startTime)
                    }
                    
                    print("🔄 [DEBUG] About to delete single schedule with ID: \(firstRelated.id)")
                    // 删除原单天项目
                    deleteSingleSchedule(with: firstRelated.id)
                    
                    print("🔄 [DEBUG] About to create recurring series")
                    // 创建重复系列
                    createRecurringScheduleSeries(updatedItem)
                    return
                }
                
                // 如果是重复日程且天数发生变化，更新整个系列
                if firstRelated.isRecurring && item.isRecurring {
                    let oldWeekdays = firstRelated.recurringWeekdays
                    let newWeekdays = item.recurringWeekdays
                    
                    print("🔄 [DEBUG] Related item old weekdays: \(oldWeekdays), New weekdays: \(newWeekdays)")
                    
                    if oldWeekdays != newWeekdays {
                        print("🔄 [DEBUG] Weekdays changed for related items, updating series")
                        // 使用第一个相关项目的parentId或id作为基础
                        var itemToUpdate = item
                        itemToUpdate.parentId = firstRelated.parentId ?? firstRelated.id
                        // 确保使用原始项目的时间信息
                        itemToUpdate.startTime = firstRelated.startTime
                        itemToUpdate.endTime = firstRelated.endTime
                        itemToUpdate.recurringStartDate = firstRelated.recurringStartDate
                        itemToUpdate.recurringEndDate = firstRelated.recurringEndDate
                        updateRecurringScheduleSeries(itemToUpdate)
                        return
                    }
                }
                
                // 如果找到了相关项目但没有进行任何更新，说明可能是其他类型的更新
                // 直接更新第一个相关项目
                print("🔄 [DEBUG] Updating first related item directly")
                var itemToUpdate = item
                itemToUpdate.id = firstRelated.id  // 使用原始ID
                if let index = scheduleItems.firstIndex(where: { $0.id == firstRelated.id }) {
                    scheduleItems[index] = itemToUpdate
                    saveToLocal()
                    
                    // 同步到CloudKit
                    Task {
                        do {
                            try await cloudKitManager.saveScheduleItem(itemToUpdate)
                        } catch {
                            print("CloudKit更新失败: \(error.localizedDescription)")
                        }
                    }
                }
                return
            } else {
                print("🔄 [DEBUG] No related items found, item may not exist")
                return
            }
        }
            
        // 取消旧通知
        if let index = scheduleItems.firstIndex(where: { $0.id == item.id }) {
            let oldItem = scheduleItems[index]
            
            if oldItem.hasReminder {
                notificationManager.cancelNotification(for: oldItem)
            }
            
            scheduleItems[index] = updatedItem
            
            // 安排新通知
            if updatedItem.hasReminder {
                notificationManager.scheduleNotification(for: updatedItem)
            }
            
            saveToLocal()
            
            // 同步到CloudKit
            Task {
                do {
                    try await cloudKitManager.saveScheduleItem(updatedItem)
                } catch {
                    print("CloudKit更新失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func deleteSchedules(at offsets: IndexSet) {
        print("🔍 [DEBUG] deleteSchedules(at:) 被调用，offsets: \(offsets)")
        print("🔍 [DEBUG] 当前日程总数: \(scheduleItems.count)")
        
        // 确保在主线程上执行
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.deleteSchedules(at: offsets)
            }
            return
        }
        
        // 验证索引有效性
        let validOffsets = offsets.filter { $0 < scheduleItems.count }
        guard !validOffsets.isEmpty else {
            print("🔍 [DEBUG] 错误：无效的索引")
            return
        }
        
        // 获取要删除的项目
        let itemsToDelete = validOffsets.map { scheduleItems[$0] }
        print("🔍 [DEBUG] 要删除的日程: \(itemsToDelete.map { $0.title })")
        
        // 取消通知
        for item in itemsToDelete {
            notificationManager.cancelNotification(for: item)
        }
        
        // 使用动画直接从数组中移除项目
        withAnimation(.easeInOut(duration: 0.3)) {
            scheduleItems.remove(atOffsets: offsets)
        }
        
        print("🔍 [DEBUG] 删除后日程总数: \(scheduleItems.count)")
        
        // 保存到本地
        saveToLocal()
        
        // 异步处理CloudKit删除
        Task {
            do {
                for item in itemsToDelete {
                    try await cloudKitManager.deleteScheduleItem(item)
                }
                print("🔍 [DEBUG] CloudKit删除成功")
            } catch {
                print("🔍 [DEBUG] CloudKit删除失败: \(error.localizedDescription)")
                // CloudKit失败时显示错误信息，但不恢复本地数据
                DispatchQueue.main.async {
                    self.errorMessage = "本地删除成功，但云端同步失败"
                }
            }
        }
    }
    
    func deleteSchedules(with ids: [UUID]) {
        print("🗑️ deleteSchedules 被调用，要删除的ID数量: \(ids.count)")
        print("🗑️ 当前日程总数: \(scheduleItems.count)")
        
        // 确保在主线程上执行UI相关操作
        guard Thread.isMainThread else {
            print("🗑️ 不在主线程，切换到主线程")
            DispatchQueue.main.async {
                self.deleteSchedules(with: ids)
            }
            return
        }
        
        let itemsToDelete = ids.compactMap { id in
            scheduleItems.first { $0.id == id }
        }
        
        print("🗑️ 找到要删除的日程数量: \(itemsToDelete.count)")
        for item in itemsToDelete {
            print("🗑️ 要删除的日程: \(item.title)")
        }
        
        guard !itemsToDelete.isEmpty else {
            print("🗑️ 错误：未找到要删除的日程")
            errorMessage = "未找到要删除的日程"
            return
        }
        
        // 备份要删除的项目，以便在CloudKit删除失败时恢复
        let backupItems = itemsToDelete
        
        print("🗑️ 开始执行删除动画")
        // 使用显式的状态更新来确保SwiftUI正确处理数据变化
        withAnimation(.easeInOut(duration: 0.3)) {
            // 先进行本地删除，确保UI立即更新
            for item in itemsToDelete {
                // 取消通知
                notificationManager.cancelNotification(for: item)
                
                // 从数组中移除 - 使用更安全的方式
                if let index = scheduleItems.firstIndex(where: { $0.id == item.id }) {
                    print("🗑️ 从索引 \(index) 删除日程: \(item.title)")
                    scheduleItems.remove(at: index)
                } else {
                    print("🗑️ 警告：未找到日程索引: \(item.title)")
                }
            }
        }
        
        print("🗑️ 删除后日程总数: \(scheduleItems.count)")
        
        // 保存到本地
        saveToLocal()
        print("🗑️ 已保存到本地")
        
        // 异步处理CloudKit删除
        Task { @MainActor in
            var failedItems: [ScheduleItem] = []
            var errorDetails: [String] = []
            
            for item in backupItems {
                do {
                    try await cloudKitManager.deleteScheduleItem(item)
                } catch {
                    failedItems.append(item)
                    let errorMsg = (error as? CloudKitError)?.errorDescription ?? error.localizedDescription
                    errorDetails.append(errorMsg)
                    print("CloudKit删除失败: \(errorMsg)")
                }
            }
            
            // 如果有失败的删除操作，提供用户选择
            if !failedItems.isEmpty {
                let uniqueErrors = Array(Set(errorDetails))
                let errorSummary = uniqueErrors.joined(separator: "；")
                
                // 提供更详细的错误信息和恢复选项
                self.errorMessage = """
                有 \(failedItems.count) 个日程云端删除失败：\(errorSummary)
                
                本地已删除，但云端仍存在。下次同步时可能会重新出现这些日程。
                建议：检查网络连接后手动同步，或在设置中重新尝试删除。
                """
                
                // 记录失败的项目ID，供后续重试使用
                let failedIds = failedItems.map { $0.id }
                print("删除失败的日程ID: \(failedIds)")
            }
        }
    }
    
    func toggleCompletion(for id: UUID) {
        DispatchQueue.main.async {
            if let index = self.scheduleItems.firstIndex(where: { $0.id == id }) {
                self.scheduleItems[index].isCompleted.toggle()
                self.scheduleItems[index].modifiedDate = Date()
                
                // 保存到本地和CloudKit
                self.saveToLocal()
                Task {
                    do {
                        try await self.cloudKitManager.saveScheduleItem(self.scheduleItems[index])
                    } catch {
                        print("CloudKit保存失败: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    

    func deleteSingleSchedule(with id: UUID) {
        // 确保在主线程上执行UI相关操作
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.deleteSingleSchedule(with: id)
            }
            return
        }
        
        guard let index = scheduleItems.firstIndex(where: { $0.id == id }) else {
            errorMessage = "未找到要删除的日程"
            return
        }
        
        let item = scheduleItems[index]
        
        // 使用显式的状态更新来确保SwiftUI正确处理数据变化
        withAnimation(.easeInOut(duration: 0.3)) {
            // 取消通知
            if item.hasReminder {
                notificationManager.cancelNotification(for: item)
            }
            
            // 从数组中移除
            scheduleItems.remove(at: index)
        }
        
        // 保存到本地
        saveToLocal()
        
        // 异步处理CloudKit删除
        Task { @MainActor in
            do {
                try await cloudKitManager.deleteScheduleItem(item)
            } catch {
                let errorMsg = (error as? CloudKitError)?.errorDescription ?? error.localizedDescription
                print("CloudKit删除失败: \(errorMsg)")
                
                // 提供更详细的错误信息
                self.errorMessage = """
                日程云端删除失败：\(errorMsg)
                
                本地已删除，但云端仍存在。下次同步时可能会重新出现此日程。
                建议：检查网络连接后手动同步。
                """
                
                print("删除失败的日程ID: \(item.id)")
            }
        }
    }

    func deleteAllRepeatingSchedules(with id: UUID) {
        // 确保在主线程上执行UI相关操作
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.deleteAllRepeatingSchedules(with: id)
            }
            return
        }
        
        guard let targetItem = scheduleItems.first(where: { $0.id == id }) else {
            errorMessage = "未找到要删除的日程"
            return
        }
        
        // 找到所有相关的重复日程或忆年日程
        let relatedItems: [ScheduleItem]
        
        if targetItem.isFestival && targetItem.isYearlyRecurring {
            // 忆年日程：删除所有相同标题的忆年日程
            relatedItems = scheduleItems.filter { item in
                item.isFestival && 
                item.isYearlyRecurring && 
                item.title == targetItem.title &&
                item.festivalType == targetItem.festivalType
            }
        } else if let parentId = targetItem.parentId {
            // 如果有parentId，删除所有具有相同parentId的日程
            relatedItems = scheduleItems.filter { $0.parentId == parentId || $0.id == parentId }
        } else if targetItem.isRecurring {
            // 如果是重复日程的父项，删除所有以此为parentId的日程
            relatedItems = scheduleItems.filter { $0.parentId == targetItem.id || $0.id == targetItem.id }
        } else {
            // 如果不是重复日程，只删除自己
            relatedItems = [targetItem]
        }
        
        guard !relatedItems.isEmpty else {
            errorMessage = "未找到相关的重复日程"
            return
        }
        
        // 备份要删除的项目
        let backupItems = relatedItems
        
        // 使用显式的状态更新来确保SwiftUI正确处理数据变化
        withAnimation(.easeInOut(duration: 0.3)) {
            // 先进行本地删除
            for item in relatedItems {
                // 取消通知
                if item.hasReminder {
                    notificationManager.cancelNotification(for: item)
                }
                
                // 从数组中移除 - 使用更安全的方式
                if let index = scheduleItems.firstIndex(where: { $0.id == item.id }) {
                    scheduleItems.remove(at: index)
                }
            }
        }
        
        // 保存到本地
        saveToLocal()
        
        // 异步处理CloudKit删除
        Task { @MainActor in
            var failedItems: [ScheduleItem] = []
            var errorDetails: [String] = []
            
            for item in backupItems {
                do {
                    try await cloudKitManager.deleteScheduleItem(item)
                } catch {
                    failedItems.append(item)
                    let errorMsg = (error as? CloudKitError)?.errorDescription ?? error.localizedDescription
                    errorDetails.append(errorMsg)
                    print("CloudKit删除失败: \(errorMsg)")
                }
            }
            
            // 如果有失败的删除操作，提供详细的错误信息
            if !failedItems.isEmpty {
                let uniqueErrors = Array(Set(errorDetails))
                let errorSummary = uniqueErrors.joined(separator: "；")
                
                self.errorMessage = """
                有 \(failedItems.count) 个重复日程云端删除失败：\(errorSummary)
                
                本地已删除，但云端仍存在。下次同步时可能会重新出现这些日程。
                建议：检查网络连接后手动同步，或在设置中重新尝试删除。
                """
                
                let failedIds = failedItems.map { $0.id }
                print("删除失败的重复日程ID: \(failedIds)")
            }
        }
    }
    
    // MARK: - 其他方法
    
    // 清除所有日程
    func clearAllSchedules() {
        // 取消所有通知
        for item in scheduleItems {
            if item.hasReminder {
                notificationManager.cancelNotification(for: item)
            }
        }
        
        // 软删除所有CloudKit记录
        Task {
            for item in scheduleItems {
                do {
                    try await cloudKitManager.deleteScheduleItem(item)
                } catch {
                    print("CloudKit删除失败: \(error.localizedDescription)")
                }
            }
        }
        
        // 清空本地数组
        scheduleItems.removeAll()
        
        // 保存到本地
        saveToLocal()
    }
    
    private func addRecurringSchedule(_ item: ScheduleItem) {
        // 对于重复日程，需要创建系列实例
        createRecurringScheduleSeries(item)
    }
    
    // 更新重复日程系列（对外公开，供视图调用）
    func updateRecurringScheduleSeries(_ updatedItem: ScheduleItem) {
        print("🔄 开始更新重复日程系列：\(updatedItem.title)")
        print("🔄 更新前总数：\(scheduleItems.count)")
        
        // 找到所有相关的重复日程项目（通过parentId或相同标题）
        let parentId = updatedItem.parentId ?? updatedItem.id
        let existingItems = scheduleItems.filter { item in
            (item.parentId == parentId || item.id == parentId || 
             (item.title == updatedItem.title && item.isRecurring)) && item.isRecurring
        }
        
        print("🔍 找到 \(existingItems.count) 个相关的重复日程项目，parentId: \(parentId)")
        
        // 获取第一个现有项目的时间信息作为基准
        let baseItem = existingItems.first ?? updatedItem
        
        // 删除所有相关的重复日程项目
        let itemsToRemove = scheduleItems.filter { item in
            (item.parentId == parentId || item.id == parentId || 
             (item.title == updatedItem.title && item.isRecurring)) && item.isRecurring
        }
        
        print("🗑️ 准备删除 \(itemsToRemove.count) 个现有重复日程项目")
        for item in itemsToRemove {
            print("🗑️ 删除项目：\(item.title), id: \(item.id), parentId: \(item.parentId?.uuidString ?? "nil")")
        }
        
        // 执行删除
        let removedCount = itemsToRemove.count
        scheduleItems.removeAll { item in
            (item.parentId == parentId || item.id == parentId || 
             (item.title == updatedItem.title && item.isRecurring)) && item.isRecurring
        }
        
        print("🔄 删除后总数：\(scheduleItems.count)，实际删除了 \(removedCount) 个项目")
        
        // 创建新的重复日程系列
        var itemToCreate = updatedItem
        itemToCreate.parentId = parentId
        itemToCreate.isRecurring = true
        
        // 使用基准项目的时间信息
        itemToCreate.startTime = baseItem.startTime
        itemToCreate.endTime = baseItem.endTime
        
        // 设置重复日程的开始和结束日期
        if itemToCreate.recurringStartDate == nil {
            itemToCreate.recurringStartDate = baseItem.recurringStartDate ?? Calendar.current.dateInterval(of: .day, for: baseItem.startTime)?.start
        }
        if itemToCreate.recurringEndDate == nil {
            itemToCreate.recurringEndDate = baseItem.recurringEndDate ?? Calendar.current.date(byAdding: .month, value: 3, to: itemToCreate.recurringStartDate ?? baseItem.startTime)
        }
        
        print("🔄 准备创建新的重复系列，weekdays: \(itemToCreate.recurringWeekdays)")
        print("🔄 开始日期: \(itemToCreate.recurringStartDate?.description ?? "nil")")
        print("🔄 结束日期: \(itemToCreate.recurringEndDate?.description ?? "nil")")
        
        createRecurringScheduleSeries(itemToCreate)
        
        print("🔄 创建后总数：\(scheduleItems.count)")
        
        // 保存更改
        saveToLocal()
    }
    
    // 创建重复日程系列
    private func createRecurringScheduleSeries(_ item: ScheduleItem) {
        print("🔄 [DEBUG] createRecurringScheduleSeries called for: \(item.title)")
        print("🔄 [DEBUG] Recurring weekdays: \(item.recurringWeekdays)")
        print("🔄 [DEBUG] Start date: \(item.recurringStartDate?.description ?? "nil")")
        print("🔄 [DEBUG] End date: \(item.recurringEndDate?.description ?? "nil")")
        print("🔄 [DEBUG] Current total items before creation: \(scheduleItems.count)")
        
        let calendar = Calendar.current
        let parentId = item.parentId ?? item.id
        
        // 确保有重复天数设置
        guard !item.recurringWeekdays.isEmpty else {
            print("❌ [DEBUG] No recurring weekdays specified")
            return
        }
        
        guard let startDate = item.recurringStartDate ?? calendar.dateInterval(of: .day, for: item.startTime)?.start,
              let endDate = item.recurringEndDate ?? calendar.date(byAdding: .month, value: 3, to: startDate) else {
            print("❌ [DEBUG] Missing start or end date")
            return
        }
        
        print("📅 创建重复日程系列：\(item.title)")
        print("📅 开始日期：\(startDate)")
        print("📅 结束日期：\(endDate)")
        print("📅 重复天数：\(item.recurringWeekdays)")
        print("📅 使用parentId：\(parentId)")
        
        var currentDate = startDate
        var createdCount = 0
        let maxIterations = 365 // 防止无限循环
        var iterations = 0
        
        // 使用用户指定的结束日期，不强制最小范围
        let actualEndDate = endDate
        
        while currentDate <= actualEndDate && iterations < maxIterations {
            let weekday = calendar.component(.weekday, from: currentDate)
            
            if item.recurringWeekdays.contains(weekday) {
                let startDateTime = calendar.date(
                    bySettingHour: calendar.component(.hour, from: item.startTime),
                    minute: calendar.component(.minute, from: item.startTime),
                    second: 0,
                    of: currentDate
                ) ?? currentDate
                
                let endDateTime = calendar.date(
                    bySettingHour: calendar.component(.hour, from: item.endTime),
                    minute: calendar.component(.minute, from: item.endTime),
                    second: 0,
                    of: currentDate
                ) ?? currentDate
                
                var newItem = ScheduleItem(
                    title: item.title,
                    notes: item.notes,
                    category: item.category,
                    priority: item.priority,
                    startTime: startDateTime,
                    endTime: endDateTime,
                    isCompleted: false
                )
                
                // 设置重复日程属性
                newItem.isRecurring = true
                newItem.recurringStartDate = startDate
                newItem.recurringEndDate = endDate  // 保持原始结束日期
                newItem.recurringWeekdays = item.recurringWeekdays
                newItem.parentId = parentId
                
                // 设置提醒
                newItem.hasReminder = item.hasReminder
                newItem.reminderMinutesBefore = item.reminderMinutesBefore
                newItem.reminderSound = item.reminderSound
                newItem.customSoundURL = item.customSoundURL
                
                scheduleItems.append(newItem)
                createdCount += 1
                
                print("📅 [DEBUG] Created item for \(currentDate): \(newItem.title), ID: \(newItem.id)")
                
                // 安排通知
                if newItem.hasReminder {
                    notificationManager.scheduleNotification(for: newItem)
                }
            }
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            iterations += 1
        }
        
        print("🔄 [DEBUG] Created \(createdCount) recurring items")
        print("🔄 [DEBUG] Current total items after creation: \(scheduleItems.count)")
        
        // 如果没有创建任何实例，至少创建一个基础实例
        if createdCount == 0 {
            print("⚠️ 没有创建任何重复实例，创建基础实例")
            var baseItem = item
            baseItem.parentId = parentId
            scheduleItems.append(baseItem)
            createdCount = 1
        }
        
        saveToLocal()
        
        // 同步到CloudKit
        Task {
            for item in scheduleItems.suffix(createdCount) {
                do {
                    try await cloudKitManager.saveScheduleItem(item)
                } catch {
                    print("CloudKit保存失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func seedSampleData() {
        // 为每种分类创建一个默认日程
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        
        // 工作分类 - 上午9点到10点
        let workStartTime = calendar.date(byAdding: .hour, value: 9, to: today) ?? now
        let workEndTime = calendar.date(byAdding: .hour, value: 1, to: workStartTime) ?? now
        let workSchedule = ScheduleItem(
            title: "工作任务示例",
            notes: "这是一个工作分类的示例日程",
            category: .work,
            priority: .medium,
            startTime: workStartTime,
            endTime: workEndTime
        )
        
        // 学习分类 - 上午10点到11点
        let studyStartTime = calendar.date(byAdding: .hour, value: 10, to: today) ?? now
        let studyEndTime = calendar.date(byAdding: .hour, value: 1, to: studyStartTime) ?? now
        let studySchedule = ScheduleItem(
            title: "学习计划示例",
            notes: "这是一个学习分类的示例日程",
            category: .study,
            priority: .high,
            startTime: studyStartTime,
            endTime: studyEndTime
        )
        
        // 生活分类 - 下午2点到3点
        let lifeStartTime = calendar.date(byAdding: .hour, value: 14, to: today) ?? now
        let lifeEndTime = calendar.date(byAdding: .hour, value: 1, to: lifeStartTime) ?? now
        let lifeSchedule = ScheduleItem(
            title: "生活安排示例",
            notes: "生活分类示例",
            category: .life,
            priority: .low,
            startTime: lifeStartTime,
            endTime: lifeEndTime
        )
        
        // 健康分类 - 下午6点到7点
        let healthStartTime = calendar.date(byAdding: .hour, value: 18, to: today) ?? now
        let healthEndTime = calendar.date(byAdding: .hour, value: 1, to: healthStartTime) ?? now
        let healthSchedule = ScheduleItem(
            title: "健康活动示例",
            notes: "这是一个健康分类的示例日程",
            category: .health,
            priority: .medium,
            startTime: healthStartTime,
            endTime: healthEndTime
        )
        
        // 其他分类 - 晚上8点到9点
        let otherStartTime = calendar.date(byAdding: .hour, value: 20, to: today) ?? now
        let otherEndTime = calendar.date(byAdding: .hour, value: 1, to: otherStartTime) ?? now
        let otherSchedule = ScheduleItem(
            title: "其他事项示例",
            notes: "这是一个其他分类的示例日程",
            category: .other,
            priority: .low,
            startTime: otherStartTime,
            endTime: otherEndTime
        )
        
        scheduleItems = [workSchedule, studySchedule, lifeSchedule, healthSchedule, otherSchedule]
        saveToLocal()
    }
    
    private func scheduleAllNotifications() async {
        for item in scheduleItems {
            if item.hasReminder {
                notificationManager.scheduleNotification(for: item)
            }
        }
    }
    
    func schedulesForDate(_ date: Date) -> [ScheduleItem] {
        let calendar = Calendar.current
        let filteredSchedules = self.scheduleItems.filter { 
            calendar.isDate($0.startTime, inSameDayAs: date)
        }.sorted { $0.startTime < $1.startTime }
        
        print("📅 查询日期 \(date) 的日程，找到 \(filteredSchedules.count) 个")
        for schedule in filteredSchedules {
            print("  - \(schedule.title) - isRecurring: \(schedule.isRecurring) - isFestival: \(schedule.isFestival)")
        }
        
        return filteredSchedules
    }
    
    func completionRateForMonth(_ date: Date) -> Double {
        let calendar = Calendar.current
        let monthSchedules = scheduleItems.filter { item in
            calendar.isDate(item.startTime, equalTo: date, toGranularity: .month)
        }
        
        guard !monthSchedules.isEmpty else { return 0.0 }
        
        let completedCount = monthSchedules.filter { $0.isCompleted }.count
        return Double(completedCount) / Double(monthSchedules.count)
    }

    
    var completedItemsCount: Int {
        return self.scheduleItems.filter { $0.isCompleted }.count
    }
    
    func requestNotificationPermission() async -> Bool {
        return await self.notificationManager.requestNotificationPermission()
    }
    
    
    var todayItemsCount: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return self.scheduleItems.filter { item in
            Calendar.current.isDate(item.startTime, inSameDayAs: today)
        }.count
    }
    
    var pendingItemsCount: Int {
        return self.scheduleItems.filter { !$0.isCompleted }.count
    }
}
