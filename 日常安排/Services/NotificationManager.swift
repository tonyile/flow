import Foundation
import Combine
import UserNotifications
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    
    private init() {
        checkAuthorizationStatus()
    }
    
    // 检查通知权限状态
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
                if self.isAuthorized {
                    print("🔔 通知权限已授权")
                } else {
                    print("🔔 通知权限未授权")
                }
            }
        }
    }
    
    // 请求通知权限（显示系统弹窗）
    func requestNotificationPermission() async -> Bool {
        do {
            // 移除 .provisional，确保出现系统的“允许通知”弹窗
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            
            print("🔔 通知权限请求结果: \(granted)")
            
            await MainActor.run {
                self.isAuthorized = granted
            }
            
            checkAuthorizationStatus()
            return granted
        } catch {
            print("🔔 ❌ 请求通知权限失败: \(error)")
            return false
        }
    }
    
    // 如果需要，请求通知权限（首次安装或处于临时授权时）
    func requestNotificationPermissionIfNeeded() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        
        switch settings.authorizationStatus {
        case .notDetermined, .provisional:
            // 未决定或临时授权：发起标准授权请求，展示系统弹窗
            let granted = await requestNotificationPermission()
            print("🔔 首次/临时授权请求完成，结果: \(granted)")
        default:
            await MainActor.run {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // 为日程安排通知
    func scheduleNotification(for item: ScheduleItem) {
        print("🔔 开始调度通知 - 标题: \(item.title)")
        
        // 使用设备助手检查能力
        let capabilities = DeviceNotificationHelper.shared.checkDeviceNotificationCapabilities()
        print("🔔 设备能力: \(capabilities.description)")
        
        // 检查设备限制
        Task {
            let restrictions = await DeviceNotificationHelper.shared.checkDeviceNotificationRestrictions()
            if !restrictions.isEmpty {
                print("🔔 ⚠️ 检测到设备限制: \(restrictions.joined(separator: ", "))")
            }
        }
        
        print("🔔 通知权限状态: \(isAuthorized)")
        print("🔔 日程是否启用提醒: \(item.hasReminder)")
        
        guard isAuthorized, item.hasReminder else { 
            print("🔔 通知调度失败 - 权限未授权或未启用提醒")
            return 
        }
        
        let content = UNMutableNotificationContent()
        content.title = "日程提醒"
        content.body = item.title
        
        // 设置自定义音乐
        if item.reminderSound == .defaultSound {
            content.sound = .default
            print("🔔 🔊 使用默认通知声音")
        } else if item.reminderSound == .custom, let customURL = item.customSoundURL {
            // 使用自定义音乐文件
            let soundName = customURL.lastPathComponent
            content.sound = UNNotificationSound(named: UNNotificationSoundName(soundName))
            print("🔔 🔊 使用自定义音乐: \(soundName)")
        } else {
            // 使用系统铃声
            if let systemSoundName = item.reminderSound.systemSoundName {
                let soundName = "\(systemSoundName).wav"
                content.sound = UNNotificationSound(named: UNNotificationSoundName(soundName))
                print("🔔 🔊 使用系统铃声: \(soundName)")
            } else {
                content.sound = .default
                print("🔔 🔊 使用默认通知声音")
            }
        }
        
        content.badge = 1
        
        // 添加用户信息，包含确认相关信息
        content.userInfo = [
            "scheduleId": item.id.uuidString,
            "scheduleTitle": item.title
        ]
        
        // 添加通知图标附件
        if let iconURL = Bundle.main.url(forResource: "notification_icon", withExtension: "png") {
            do {
                let attachment = try UNNotificationAttachment(identifier: "notification_icon", url: iconURL, options: nil)
                content.attachments = [attachment]
                print("🔔 🎨 已添加通知图标附件")
            } catch {
                print("🔔 ❌ 添加通知图标附件失败: \(error)")
            }
        } else {
            print("🔔 ⚠️ 未找到通知图标文件")
        }
        
        // 设置通知类别（用于真机上的交互操作）
        content.categoryIdentifier = "UPCOMING_SCHEDULE"
        
        // 使用设备助手获取推荐配置
        let recommendedContent = DeviceNotificationHelper.shared.getRecommendedNotificationContent()
        if #available(iOS 15.0, *) {
            content.interruptionLevel = recommendedContent.interruptionLevel
            content.relevanceScore = recommendedContent.relevanceScore
            print("🔔 📱 应用推荐的通知配置 - 中断级别: \(content.interruptionLevel.rawValue), 相关性: \(content.relevanceScore)")
        }
        
        // 计算提醒时间
        let reminderDate: Date
        if let customReminderTime = item.reminderTime {
            reminderDate = customReminderTime
        } else {
            // 确保提前提醒分钟数大于0
            let minutesBefore = max(item.reminderMinutesBefore, 1)
            reminderDate = Calendar.current.date(
                byAdding: .minute,
                value: -minutesBefore,
                to: item.startTime
            ) ?? item.startTime
        }
        
        print("🔔 日程开始时间: \(item.startTime)")
        print("🔔 计算的提醒时间: \(reminderDate)")
        print("🔔 提前提醒分钟数: \(item.reminderMinutesBefore)")
        print("🔔 当前时间: \(Date())")
        
        // 使用设备助手获取推荐的缓冲时间
        let bufferTime = DeviceNotificationHelper.shared.getRecommendedBufferTime()
        print("🔔 推荐缓冲时间: \(bufferTime)秒")
        
        // 检查提醒时间是否在未来（给足够的缓冲时间）
        let currentTime = Date()
        let minimumFutureTime = currentTime.addingTimeInterval(bufferTime)
        
        if reminderDate <= minimumFutureTime {
            print("🔔 ⚠️ 提醒时间已过期或太接近当前时间")
            print("🔔 ⚠️ 提醒时间: \(reminderDate)")
            print("🔔 ⚠️ 最小未来时间: \(minimumFutureTime)")
            print("🔔 ⚠️ 缓冲时间: \(bufferTime)秒")
            return
        }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: reminderDate)
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let notificationId = item.notificationId ?? "schedule_\(item.id.uuidString)"
        let request = UNNotificationRequest(identifier: notificationId, content: content, trigger: trigger)
        
        print("🔔 通知ID: \(notificationId)")
        print("🔔 通知触发器组件: \(components)")
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("🔔 ❌ 添加通知失败: \(error)")
                print("🔔 ❌ 错误详情: \(error.localizedDescription)")
            } else {
                print("🔔 ✅ 通知添加成功")
                
                // 如果启用了重复提醒功能，调度重复提醒
        // if item.repeatReminderEnabled && !item.isReminderConfirmed && !item.isCompleted {
        //     DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        //         self.scheduleRepeatReminder(for: item)
        //     }
        // }
                
                // 验证通知是否真的被添加了
                UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                    let matchingRequest = requests.first { $0.identifier == notificationId }
                    if let request = matchingRequest {
                        print("🔔 ✅ 验证成功 - 通知已在待处理队列中")
                        print("🔔 ✅ 通知内容: \(request.content.body)")
                        if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                            print("🔔 ✅ 触发时间: \(trigger.dateComponents)")
                        }
                    } else {
                        print("🔔 ❌ 验证失败 - 通知未在待处理队列中找到")
                    }
                    
                    // 打印所有待处理通知的数量
                    print("🔔 📊 当前待处理通知总数: \(requests.count)")
                }

                // 周年：在开始前一周内每日提醒一次
                if item.isFestival && item.isYearlyRecurring && item.hasReminder {
                    self.schedulePreAnniversaryDailyReminders(for: item)
                }
            }
        }
    }
    
    // 取消日程通知
    func cancelNotification(for item: ScheduleItem) {
        guard let notificationId = item.notificationId else { return }
        
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationId])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notificationId])

        // 额外清理：周年提前一周每日提醒
        let center = UNUserNotificationCenter.current()
        Task {
            let pending = await center.pendingNotificationRequests()
            let prefix = "pre_anniv_\(item.id.uuidString)_"
            let relatedIds = pending
                .map { $0.identifier }
                .filter { $0.hasPrefix(prefix) }
            if !relatedIds.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: relatedIds)
                center.removeDeliveredNotifications(withIdentifiers: relatedIds)
                print("🧹 已清理周年每日提醒 \(relatedIds.count) 条，标识前缀: \(prefix)")
            }
        }
    }
    
    // 更新通知
    func updateNotification(for item: ScheduleItem) {
        cancelNotification(for: item)
        if item.hasReminder {
            scheduleNotification(for: item)
        }
    }
    
    // 批量安排通知
    func scheduleNotifications(for items: [ScheduleItem]) {
        for item in items {
            if item.hasReminder {
                scheduleNotification(for: item)
            }
        }
    }

    // MARK: - 周年前一周每日提醒
    /// 为周年（节日，年度重复）在开始前一周内每日提醒一次
    private func schedulePreAnniversaryDailyReminders(for item: ScheduleItem) {
        guard isAuthorized, item.hasReminder, item.isFestival, item.isYearlyRecurring else { return }

        let center = UNUserNotificationCenter.current()
        let calendar = Calendar.current
        let now = Date()
        let bufferTime = DeviceNotificationHelper.shared.getRecommendedBufferTime()
        let minimumFutureTime = now.addingTimeInterval(bufferTime)

        // 基准提醒时间点（时/分）：优先使用自定义提醒时间，其次使用开始时间减去提前分钟数
        let baseReminderDate: Date = {
            if let custom = item.reminderTime { return custom }
            let minutesBefore = max(item.reminderMinutesBefore, 1)
            return Calendar.current.date(byAdding: .minute, value: -minutesBefore, to: item.startTime) ?? item.startTime
        }()
        let baseHM = calendar.dateComponents([.hour, .minute], from: baseReminderDate)

        // 先清理同一日程ID的既有“周年每日提醒”，避免重复
        Task {
            let pending = await center.pendingNotificationRequests()
            let prefix = "pre_anniv_\(item.id.uuidString)_"
            let existing = pending.filter { $0.identifier.hasPrefix(prefix) }.map { $0.identifier }
            if !existing.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: existing)
                print("🧹 清理已有周年每日提醒 \(existing.count) 条，准备重新调度")
            }

            // 调度 1..7 天前的每日提醒
            for day in 1...7 {
                guard let targetDay = calendar.date(byAdding: .day, value: -day, to: item.startTime) else { continue }
                var comps = calendar.dateComponents([.year, .month, .day], from: targetDay)
                comps.hour = baseHM.hour
                comps.minute = baseHM.minute
                comps.second = 0

                // 具体触发日期时间
                let triggerDate = calendar.date(from: comps) ?? targetDay
                if triggerDate <= minimumFutureTime { continue } // 过去或太近，跳过

                let id = String(format: "pre_anniv_%@_%04d%02d%02d",
                                 item.id.uuidString,
                                 comps.year ?? 0,
                                 comps.month ?? 0,
                                 comps.day ?? 0)

                // 组装通知内容
                let content = UNMutableNotificationContent()
                content.title = "周年倒计时提醒"
                content.body = "「\(item.title)」还有 \(day) 天"
                content.categoryIdentifier = "UPCOMING_SCHEDULE"
                content.badge = 1

                // 声音沿用原提醒设置
                if item.reminderSound == .defaultSound {
                    content.sound = .default
                } else if item.reminderSound == .custom, let customURL = item.customSoundURL {
                    let soundName = customURL.lastPathComponent
                    content.sound = UNNotificationSound(named: UNNotificationSoundName(soundName))
                } else if let systemSoundName = item.reminderSound.systemSoundName {
                    let soundName = "\(systemSoundName).wav"
                    content.sound = UNNotificationSound(named: UNNotificationSoundName(soundName))
                } else {
                    content.sound = .default
                }

                // 图标附件（如有）
                if let iconURL = Bundle.main.url(forResource: "notification_icon", withExtension: "png"),
                   let attachment = try? UNNotificationAttachment(identifier: "notification_icon", url: iconURL, options: nil) {
                    content.attachments = [attachment]
                }

                content.userInfo = [
                    "scheduleId": item.id.uuidString,
                    "scheduleTitle": item.title,
                    "notificationType": "pre_anniversary",
                    "daysRemaining": day
                ]

                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

                do {
                    try await center.add(request)
                    print("📅 已调度周年每日提醒：\(id) 于 \(String(describing: trigger.nextTriggerDate()))")
                } catch {
                    print("📅 周年每日提醒调度失败：\(error)")
                }
            }
        }
    }
    
    // 清除所有通知
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
    
    // 获取待处理的通知数量
    func getPendingNotificationCount() async -> Int {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return requests.count
    }
    
    // 获取所有待处理的通知详情（用于调试）
    func debugPendingNotifications() async {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        print("🔔 当前待处理通知数量: \(requests.count)")
        
        for request in requests {
            print("🔔 通知ID: \(request.identifier)")
            print("🔔 通知标题: \(request.content.title)")
            print("🔔 通知内容: \(request.content.body)")
            
            if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                print("🔔 触发时间: \(trigger.dateComponents)")
            }
            print("---")
        }
    }

    // MARK: - 每日固定时点的过期汇总
    /// 读取用户设定的每日汇总时间，默认 21:00
    private func getDailySummaryTime() -> DateComponents {
        let setHour = UserDefaults.standard.object(forKey: "DailyOverdueSummaryHour") as? Int
        let setMinute = UserDefaults.standard.object(forKey: "DailyOverdueSummaryMinute") as? Int
        let hour = setHour ?? 21
        let minute = setMinute ?? 0
        return DateComponents(hour: hour, minute: minute)
    }

    /// 根据当前计划，预定下一次“过期汇总”通知（不重复，每天重新调度）
    func scheduleNextDailyOverdueSummary(schedules: [ScheduleItem]) async {
        guard isAuthorized else { return }
        let center = UNUserNotificationCenter.current()
        let calendar = Calendar.current
        let now = Date()

        // 若用户关闭了“每日过期汇总”，则清理已预定的每日汇总请求并跳过调度
        let isEnabled = (UserDefaults.standard.object(forKey: "DailyOverdueSummaryEnabled") as? Bool) ?? true
        if !isEnabled {
            let pending = await center.pendingNotificationRequests()
            let ids = pending.filter { $0.identifier.hasPrefix("overdue_daily_") }.map { $0.identifier }
            if !ids.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: ids)
                print("🔔 已关闭每日过期汇总，清理 \(ids.count) 个每日请求")
            } else {
                print("🔔 已关闭每日过期汇总，无每日请求需要清理")
            }
            return
        }

        // 计算下一次触发的日期
        var time = getDailySummaryTime()
        var nextDate = calendar.nextDate(after: now, matching: time, matchingPolicy: .nextTimePreservingSmallerComponents) ?? now
        if nextDate <= now {
            nextDate = calendar.date(byAdding: .day, value: 1, to: nextDate) ?? now.addingTimeInterval(24*3600)
        }

        // 生成已过期的计划摘要（到下一次触发时间为止）
        let overdueSchedules = schedules.filter { item in
            !item.isCompleted && item.endTime < nextDate
        }
        let count = overdueSchedules.count
        let topTitles = overdueSchedules.prefix(3).map { $0.title }
        let details = topTitles.joined(separator: "、")

        let content = UNMutableNotificationContent()
        content.title = "有计划已过期"
        if topTitles.isEmpty {
            content.body = "您有 \(count) 个计划已过期，请及时处理"
        } else if count <= 3 {
            content.body = "已过期：\(details)"
        } else {
            content.body = "已过期：\(details) 等，共 \(count) 个"
        }
        content.sound = .default
        content.badge = NSNumber(value: max(count, 1))
        content.categoryIdentifier = "OVERDUE_SCHEDULE"
        content.userInfo = [
            "notificationType": "overdue_daily",
            "overdueCount": count,
            "overdueTitles": topTitles
        ]

        if let iconURL = Bundle.main.url(forResource: "notification_icon", withExtension: "png"),
           let attachment = try? UNNotificationAttachment(identifier: "notification_icon", url: iconURL, options: nil) {
            content.attachments = [attachment]
        }

        // 当前日期对应的标识（例如 overdue_daily_20251105）
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: nextDate)
        let identifier = String(format: "overdue_daily_%04d%02d%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)

        // 查询已存在的“每日汇总”请求，避免重复调度和不必要的增删操作
        let pending = await center.pendingNotificationRequests()
        let existingDaily = pending.filter { $0.identifier.hasPrefix("overdue_daily_") }
        let alreadyScheduledForToday = existingDaily.contains { $0.identifier == identifier }

        if alreadyScheduledForToday {
            // 如果今天的汇总已经预定，则直接跳过，避免重复工作
            print("🔔 今日每日过期汇总已存在（标识: \(identifier)），跳过重新预定")
            return
        }

        // 清理旧的每日汇总（非今天的），避免积累
        let outdatedIdentifiers = existingDaily.map { $0.identifier }.filter { $0 != identifier }
        if !outdatedIdentifiers.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: outdatedIdentifiers)
            print("🔔 已移除过期的每日过期汇总通知 \(outdatedIdentifiers.count) 条")
        }

        // 使用非重复触发器，便于每日重算内容
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        do {
            try await center.add(request)
            print("📅 已预定每日过期汇总通知于: \(nextDate)")
        } catch {
            print("📅 预定每日过期汇总通知失败: \(error)")
        }
    }
    
    // MARK: - 增强功能：计划状态检查和到期提醒
    
    // 检查即将开始的计划并发送提醒
    func checkUpcomingSchedules(schedules: [ScheduleItem]) async {
        let now = Date()
        let upcomingThreshold = now.addingTimeInterval(15 * 60) // 15分钟内
        
        for schedule in schedules {
            guard !schedule.isCompleted && schedule.startTime > now && schedule.startTime <= upcomingThreshold else {
                continue
            }
            
            await sendUpcomingNotification(for: schedule)
        }
    }
    
    // 检查已过期的计划（只检查当日的）
    func checkOverdueSchedules(schedules: [ScheduleItem]) async -> [ScheduleItem] {
        let now = Date()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        
        let overdueSchedules = schedules.filter { schedule in
            !schedule.isCompleted && 
            schedule.endTime < now &&
            calendar.isDate(schedule.startTime, inSameDayAs: today)
        }
        
        if !overdueSchedules.isEmpty {
            await sendOverdueNotification(schedules: overdueSchedules)
        }
        
        return overdueSchedules
    }
    
    // 发送即将开始的计划通知
    private func sendUpcomingNotification(for schedule: ScheduleItem) async {
        let content = UNMutableNotificationContent()
        // 计算距开始的剩余时间，优化提示语气
        let now = Date()
        let remainingSeconds = max(0, Int(schedule.startTime.timeIntervalSince(now)))
        let remainingMinutes = max(1, Int(ceil(Double(remainingSeconds) / 60.0)))
        if remainingMinutes <= 1 {
            content.title = "温馨提醒：日程即将开始"
            content.body = "「\(schedule.title)」马上开始啦，祝你顺利！"
        } else {
            content.title = "温馨提醒：日程即将开始"
            content.body = "「\(schedule.title)」将在 \(remainingMinutes) 分钟后开始，做好准备哦。"
        }
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = "UPCOMING_SCHEDULE"
        
        // 添加通知图标附件
        if let iconURL = Bundle.main.url(forResource: "notification_icon", withExtension: "png") {
            do {
                let attachment = try UNNotificationAttachment(identifier: "notification_icon", url: iconURL, options: nil)
                content.attachments = [attachment]
                print("🔔 🎨 已添加通知图标附件（即将开始）")
            } catch {
                print("🔔 ❌ 添加通知图标附件失败（即将开始）: \(error)")
            }
        }
        
        content.userInfo = [
            "scheduleId": schedule.id.uuidString,
            "scheduleTitle": schedule.title,
            "notificationType": "upcoming"
        ]
        
        let request = UNNotificationRequest(
            identifier: "upcoming_\(schedule.id.uuidString)",
            content: content,
            trigger: nil // 立即发送
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("📱 已发送即将开始通知: \(schedule.title)")
        } catch {
            print("📱 发送即将开始通知失败: \(error)")
        }
    }
    
    // 发送过期计划汇总通知（包含部分具体标题）
    private func sendOverdueNotification(schedules: [ScheduleItem]) async {
        let count = schedules.count
        let topTitles = schedules.prefix(3).map { $0.title }
        let details = topTitles.joined(separator: "、")
        let content = UNMutableNotificationContent()
        content.title = "有计划已过期"
        // 显示部分具体过期计划标题，便于用户快速识别
        if topTitles.isEmpty {
            content.body = "您有 \(count) 个计划已过期，请及时处理"
        } else if count <= 3 {
            content.body = "已过期：\(details)"
        } else {
            content.body = "已过期：\(details) 等，共 \(count) 个"
        }
        content.sound = .default
        content.badge = NSNumber(value: count)
        content.categoryIdentifier = "OVERDUE_SCHEDULE"
        
        // 添加通知图标附件
        if let iconURL = Bundle.main.url(forResource: "notification_icon", withExtension: "png") {
            do {
                let attachment = try UNNotificationAttachment(identifier: "notification_icon", url: iconURL, options: nil)
                content.attachments = [attachment]
                print("🔔 🎨 已添加通知图标附件（过期计划）")
            } catch {
                print("🔔 ❌ 添加通知图标附件失败（过期计划）: \(error)")
            }
        }
        
        content.userInfo = [
            "notificationType": "overdue",
            "overdueCount": count,
            "overdueTitles": topTitles
        ]
        
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
    
    // 设置通知类别和操作
    func setupNotificationCategories() {
        let upcomingCategory = UNNotificationCategory(
            identifier: "UPCOMING_SCHEDULE",
            actions: [
                UNNotificationAction(
                    identifier: "MARK_COMPLETED",
                    title: "标记完成",
                    options: []
                )
            ],
            intentIdentifiers: [],
            options: []
        )
        
        let overdueCategory = UNNotificationCategory(
            identifier: "OVERDUE_SCHEDULE",
            actions: [
                UNNotificationAction(
                    identifier: "VIEW_OVERDUE",
                    title: "查看过期计划",
                    options: [.foreground]
                )
            ],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([upcomingCategory, overdueCategory])
    }
    
    // 批量检查和更新计划通知状态
    func refreshScheduleNotifications(schedules: [ScheduleItem]) async {
        print("🔄 开始刷新计划通知状态")
        
        // 检查即将开始的计划
        await checkUpcomingSchedules(schedules: schedules)
        
        // 检查过期的计划
        let overdueSchedules = await checkOverdueSchedules(schedules: schedules)
        
        // 清理已完成或已删除计划的通知
        await cleanupCompletedScheduleNotifications(schedules: schedules)
        
        print("🔄 计划通知状态刷新完成，发现 \(overdueSchedules.count) 个过期计划")
    }
    
    // 清理已完成计划的通知
    private func cleanupCompletedScheduleNotifications(schedules: [ScheduleItem]) async {
        let completedSchedules = schedules.filter { $0.isCompleted }
        let identifiersToRemove = completedSchedules.compactMap { schedule in
            schedule.notificationId ?? "schedule_\(schedule.id.uuidString)"
        }
        
        if !identifiersToRemove.isEmpty {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiersToRemove)
            print("🧹 已清理 \(identifiersToRemove.count) 个已完成计划的通知")
        }
    }
}

