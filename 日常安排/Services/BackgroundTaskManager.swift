import Foundation
import BackgroundTasks
import UserNotifications
import SwiftUI
import Combine

class BackgroundTaskManager: ObservableObject {
    static let shared = BackgroundTaskManager()
    
    // 后台任务标识符 - 必须与Info.plist中的BGTaskSchedulerPermittedIdentifiers一致
    private let backgroundTaskIdentifier = "com.enow.dailyschedule.refresh"
    private let processingTaskIdentifier = "com.enow.dailyschedule.processing"
    
    @Published var isBackgroundRefreshEnabled = false
    
    private init() {
        checkBackgroundRefreshStatus()
    }

    // 去重与节流配置
    private let refreshMinInterval: TimeInterval = 10 * 60
    private let processingMinInterval: TimeInterval = 30 * 60

    private let refreshLastSubmitKey = "BGLastRefreshSubmitDate"
    private let processingLastSubmitKey = "BGLastProcessingSubmitDate"

    private var refreshLastSubmitDate: Date? {
        get { UserDefaults.standard.object(forKey: refreshLastSubmitKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: refreshLastSubmitKey) }
    }

    private var processingLastSubmitDate: Date? {
        get { UserDefaults.standard.object(forKey: processingLastSubmitKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: processingLastSubmitKey) }
    }

    private func shouldThrottle(last: Date?, minInterval: TimeInterval) -> Bool {
        guard let last = last else { return false }
        return Date().timeIntervalSince(last) < minInterval
    }
    
    // MARK: - 注册后台任务
    func registerBackgroundTasks() {
        print("🔄 开始注册后台任务...")
        #if os(iOS)
        // 检查后台刷新状态
        let backgroundRefreshStatus = UIApplication.shared.backgroundRefreshStatus
        print("🔄 后台刷新状态: \(backgroundRefreshStatus.rawValue)")
        
        switch backgroundRefreshStatus {
        case .available:
            print("🔄 ✅ 后台刷新可用")
        case .denied:
            print("🔄 ❌ 后台刷新被拒绝")
        case .restricted:
            print("🔄 ⚠️ 后台刷新受限")
        @unknown default:
            print("🔄 ❓ 后台刷新状态未知")
        }
        
        // 注册后台应用刷新任务
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
            print("🔄 后台刷新任务被触发")
            self.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
        }
        
        // 注册后台处理任务
        BGTaskScheduler.shared.register(forTaskWithIdentifier: processingTaskIdentifier, using: nil) { task in
            print("🔄 后台处理任务被触发")
            self.handleBackgroundProcessing(task: task as! BGProcessingTask)
        }
        
