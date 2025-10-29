import SwiftUI
import Foundation

struct DayView: View {
    @ObservedObject var scheduleStore: ScheduleStore
    @State private var selectedDate: Date = .now
    @State private var showAdd: Bool = false
    @State private var showCalendar: Bool = false
    @State private var showEditView: Bool = false
    @State private var editingItem: ScheduleItem?
    @StateObject private var weatherManager = WeatherManager.shared
    @Binding var currentViewMode: ViewMode // 从父视图接收视图模式绑定
    
    init(scheduleStore: ScheduleStore, currentViewMode: Binding<ViewMode>) {
        self.scheduleStore = scheduleStore
        self._currentViewMode = currentViewMode
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                content
            }
            .navigationTitle("")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        // 添加点击手势到日期标题
                        Button(action: {
                            showCalendar = true
                        }) {
                            coloredTitleView // 使用新的带颜色的标题视图
                        }
                        .buttonStyle(PlainButtonStyle()) // 保持原有样式
                    }
                }
                ToolbarItem(placement: .automatic) {
                    HStack(spacing: 8) {
                        // 视图模式切换按钮 - 在今日页面时隐藏
                        if currentViewMode != .day {
                            Button {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    currentViewMode = currentViewMode.nextMode
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: currentViewMode.icon)
                                        .font(.system(size: 16, weight: .medium))
                                    Text(currentViewMode.title)
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(.accentColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.accentColor.opacity(0.1))
                                )
                            }
                        }
                        
                        // 添加按钮 - 动感多彩小圆圈
                        AnimatedPlusButton {
                            showAdd = true
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddScheduleView(scheduleStore: scheduleStore, baseDate: selectedDate)
        }
        .sheet(isPresented: $showEditView) {
            if let editingItem = editingItem {
                EditScheduleView(scheduleItem: editingItem, scheduleStore: scheduleStore)
            }
        }
        .sheet(isPresented: $showCalendar) {
            NavigationView {
                CustomCalendarView(selectedDate: $selectedDate)
                    .navigationTitle("选择日期")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        #if os(iOS)
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("完成") {
                                showCalendar = false
                            }
                        }
                        #else
                        ToolbarItem(placement: .primaryAction) {
                            Button("完成") {
                                showCalendar = false
                            }
                        }
                        #endif
                    }
            }
            .presentationDetents([.medium, .large])
        }
        .onAppear {
            weatherManager.fetchWeather()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MonthSwitchGesture"))) { notification in
            // 监听月份切换手势通知
            if let userInfo = notification.userInfo,
               let direction = userInfo["direction"] as? Int,
               let viewType = userInfo["viewType"] as? Int,
               viewType == 0 { // DayView对应的tab是0
                
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    let calendar = Calendar.current
                    if let newDate = calendar.date(byAdding: .month, value: direction, to: selectedDate) {
                        selectedDate = newDate
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var customTitleView: some View {
        coloredTitleView // 统一使用带颜色的标题视图
    }
    
    @ViewBuilder
    private var content: some View {
        let items = scheduleStore.schedulesForDate(selectedDate)
        if items.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "calendar.badge.exclamationmark").font(.largeTitle)
                Text("今日暂无日程")
                    .foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(items, id: \.id) { item in
                    ScheduleCardView(item: item, scheduleStore: scheduleStore)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .contextMenu {
                            // 编辑功能 - 实际实现
                            Button {
                                editingItem = item
                                showEditView = true
                            } label: {
                                Label("编辑日程", systemImage: "pencil")
                            }
                            
                            // 完成状态切换
                            Button {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    scheduleStore.toggleCompletion(for: item.id)
                                }
                            } label: {
                                Label(item.isCompleted ? "标记为未完成" : "标记为完成", 
                                      systemImage: item.isCompleted ? "arrow.uturn.backward" : "checkmark.circle")
                            }
                            
                            Divider()
                            
                            // 删除功能 - 参考WeekView的实现
                            if item.isRecurring {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        scheduleStore.deleteSingleSchedule(with: item.id)
                                    }
                                } label: {
                                    Label("删除此日程", systemImage: "trash")
                                }
                                Button(role: .destructive) {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        scheduleStore.deleteAllRepeatingSchedules(with: item.id)
                                    }
                                } label: {
                                    Label("删除所有重复日程", systemImage: "trash.fill")
                                }
                            } else {
                                Button(role: .destructive) {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        scheduleStore.deleteSchedules(with: [item.id])
                                    }
                                } label: {
                                    Label("删除日程", systemImage: "trash")
                                }
                            }
                        }
                }
                .onDelete { indexSet in
                    let itemsToDelete = indexSet.map { items[$0] }
                    
                    for item in itemsToDelete {
                        if item.isFestival && item.isYearlyRecurring {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                scheduleStore.deleteSingleSchedule(with: item.id)
                            }
                        } else if item.isRecurring {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                scheduleStore.deleteSingleSchedule(with: item.id)
                            }
                        } else {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                scheduleStore.deleteSchedules(with: [item.id])
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .environment(\.defaultMinListRowHeight, 0)
            .clipShape(Rectangle())
            .animation(.easeInOut(duration: 0.3), value: items.count)
            .ignoresSafeArea(.container, edges: .bottom)
        }
    }

    private var dayFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "M月d日"  // 统一使用不显示年份的格式
        df.locale = Locale(identifier: "zh_CN")
        return df
    }
    
    private var enhancedDateTitle: String {
        let lunarInfo = ChineseLunarCalendar.shared.getLunarInfo(for: selectedDate)
        let festival = ChineseFestivalManager.shared.getPrimaryFestival(for: selectedDate)
        let baseTitle = dayFormatter.string(from: selectedDate)
        let lunarTitle = "\(lunarInfo.month)\(lunarInfo.day)"
        
        if let festival = festival {
            // 使用AttributedString来设置不同部分的颜色
            return "\(baseTitle) \(lunarTitle) \(festival.name)"
        } else {
            return "\(baseTitle) \(lunarTitle)"
        }
    }
    
    // 创建带颜色的标题视图
    @ViewBuilder
    private var coloredTitleView: some View {
        let lunarInfo = ChineseLunarCalendar.shared.getLunarInfo(for: selectedDate)
        let festival = ChineseFestivalManager.shared.getPrimaryFestival(for: selectedDate)
        let _ = Calendar.current.isDateInToday(selectedDate)  // isToday - 暂时未使用但保留
        let baseTitle = dayFormatter.string(from: selectedDate)  // 统一使用同一个格式器
        let lunarTitle = "\(lunarInfo.month)\(lunarInfo.day)"
        
        HStack(spacing: 4) {
            // 主日期 - 统一使用与其他页面一致的字体样式
            Text(baseTitle)
                .font(.system(.title2, design: .default, weight: .semibold))
                .foregroundColor(.primary)
            
            // 农历信息
            Text(lunarTitle)
                .font(.system(.caption2, design: .default, weight: .medium))
                .foregroundColor(.secondary)
            
            // 忆年信息 - 保持与MonthView一致的样式
            if let festival = festival {
                Text(festival.name)
                    .font(.system(.caption2, design: .default, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(festivalTextColor(for: festival.type, festivalName: festival.name))
                    )
            }
            
            // 天气信息
            WeatherDisplayView(date: selectedDate, weatherManager: weatherManager, isCompact: true)
        }
        .minimumScaleFactor(0.5)  // 提高缩放范围，允许缩小到50%
        .lineLimit(1)
        .allowsTightening(true)
        .truncationMode(.tail)  // 添加截断模式
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)  // 限制动态字体最大尺寸
    }
    
    // 忆年文字颜色
    private func festivalTextColor(for type: ChineseFestivalType, festivalName: String = "") -> Color {
        switch type {
        case .lunar:
            return .orange  // 传统节假日使用温暖的橙色
        case .solar:
            // 区分法定假日和普通公历忆年
            let legalHolidays = ["元旦", "劳动节", "国庆节"]
            if legalHolidays.contains(festivalName) {
                return .red  // 法定假日使用醒目的红色
            } else {
                return .accentColor  // 其他公历忆年使用品牌色（蓝色）
            }
        case .solarTerm:
            return .green.opacity(0.8)  // 节气使用浅绿色，弱化颜色强调信息性
        }
    }
}
