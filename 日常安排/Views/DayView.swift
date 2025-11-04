import SwiftUI
import Foundation

struct DayView: View {
    @ObservedObject var scheduleStore: ScheduleStore
    @State private var selectedDate: Date = .now
    @State private var showAdd: Bool = false
    @State private var showCalendar: Bool = false
    @State private var editingItem: ScheduleItem?
    @StateObject private var weatherManager = WeatherManager.shared
    @EnvironmentObject var colorSchemeManager: ColorSchemeManager
    @Environment(\.colorScheme) private var colorScheme

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
        .fullScreenCover(item: $editingItem) { editingItem in
            EditScheduleView(scheduleItem: editingItem, scheduleStore: scheduleStore)
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
            // 同步当前环境的颜色模式，确保切换后立即刷新
            colorSchemeManager.updateColors(for: colorScheme)
        }
        .onChange(of: colorScheme) { newScheme in
            colorSchemeManager.updateColors(for: newScheme)
        }
        .id(colorScheme)
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
                    .foregroundStyle(colorSchemeManager.secondary)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(items, id: \.id) { item in
                    ScheduleCardView(item: item, scheduleStore: scheduleStore, onEdit: {
                        editingItem = item
                    })
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .contextMenu {
                            // 编辑功能 - 实际实现
                            Button {
                                editingItem = item
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
                .foregroundColor(colorSchemeManager.primary)
            
            // 农历信息
            Text(lunarTitle)
                .font(.system(.caption2, design: .default, weight: .medium))
                .foregroundColor(colorSchemeManager.secondary)
            
            // 忆年信息 - 保持与MonthView一致的样式
            if let festival = festival {
                Text(festival.name)
                    .font(.system(.caption2, design: .default, weight: .medium))
                    .foregroundColor(colorSchemeManager.primary)
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
            return colorSchemeManager.lunarFestivalColor
        case .solar:
            let legalHolidays = ["元旦", "劳动节", "国庆节"]
            if legalHolidays.contains(festivalName) {
                return colorSchemeManager.legalHolidayColor
            } else {
                return colorSchemeManager.accent
            }
        case .solarTerm:
            return colorSchemeManager.solarTermColor
        }
    }
}
