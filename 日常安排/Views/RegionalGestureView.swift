import SwiftUI

/// 区域化手势识别视图
/// 在日期视图中，日期区域支持月份切换，其他区域支持页面切换
/// 在统计视图中，日期标题区域支持月份切换，其他区域支持页面切换
/// 在周视图中，日期区域支持周切换，其他区域支持页面切换
/// 在非日期视图中，全区域支持页面切换
struct RegionalGestureView<Content: View>: View {
    @Binding var selectedTab: Int
    let currentTab: Int
    let isDateView: Bool
    let isStatisticsView: Bool
    let isWeekView: Bool
    let content: () -> Content
    
    init(selectedTab: Binding<Int>, currentTab: Int, isDateView: Bool = false, isStatisticsView: Bool = false, isWeekView: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self._selectedTab = selectedTab
        self.currentTab = currentTab
        self.isDateView = isDateView
        self.isStatisticsView = isStatisticsView
        self.isWeekView = isWeekView
        self.content = content
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                content()
                
                // 如果是日期视图，添加透明的手势识别区域
                if isDateView {
                    // 日期区域 - 通常在顶部工具栏区域
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 100) // 工具栏和标题区域的高度
                        .position(x: geometry.size.width / 2, y: 50)
                        .gesture(
                            DragGesture(minimumDistance: 30)
                                .onEnded { value in
                                    handleDateAreaGesture(value)
                                }
                        )
                    
                    // 非日期区域 - 剩余的内容区域
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: geometry.size.height - 100)
                        .position(x: geometry.size.width / 2, y: geometry.size.height - (geometry.size.height - 100) / 2)
                        .gesture(
                            DragGesture(minimumDistance: 50)
                                .onEnded { value in
                                    handlePageSwitchGesture(value)
                                }
                        )
                } else if isStatisticsView {
                    // 统计视图的日期标题区域 - 顶部的日期标题和箭头按钮区域
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 80) // 日期标题区域的高度
                        .position(x: geometry.size.width / 2, y: 40)
                        .gesture(
                            DragGesture(minimumDistance: 30)
                                .onEnded { value in
                                    handleStatisticsDateAreaGesture(value)
                                }
                        )
                    
                    // 统计视图的其他区域 - 支持页面切换
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: geometry.size.height - 80)
                        .position(x: geometry.size.width / 2, y: geometry.size.height - (geometry.size.height - 80) / 2)
                        .gesture(
                            DragGesture(minimumDistance: 50)
                                .onEnded { value in
                                    handlePageSwitchGesture(value)
                                }
                        )
                } else if isWeekView {
                    // 周视图的日期区域 - 顶部的周导航栏区域
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 80) // 调整为更准确的周导航栏高度
                        .position(x: geometry.size.width / 2, y: 40)
                        .onAppear {
                        }
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 30)
                                .onEnded { value in
                                    handleWeekDateAreaGesture(value)
                                }
                        )
                    
                    // 周视图的其他区域 - 支持页面切换
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: geometry.size.height - 80)
                        .position(x: geometry.size.width / 2, y: geometry.size.height - (geometry.size.height - 80) / 2)
                        .gesture(
                            DragGesture(minimumDistance: 50)
                                .onEnded { value in
                                    handlePageSwitchGesture(value)
                                }
                        )
                } else {
                    // 非日期视图，全区域支持页面切换
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .gesture(
                            DragGesture(minimumDistance: 50)
                                .onEnded { value in
                                    handlePageSwitchGesture(value)
                                }
                        )
                }
            }
        }
    }
    
    /// 处理统计视图日期区域的手势 - 月份切换
    private func handleStatisticsDateAreaGesture(_ value: DragGesture.Value) {
        let horizontalDistance = abs(value.translation.width)
        let verticalDistance = abs(value.translation.height)
        
        // 只有在水平滑动且距离足够时才进行月份切换
        if horizontalDistance > verticalDistance && horizontalDistance > 50 {
            // 通知统计视图进行月份切换
            let direction = value.translation.width > 0 ? -1 : 1 // 左滑下一月，右滑上一月
            
            NotificationCenter.default.post(
                name: NSNotification.Name("StatisticsMonthSwitchGesture"),
                object: nil,
                userInfo: ["direction": direction]
            )
        }
    }
    
    /// 处理周视图日期区域的手势 - 周切换
    private func handleWeekDateAreaGesture(_ value: DragGesture.Value) {
        print("🔥 WeekView手势被触发: startLocation=\(value.startLocation), translation=\(value.translation)")
        
        let horizontalDistance = abs(value.translation.width)
        let verticalDistance = abs(value.translation.height)
        
        print("🔥 手势距离: horizontal=\(horizontalDistance), vertical=\(verticalDistance)")
        
        // 只有在水平滑动且距离足够时才进行周切换
        if horizontalDistance > verticalDistance && horizontalDistance > 50 {
            // 通知周视图进行周切换
            let direction = value.translation.width > 0 ? -1 : 1 // 左滑下一周，右滑上一周
            
            print("🔥 发送周切换通知: direction=\(direction)")
            
            NotificationCenter.default.post(
                name: NSNotification.Name("WeekSwitchGesture"),
                object: nil,
                userInfo: ["direction": direction]
            )
        } else {
            print("🔥 手势不满足条件，未触发周切换")
        }
    }
    
    /// 处理日期区域的手势 - 月份切换
    private func handleDateAreaGesture(_ value: DragGesture.Value) {
        let horizontalDistance = abs(value.translation.width)
        let verticalDistance = abs(value.translation.height)
        
        // 只有在水平滑动且距离足够时才进行月份切换
        if horizontalDistance > verticalDistance && horizontalDistance > 50 {
            // 这里需要通知对应的视图进行月份切换
            // 由于我们无法直接访问视图的内部状态，我们使用通知机制
            let direction = value.translation.width > 0 ? -1 : 1 // 左滑下一月，右滑上一月
            
            NotificationCenter.default.post(
                name: NSNotification.Name("MonthSwitchGesture"),
                object: nil,
                userInfo: ["direction": direction, "viewType": currentTab]
            )
        }
    }
    
    /// 处理页面切换手势
    private func handlePageSwitchGesture(_ value: DragGesture.Value) {
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
}

#Preview {
    RegionalGestureView(
        selectedTab: .constant(0),
        currentTab: 0,
        isDateView: true
    ) {
        Text("示例内容")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.blue.opacity(0.1))
    }
}