        print("🔄 后台任务注册完成")
        #else
        print("🔄 非iOS平台，跳过后台任务注册")
        #endif
    }
    
    // MARK: - 检查后台刷新状态
    func checkBackgroundRefreshStatus() {
        #if os(iOS)
        DispatchQueue.main.async {
            self.isBackgroundRefreshEnabled = UIApplication.shared.backgroundRefreshStatus == .available
        }
        #endif
    }
    
    // MARK: - 调度后台任务
    func scheduleBackgroundRefresh(force: Bool = false) {
        #if os(iOS)
        // 在提交前检查后台刷新能力
        let status = UIApplication.shared.backgroundRefreshStatus
        guard status == .available else {
            print("🔄 后台刷新不可用，状态: \(status.rawValue)；请在系统设置中开启后台应用刷新")
            return
        }
        // 节流：距离上次提交过短则跳过（除非强制）
        if !force, shouldThrottle(last: refreshLastSubmitDate, minInterval: refreshMinInterval) {
            if let last = refreshLastSubmitDate {
                let remain = refreshMinInterval - Date().timeIntervalSince(last)
                print("🔄 刷新任务节流，剩余 \(Int(max(0, remain)))s 后可再次提交")
            }
            return
        }
        // 去重：先取消相同标识的待请求，避免叠加
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: backgroundTaskIdentifier)
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15分钟后
        
        do {
            try BGTaskScheduler.shared.submit(request)
            refreshLastSubmitDate = Date()
            print("🔄 后台刷新任务已调度（去重+节流保护）")
        } catch {
            let nsError = error as NSError
            print("🔄 调度后台刷新任务失败: domain=\(nsError.domain) code=\(nsError.code) desc=\(nsError.localizedDescription)")
        }
        #endif
    }
    
    func scheduleBackgroundProcessing(force: Bool = false) {
        #if os(iOS)
        // 节流：处理任务通常更重，间隔更长（除非强制）
        if !force, shouldThrottle(last: processingLastSubmitDate, minInterval: processingMinInterval) {
            if let last = processingLastSubmitDate {
                let remain = processingMinInterval - Date().timeIntervalSince(last)
                print("🔄 处理任务节流，剩余 \(Int(max(0, remain)))s 后可再次提交")
            }
            return
        }
        // 去重：先取消相同标识的待请求
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: processingTaskIdentifier)
        let request = BGProcessingTaskRequest(identifier: processingTaskIdentifier)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60) // 5分钟后
        
        do {
            try BGTaskScheduler.shared.submit(request)
            processingLastSubmitDate = Date()
            print("🔄 后台处理任务已调度（去重+节流保护）")
        } catch {
            let nsError = error as NSError
            print("🔄 调度后台处理任务失败: domain=\(nsError.domain) code=\(nsError.code) desc=\(nsError.localizedDescription)")
        }
        #endif
    }
    
    // MARK: - 处理后台刷新任务
    #if os(iOS)
    private func handleBackgroundRefresh(task: BGAppRefreshTask) {
        print("🔄 开始执行后台刷新任务")
        
        // 调度下一次后台任务
        scheduleBackgroundRefresh(force: true)
        
        let taskCompleted = DispatchGroup()
        taskCompleted.enter()
        
        // 设置任务过期处理
        task.expirationHandler = {
            print("🔄 后台刷新任务即将过期")
            task.setTaskCompleted(success: false)
            taskCompleted.leave()
        }
        
        // 执行计划状态检查
        Task {
            await self.checkScheduleStatus()
            task.setTaskCompleted(success: true)
            taskCompleted.leave()
        }
        
        // 等待任务完成
        taskCompleted.notify(queue: .main) {
            print("🔄 后台刷新任务完成")
        }
    }
    #endif
    
    // MARK: - 处理后台处理任务
    #if os(iOS)
    private func handleBackgroundProcessing(task: BGProcessingTask) {
        print("🔄 开始执行后台处理任务")
        
        // 调度下一次后台任务
        scheduleBackgroundProcessing(force: true)
        
        let taskCompleted = DispatchGroup()
        taskCompleted.enter()
        
        // 设置任务过期处理
        task.expirationHandler = {
            print("🔄 后台处理任务即将过期")
            task.setTaskCompleted(success: false)
            taskCompleted.leave()
        }
        
        // 执行更详细的计划检查和处理
        Task {
            await self.performDetailedScheduleCheck()
            task.setTaskCompleted(success: true)
            taskCompleted.leave()
        }
        
        // 等待任务完成
        taskCompleted.notify(queue: .main) {
            print("🔄 后台处理任务完成")
        }
    }
    #endif
    
    // MARK: - 检查计划状态
    @MainActor
    private func checkScheduleStatus() async {
        print("📅 开始检查计划状态")
        
        let scheduleStore = ScheduleStore.shared
        
        // 获取今天和明天的计划
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        let todaySchedules = scheduleStore.scheduleItems.filter { item in
            calendar.isDate(item.startTime, inSameDayAs: today) && !item.isCompleted
        }
        
        let upcomingSchedules = scheduleStore.scheduleItems.filter { item in
            item.startTime > Date() && item.startTime < tomorrow && !item.isCompleted
        }
        
        print("📅 今日未完成计划: \(todaySchedules.count)个")
        print("📅 即将到来的计划: \(upcomingSchedules.count)个")
        
        // 检查即将开始的计划（15分钟内）
        let soonSchedules = upcomingSchedules.filter { schedule in
            schedule.startTime.timeIntervalSince(Date()) <= 15 * 60 // 15分钟
        }
        
        // 检查过期的计划（只检查当日的）
        let overdueSchedules = scheduleStore.scheduleItems.filter { schedule in
            !schedule.isCompleted &&
            schedule.endTime < Date() &&
            calendar.isDate(schedule.startTime, inSameDayAs: today)
        }
        
        // 发送即将开始的计划通知
        for schedule in soonSchedules {
            await sendImmediateNotification(for: schedule, type: .upcoming)
        }
        
        // 发送过期计划通知
        if !overdueSchedules.isEmpty {
            await sendOverdueNotification(count: overdueSchedules.count)
        }
        
        print("📅 计划状态检查完成")
    }
    
    // MARK: - 执行详细的计划检查
    @MainActor
    private func performDetailedScheduleCheck() async {
        print("📅 开始执行详细计划检查")
        
        // 执行基本的计划状态检查
        await checkScheduleStatus()
        
        // 执行额外的处理任务
        let scheduleStore = ScheduleStore.shared
        
        // 清理过期的通知
        await cleanupExpiredNotifications()
        
        // 重新调度未来的通知
        let futureSchedules = scheduleStore.scheduleItems.filter { item in
            item.hasReminder && item.startTime > Date() && !item.isCompleted
        }
        
        let notificationManager = NotificationManager.shared
        for schedule in futureSchedules {
            notificationManager.updateNotification(for: schedule)
        }
        
        print("📅 详细计划检查完成")
    }
    
    // MARK: - 发送即时通知
    private func sendImmediateNotification(for schedule: ScheduleItem, type: NotificationType) async {
        let content = UNMutableNotificationContent()
        
        switch type {
        case .upcoming:
            content.title = "计划即将开始"
            content.body = "\(schedule.title) 将在15分钟内开始"
        case .started:
            content.title = "计划已开始"
            content.body = schedule.title
        case .overdue:
            content.title = "计划已过期"
            content.body = "\(schedule.title) 已过期，请及时处理"
        }
        
        content.sound = .default
        content.badge = 1
        
        // 添加通知图标附件
        if let iconURL = Bundle.main.url(forResource: "notification_icon", withExtension: "png") {
            do {
                let attachment = try UNNotificationAttachment(identifier: "notification_icon", url: iconURL, options: nil)
                content.attachments = [attachment]
                print("🔔 🎨 已添加通知图标附件（后台即时通知）")
            } catch {
                print("🔔 ❌ 添加通知图标附件失败（后台即时通知）: \(error)")
            }
        }
        
        content.userInfo = [
            "scheduleId": schedule.id.uuidString,
            "scheduleTitle": schedule.title,
            "notificationType": type.rawValue
        ]
        
        let request = UNNotificationRequest(
            identifier: "immediate_\(schedule.id.uuidString)_\(type.rawValue)",
            content: content,
            trigger: nil // 立即发送
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("📱 已发送即时通知: \(schedule.title)")
        } catch {
            print("📱 发送即时通知失败: \(error)")
        }
    }
    
    // MARK: - 发送过期计划通知
    private func sendOverdueNotification(count: Int) async {
        let content = UNMutableNotificationContent()
        content.title = "有未完成的计划"
        content.body = "您有 \(count) 个计划已过期，请及时处理"
        content.sound = .default
        content.badge = NSNumber(value: count)
        
        // 添加通知图标附件
        if let iconURL = Bundle.main.url(forResource: "notification_icon", withExtension: "png") {
            do {
                let attachment = try UNNotificationAttachment(identifier: "notification_icon", url: iconURL, options: nil)
                content.attachments = [attachment]
                print("🔔 🎨 已添加通知图标附件（后台过期通知）")
            } catch {
                print("🔔 ❌ 添加通知图标附件失败（后台过期通知）: \(error)")
            }
        }
        
        content.userInfo = ["notificationType": NotificationType.overdue.rawValue]
        
        let request = UNNotificationRequest(
            identifier: "overdue_summary_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("📱 已发送过期计划汇总通知")
        } catch {
            print("📱 发送过期计划汇总通知失败: \(error)")
        }
    }
    
    // MARK: - 清理过期通知
    private func cleanupExpiredNotifications() async {
        let center = UNUserNotificationCenter.current()
        let pendingRequests = await center.pendingNotificationRequests()
        
        let expiredIdentifiers = pendingRequests.compactMap { request -> String? in
            if let trigger = request.trigger as? UNCalendarNotificationTrigger,
               let triggerDate = trigger.nextTriggerDate(),
               triggerDate < Date() {
                return request.identifier
            }
            return nil
        }
        
        if !expiredIdentifiers.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: expiredIdentifiers)
            print("🧹 已清理 \(expiredIdentifiers.count) 个过期通知")
        }
    }
}

// MARK: - 通知类型枚举
enum NotificationType: String, CaseIterable {
    case upcoming = "upcoming"
    case started = "started"
    case overdue = "overdue"
}