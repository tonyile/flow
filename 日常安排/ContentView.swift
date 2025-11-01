import SwiftUI

struct ContentView: View {
    @ObservedObject var scheduleStore: ScheduleStore
    @StateObject private var flowStore = FlowStore.shared
    @EnvironmentObject var colorSchemeManager: ColorSchemeManager
    @State private var selectedTab = 0
    @State private var selectedDate = Date()
    @State private var showingAddSchedule = false
    @State private var showingAddFlow = false
    @State private var showingSettings = false
    @State private var showingStatistics = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 主要内容区域 - 支持6个页面的连续滑动切换
            TabView(selection: $selectedTab) {
                // Day视图 - 包装在RegionalGestureView中
                RegionalGestureView(
                    selectedTab: $selectedTab,
                    currentTab: 0,
                    isDateView: true
                ) {
                    DayView(scheduleStore: scheduleStore, currentViewMode: .constant(.day))
                }
                .tag(0)
                
                // Week视图 - 包装在RegionalGestureView中
                RegionalGestureView(
                    selectedTab: $selectedTab,
                    currentTab: 1,
                    isWeekView: true
                ) {
                    WeekView(scheduleStore: scheduleStore, currentViewMode: .constant(.week))
                }
                .tag(1)
                
                // Month视图 - 包装在RegionalGestureView中
                RegionalGestureView(
                    selectedTab: $selectedTab,
                    currentTab: 2,
                    isDateView: true
                ) {
                    MonthView(scheduleStore: scheduleStore, currentViewMode: .constant(.month))
                }
                .tag(2)
                
                // Flow视图 - 包装在RegionalGestureView中
                RegionalGestureView(
                    selectedTab: $selectedTab,
                    currentTab: 3,
                    isDateView: false
                ) {
                    FlowView()
                }
                .tag(3)
                
                // Statistics视图 - 包装在RegionalGestureView中
                RegionalGestureView(
                    selectedTab: $selectedTab,
                    currentTab: 4,
                    isStatisticsView: true
                ) {
                    StatisticsView(scheduleStore: scheduleStore)
                }
                .tag(4)
                
                // Settings视图 - 包装在RegionalGestureView中
                RegionalGestureView(
                    selectedTab: $selectedTab,
                    currentTab: 5,
                    isDateView: false
                ) {
                    SettingsView(scheduleStore: scheduleStore)
                }
                .tag(5)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never)) // 启用滑动切换，隐藏页面指示器
            .ignoresSafeArea(.container, edges: .bottom) // 让内容延伸到底部
            .gesture(
                // 全局页面切换手势 - 优先级较低
                DragGesture(minimumDistance: 50)
                    .onEnded { value in
                        let horizontalDistance = abs(value.translation.width)
                        let verticalDistance = abs(value.translation.height)
                        
                        // 只有在水平滑动且距离足够时才切换页面
                        if horizontalDistance > verticalDistance && horizontalDistance > 80 {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                if value.translation.width > 0 && selectedTab > 0 {
                                    selectedTab -= 1
                                } else if value.translation.width < 0 && selectedTab < 5 {
                                    selectedTab += 1
                                }
                            }
                        }
                    }
            )
            
            Spacer(minLength: 20)
            
            // 底部导航栏
            HStack(spacing: 0) {
                TabBarButton(
                    icon: "clock",
                    title: "时光",
                    isSelected: selectedTab >= 0 && selectedTab <= 2, // day/week/month都属于时光
                    action: { 
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            if selectedTab < 0 || selectedTab > 2 {
                                selectedTab = 1 // 默认切换到week视图
                            }
                        }
                    }
                )
                
                TabBarButton(
                    icon: "drop",
                    title: "流水",
                    isSelected: selectedTab == 3,
                    action: { selectedTab = 3 },
                    isDropIcon: true
                )
                
                TabBarButton(
                    icon: "chart.bar",
                    title: "统计",
                    isSelected: selectedTab == 4,
                    action: { selectedTab = 4 }
                )
                
                TabBarButton(
                    icon: "gearshape",
                    title: "设置",
                    isSelected: selectedTab == 5,
                    action: { selectedTab = 5 }
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 6)
            .padding(.vertical, 4)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.customBrandPrimary.opacity(0.3), Color.customBrandSecondary.opacity(0.3)]),
                    startPoint: .leading,
                    endPoint: .trailing
                ).clipShape(Capsule())
            )
            .padding(.horizontal, 20)
        }
        .background(Color.clear) // 设置透明背景，移除系统默认的白色背景
        .transparentTabBar() // 应用透明TabBar配置
    }
}

// 自定义标签栏按钮
struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    let isDropIcon: Bool
    @State private var dropOffset: CGFloat = 0
    @EnvironmentObject var colorSchemeManager: ColorSchemeManager
    
    init(icon: String, title: String, isSelected: Bool, action: @escaping () -> Void, isDropIcon: Bool = false) {
        self.icon = icon
        self.title = title
        self.isSelected = isSelected
        self.action = action
        self.isDropIcon = isDropIcon
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        // 选中状态的背景
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.customBrandPrimary.opacity(0.15))
                            .frame(width: 56, height: 32)
                            .scaleEffect(1.0)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isSelected)
                    }
                    
                    if isDropIcon {
                        // 水滴效果背景
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        Color.customBrandPrimary.opacity(0.3),
                                        Color.customBrandPrimary.opacity(0.1),
                                        Color.clear
                                    ]),
                                    center: .center,
                                    startRadius: 5,
                                    endRadius: 18
                                )
                            )
                            .frame(width: 36, height: 36)
                            .scaleEffect(isSelected ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.3), value: isSelected)
                            .offset(y: dropOffset)
                            .onAppear {
                                // 持续的水滴下落动画
                                withAnimation(
                                    Animation.easeInOut(duration: 2.0)
                                        .repeatForever(autoreverses: true)
                                ) {
                                    dropOffset = 3
                                }
                            }
                    }
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(
                            isSelected ? .customBrandPrimary : 
                            (isDropIcon ? Color.blue.opacity(0.8) : Color.gray.opacity(0.7))
                        )
                        .frame(height: 18)
                        .scaleEffect(isSelected ? 1.1 : 1.0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isSelected)
                        .offset(y: isDropIcon ? dropOffset : 0)
                }
                
                Text(title)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(
                        isSelected ? .customBrandPrimary : 
                        (isDropIcon ? Color.blue.opacity(0.8) : Color.gray.opacity(0.7))
                    )
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ContentView(scheduleStore: ScheduleStore.shared)
        .environmentObject(NotificationManager.shared)
        .environmentObject(CloudKitManager.shared)
}
