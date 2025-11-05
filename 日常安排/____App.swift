import SwiftUI
import Combine
import UserNotifications
import CloudKit
import BackgroundTasks

@main
struct TimeFlowApp: App {
    @StateObject private var store = ScheduleStore.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @StateObject private var backgroundTaskManager = BackgroundTaskManager.shared
    @StateObject private var colorSchemeManager = ColorSchemeManager.shared
    
    // 保持对通知代理的强引用
    private let notificationDelegate = NotificationDelegate()
    
    init() {
        // 设置通知代理
        UNUserNotificationCenter.current().delegate = notificationDelegate

        // 设置中文本地化
        UserDefaults.standard.set(["zh-Hans"], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()

        // 注册后台任务（尽早在应用启动阶段进行）
        #if os(iOS)
        BackgroundTaskManager.shared.registerBackgroundTasks()
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(notificationManager)
                .environmentObject(cloudKitManager)
                .environmentObject(backgroundTaskManager)
                .environmentObject(colorSchemeManager)
                .environment(\.locale, Locale(identifier: "zh-Hans"))
                .onAppear {
                    // 检查通知权限状态
                    notificationManager.checkAuthorizationStatus()
                    // 检查CloudKit账户状态
                    cloudKitManager.checkAccountStatus()
                    // 检查后台刷新状态
                    backgroundTaskManager.checkBackgroundRefreshStatus()
                    // 设置通知类别
                    notificationManager.setupNotificationCategories()
                }
                .task {
                    // 首次启动时自动请求通知权限
                    await notificationManager.requestNotificationPermissionIfNeeded()
                    // 刷新计划通知状态
                    await notificationManager.refreshScheduleNotifications(schedules: store.scheduleItems)
                }
                #if os(iOS)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    // 应用进入后台时调度后台任务
                    backgroundTaskManager.scheduleBackgroundRefresh()
                    backgroundTaskManager.scheduleBackgroundProcessing()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    // 应用即将进入前台时刷新通知状态
                    Task {
                        await notificationManager.refreshScheduleNotifications(schedules: store.scheduleItems)
                    }
                }
                #else
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didHideNotification)) { _ in
                    // 应用进入后台时调度后台任务
                    backgroundTaskManager.scheduleBackgroundRefresh()
                    backgroundTaskManager.scheduleBackgroundProcessing()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didUnhideNotification)) { _ in
                    // 应用即将进入前台时刷新通知状态
                    Task {
                        await notificationManager.refreshScheduleNotifications(schedules: store.scheduleItems)
                    }
                }
                #endif
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MarkScheduleCompleted"))) { notification in
                    // 处理通知操作：标记完成
                    DispatchQueue.main.async {
                        if let scheduleId = notification.userInfo?["scheduleId"] as? String,
                           let uuid = UUID(uuidString: scheduleId),
                           let index = store.scheduleItems.firstIndex(where: { $0.id == uuid }) {
                            store.scheduleItems[index].isCompleted = true
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ViewOverdueSchedules"))) { _ in
                    // 处理通知操作：查看过期计划
                    // 这里可以添加导航到过期计划视图的逻辑（确保主线程）
                    DispatchQueue.main.async {
                        // TODO: 导航到过期计划视图
                    }
                }
        }
    }
}
