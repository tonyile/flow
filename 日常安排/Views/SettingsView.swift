import SwiftUI
import UserNotifications

struct SettingsView: View {
    @ObservedObject var scheduleStore: ScheduleStore
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var cloudKitManager: CloudKitManager
    
    @State private var showingPermissionAlert = false
    @State private var showingSyncAlert = false
    @State private var showingClearAllAlert = false
    @State private var syncMessage = ""
    @State private var showingScheduleMergeView = false
    @State private var duplicateCleanupResult: String?
    @State private var showingCleanupAlert = false

    
    var body: some View {
        NavigationView {
            Form {
                // 通知设置
                Section(header: Text("通知设置")) {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.15))
                                .frame(width: 28, height: 28)
                            Image(systemName: "bell")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        Text("通知权限")
                        Spacer()
                        if notificationManager.isAuthorized {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.green)
                                Text("已授权")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        } else {
                            Button("请求权限") {
                                requestNotificationPermission()
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }
                    
                    if notificationManager.isAuthorized {
                        Button(action: {
                            notificationManager.clearAllNotifications()
                        }) {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(Color.red.opacity(0.15))
                                        .frame(width: 28, height: 28)
                                    Image(systemName: "trash")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.red)
                                }
                                Text("清除所有通知")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                .listRowSeparator(.hidden)
                
                // iCloud同步设置
                Section(header: Text("iCloud同步")) {
                    // 云同步开关
                    HStack {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.15))
                                .frame(width: 28, height: 28)
                            Image(systemName: "icloud")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        Text("启用云同步")
                        Spacer()
                        Toggle("", isOn: $cloudKitManager.isCloudSyncEnabled)
                            .onChange(of: cloudKitManager.isCloudSyncEnabled) { _, newValue in
                                if newValue {
                                    cloudKitManager.checkAccountStatus()
                                }
                            }
                    }
                    
                    if cloudKitManager.isCloudSyncEnabled {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.gray.opacity(0.15))
                                    .frame(width: 28, height: 28)
                                Image(systemName: "person")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.gray)
                            }
                            Text("iCloud状态")
                            Spacer()
                            if cloudKitManager.isSignedIn {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.green)
                                    Text("已登录")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            } else {
                                HStack(spacing: 4) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.red)
                                    Text("未登录")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        
                        if cloudKitManager.isSignedIn {
                            Button(action: {
                                performManualSync()
                            }) {
                                HStack {
                                    ZStack {
                                        Circle()
                                            .fill(Color.blue.opacity(0.15))
                                            .frame(width: 28, height: 28)
                                        if cloudKitManager.isSyncing {
                                            ProgressView()
                                                .scaleEffect(0.6)
                                        } else {
                                            Image(systemName: "arrow.clockwise")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    Text("手动同步")
                                        .foregroundColor(.blue)
                                }
                            }
                            .disabled(cloudKitManager.isSyncing)
                            
                            if let lastSyncDate = cloudKitManager.lastSyncDate {
                                Text("上次同步: \(lastSyncDate, formatter: dateFormatter)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            // 突出显示未登录状态
                            VStack(alignment: .leading, spacing: 12) {
                                // 警告提示
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.orange)
                                    Text("iCloud未登录")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.orange)
                                }
                                
                                // 说明文字
                                Text("请在设置中登录 iCloud 账户以启用云同步功能，确保数据在多设备间同步。")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                // 登录引导按钮
                                Button(action: {
                                    // 打开系统设置的iCloud页面
                                    if let settingsUrl = URL(string: "App-Prefs:root=CASTLE") {
                                        UIApplication.shared.open(settingsUrl)
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "gear")
                                            .font(.system(size: 12, weight: .medium))
                                        Text("前往设置登录")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.blue)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.orange.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                    }
                    

                }
                .listRowSeparator(.hidden)
                
                // 日程管理
                Section(header: Text("日程管理")) {
                    Button(action: {
                        showingScheduleMergeView = true
                    }) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.orange.opacity(0.15))
                                    .frame(width: 28, height: 28)
                                Image(systemName: "arrow.triangle.merge")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.orange)
                            }
                            Text("日程合并")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                    
                    Button(action: {
                        let cleanedCount = scheduleStore.autoCleanDuplicates()
                        duplicateCleanupResult = cleanedCount > 0 ? 
                            "已清理 \(cleanedCount) 个重复日程" : 
                            "未发现重复日程"
                        showingCleanupAlert = true
                    }) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.purple.opacity(0.15))
                                    .frame(width: 28, height: 28)
                                Image(systemName: "sparkles")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.purple)
                            }
                            Text("清理重复日程")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                }
                .listRowSeparator(.hidden)
                
                // 数据统计
                Section(header: Text("数据统计")) {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.15))
                                .frame(width: 28, height: 28)
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.green)
                        }
                        Text("已完成日程")
                        Spacer()
                        Text("\(scheduleStore.completedItemsCount)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    
                    HStack {
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.15))
                                .frame(width: 28, height: 28)
                            Image(systemName: "clock")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.orange)
                        }
                        Text("待完成日程")
                        Spacer()
                        Text("\(scheduleStore.pendingItemsCount)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    
                    HStack {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.15))
                                .frame(width: 28, height: 28)
                            Image(systemName: "calendar")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        Text("今日日程")
                        Spacer()
                        Text("\(scheduleStore.todayItemsCount)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    
                    Button(action: {
                        showingClearAllAlert = true
                    }) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.red.opacity(0.15))
                                    .frame(width: 28, height: 28)
                                Image(systemName: "trash")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.red)
                            }
                            Text("清除所有日程")
                                .foregroundColor(.red)
                        }
                    }
                }
                .listRowSeparator(.hidden)
                
                // 应用信息
                Section(header: Text("应用信息")) {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.15))
                                .frame(width: 28, height: 28)
                            Image(systemName: "info.circle")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.15))
                                .frame(width: 28, height: 28)
                            Image(systemName: "envelope")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        Text("反馈")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .listRowSeparator(.hidden)
            }
            .navigationTitle("设置")
            .alert("通知权限", isPresented: $showingPermissionAlert) {
                Button("确定") { }
            } message: {
                Text("通知权限请求已发送，请在系统设置中允许通知权限。")
            }
            .alert("同步结果", isPresented: $showingSyncAlert) {
                Button("确定") { }
            } message: {
                Text(syncMessage)
            }
            .alert("清除所有日程", isPresented: $showingClearAllAlert) {
                Button("取消", role: .cancel) { }
                Button("确定", role: .destructive) {
                    scheduleStore.clearAllSchedules()
                }
            } message: {
                Text("此操作将删除所有日程数据，包括本地和云端数据。此操作不可撤销，确定要继续吗？")
            }
            .sheet(isPresented: $showingScheduleMergeView) {
                ScheduleMergeView(scheduleStore: scheduleStore)
            }
            .alert("清理结果", isPresented: $showingCleanupAlert) {
                Button("确定") { }
            } message: {
                Text(duplicateCleanupResult ?? "")
            }
        }
    }
    
    private func requestNotificationPermission() {
        Task {
            let granted = await scheduleStore.requestNotificationPermission()
            await MainActor.run {
                if granted {
                    syncMessage = "通知权限已授权"
                } else {
                    syncMessage = "通知权限被拒绝，请在系统设置中手动开启"
                }
                showingPermissionAlert = true
            }
        }
    }
    
    private func performManualSync() {
        scheduleStore.manualSync()
        
        // 监听同步完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if cloudKitManager.isSyncing {
                syncMessage = "同步正在进行中..."
            } else {
                syncMessage = "同步完成"
            }
            showingSyncAlert = true
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
}

#Preview {
    SettingsView(scheduleStore: ScheduleStore.shared)
        .environmentObject(NotificationManager.shared)
        .environmentObject(CloudKitManager.shared)
}