// MARK: - 通知代理
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    
    // 应用在前台时收到通知
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        // 在前台显示通知
        completionHandler([.banner, .sound, .badge])
    }
    
    // 用户点击通知时的处理
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        let userInfo = response.notification.request.content.userInfo
        
        // 处理通知操作
        switch response.actionIdentifier {
        case "MARK_COMPLETED":
            if let scheduleId = userInfo["scheduleId"] as? String {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("MarkScheduleCompleted"),
                        object: nil,
                        userInfo: ["scheduleId": scheduleId]
                    )
                }
            }
            
        case "VIEW_OVERDUE":
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("ViewOverdueSchedules"),
                    object: nil,
                    userInfo: userInfo
                )
            }
            
        case UNNotificationDefaultActionIdentifier:
            // 默认点击通知的处理
            if let scheduleId = userInfo["scheduleId"] as? String {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ScheduleNotificationTapped"),
                        object: nil,
                        userInfo: ["scheduleId": scheduleId]
                    )
                }
            } else if let type = userInfo["notificationType"] as? String, type == "overdue" {
                // 过期汇总通知的默认点击：触发查看过期计划
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ViewOverdueSchedules"),
                        object: nil,
                        userInfo: userInfo
                    )
                }
            }
            
        default:
            break
        }
        
        completionHandler()
    }
    
    // 调度延迟提醒通知
    private func scheduleSnoozeNotification(scheduleId: String, title: String) {
        let content = UNMutableNotificationContent()
        content.title = "延迟提醒"
        content.body = title
        content.sound = .default
        content.badge = 1
        
        // 添加通知图标附件
        if let iconURL = Bundle.main.url(forResource: "notification_icon", withExtension: "png") {
            do {
                let attachment = try UNNotificationAttachment(identifier: "notification_icon", url: iconURL, options: nil)
                content.attachments = [attachment]
                print("🔔 🎨 已添加通知图标附件（延迟提醒）")
            } catch {
                print("🔔 ❌ 添加通知图标附件失败（延迟提醒）: \(error)")
            }
        }
        
        content.userInfo = [
            "scheduleId": scheduleId,
            "scheduleTitle": title,
            "notificationType": "snooze"
        ]
        
        // 5分钟后触发
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5 * 60, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "snooze_\(scheduleId)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("📱 调度延迟提醒失败: \(error)")
            } else {
                print("📱 已调度5分钟延迟提醒: \(title)")
            }
        }
    }
}
