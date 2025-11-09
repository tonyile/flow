import SwiftUI
import Foundation
import Combine

// 专门的日历数据管理器，确保数据一致性
class CalendarDataManager: ObservableObject {
    @Published private(set) var days: [Date] = []
    @Published private(set) var isUpdating = false
    
    private var currentMonth: Date = .now
    private let calendar = Calendar.current
    private var updateTask: Task<Void, Never>?
    
    init() {
        print("📅 CalendarDataManager: 初始化")
        generateDays(for: .now)
    }
    
    deinit {
        updateTask?.cancel()
    }
    
    func updateMonth(_ newMonth: Date) {
        guard !calendar.isDate(currentMonth, equalTo: newMonth, toGranularity: .month) else { 
            print("📅 CalendarDataManager: 月份未变化，跳过更新")
            return 
        }
        
        // 取消之前的更新任务
        updateTask?.cancel()
        
        print("📅 CalendarDataManager: 开始更新月份 \(DateFormatter().string(from: newMonth))")
        isUpdating = true
        currentMonth = newMonth
        
        // 使用 Task 替代 DispatchQueue 确保更好的取消支持
        updateTask = Task { @MainActor [weak self] in
            guard let self = self, !Task.isCancelled else { return }
            
            print("📅 CalendarDataManager: 生成新月份数据")
            self.generateDays(for: newMonth)
            
            // 短暂延迟以确保UI更新完成
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
            
            guard !Task.isCancelled else { return }
            print("📅 CalendarDataManager: 更新完成，重置状态")
            self.isUpdating = false
        }
    }
    
    private func generateDays(for month: Date) {
        print("📅 CalendarDataManager: 开始生成日期数据 for \(DateFormatter().string(from: month))")
        
        // 获取当前月份的第一天
        guard let monthStart = calendar.dateInterval(of: .month, for: month)?.start else {
            print("❌ CalendarDataManager: 无法获取月份开始日期")
            days = []
            return
        }
        
        // 获取第一天是星期几（1=周日，2=周一...7=周六）
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        // 转换为周一开始的索引（0=周一，1=周二...6=周日）
        let mondayBasedWeekday = (firstWeekday + 5) % 7
        
        // 获取当前月份的天数
        guard let monthRange = calendar.range(of: .day, in: .month, for: month) else {
            print("❌ CalendarDataManager: 无法获取月份天数范围")
            days = []
            return
        }
        let daysInMonth = monthRange.count
        
        print("📅 CalendarDataManager: 月份信息 - 第一天星期: \(firstWeekday), 周一基准: \(mondayBasedWeekday), 天数: \(daysInMonth)")
        
        var newDays: [Date] = []
        newDays.reserveCapacity(42) // 预分配容量，提高性能
        
        // 添加上个月的尾部日期（填充前面的空白）
        if mondayBasedWeekday > 0 {
            guard let previousMonth = calendar.date(byAdding: .month, value: -1, to: month),
                  let previousMonthStart = calendar.dateInterval(of: .month, for: previousMonth)?.start,
                  let previousMonthRange = calendar.range(of: .day, in: .month, for: previousMonth) else {
                print("❌ CalendarDataManager: 无法获取上个月信息")
                days = []
                return
            }
            
            let previousMonthDays = previousMonthRange.count
            
            // 修复：直接从上个月的最后几天开始添加
            for i in 0..<mondayBasedWeekday {
                let dayOffset = previousMonthDays - mondayBasedWeekday + i
                if let date = calendar.date(byAdding: .day, value: dayOffset, to: previousMonthStart) {
                    newDays.append(date)
                }
            }
            print("📅 CalendarDataManager: 添加了 \(mondayBasedWeekday) 个上月日期")
        }
        
        // 添加当前月份的所有日期
        for i in 0..<daysInMonth {
            if let date = calendar.date(byAdding: .day, value: i, to: monthStart) {
                newDays.append(date)
            }
        }
        print("📅 CalendarDataManager: 添加了 \(daysInMonth) 个当月日期")
        
        // 添加下个月的开头日期（填充后面的空白，确保总共42天）
        let remainingDays = 42 - newDays.count
        if remainingDays > 0 {
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: month),
                  let nextMonthStart = calendar.dateInterval(of: .month, for: nextMonth)?.start else {
                print("❌ CalendarDataManager: 无法获取下个月信息，使用现有数据")
                // 确保数组长度为42，避免UI异常
                while newDays.count < 42 {
                    newDays.append(monthStart)
                }
                days = newDays
                return
            }
            
            for i in 0..<remainingDays {
                if let date = calendar.date(byAdding: .day, value: i, to: nextMonthStart) {
                    newDays.append(date)
                }
            }
            print("📅 CalendarDataManager: 添加了 \(remainingDays) 个下月日期")
        }
        
        // 确保始终有42天，添加更严格的验证
        if newDays.count == 42 {
            print("✅ CalendarDataManager: 成功生成42天数据")
            days = newDays
        } else {
            print("❌ CalendarDataManager: 数据生成错误，实际天数: \(newDays.count)，使用安全默认值")
            // 如果计算出错，创建一个安全的默认数组，避免崩溃
            var safeDays: [Date] = []
            safeDays.reserveCapacity(42)
            
            // 使用当前月份的第一天作为基准
            for i in 0..<42 {
                if let date = calendar.date(byAdding: .day, value: i, to: monthStart) {
                    safeDays.append(date)
                } else {
                    safeDays.append(monthStart) // 最后的安全保障
                }
            }
            days = safeDays
        }
        
        print("📅 CalendarDataManager: 数据生成完成，总计 \(days.count) 天")
    }
}

struct MonthView: View {
    @EnvironmentObject var colorSchemeManager: ColorSchemeManager
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var scheduleStore: ScheduleStore
    @ObservedObject var weatherManager = WeatherManager.shared
    @StateObject private var calendarManager = CalendarDataManager()
    
    @State private var currentMonth: Date = .now
    @State private var selectedDate: Date?
    @State private var showingDeleteAlert = false
    @State private var scheduleToDelete: ScheduleItem?
    @State private var schedulesToDelete: [ScheduleItem]?
    @State private var deleteType: DeleteType = .single
    @State private var showingDateDetail = false
    @State private var dateForDetail: Date = .now
    @State private var showingMonthPicker = false
    @State private var editingItem: ScheduleItem?
    
    enum DeleteType {
        case single
        case allRepeating
    }

    // 月份标题格式器
    private let monthFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy年M月"
        df.locale = Locale(identifier: "zh_CN")
        return df
    }()
    
    // 月份标题视图
    @ViewBuilder
    private var monthTitleView: some View {
        let lunarInfo = ChineseLunarCalendar.shared.getLunarInfo(for: currentMonth)
        let festival = ChineseFestivalManager.shared.getPrimaryFestival(for: currentMonth)
        
        HStack(spacing: 4) {
            // 公历月份
            Text(monthFormatter.string(from: currentMonth))
                .font(.system(.title2, design: .default, weight: .semibold))
                .foregroundColor(colorSchemeManager.primary)
            
            // 农历信息
            Text("(\(lunarInfo.month)月)")
                .font(.system(.caption2, design: .default, weight: .medium))
                .foregroundColor(colorSchemeManager.secondary)
            
            // 忆年信息（如果有）
            if let festival = festival {
                Text(festival.name)
                    .font(.system(.caption2, design: .default, weight: .medium))
                    .foregroundColor(festivalTextColor(for: festival.type, festivalName: festival.name))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(festivalTextColor(for: festival.type, festivalName: festival.name).opacity(0.1))
                    )
            }
            
            // 天气信息
            WeatherDisplayView(date: currentMonth, weatherManager: weatherManager, isCompact: true)
        }
        .minimumScaleFactor(0.5)
        .lineLimit(1)
        .allowsTightening(true)
        .truncationMode(.tail)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
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
                return colorSchemeManager.blue
            }
        case .solarTerm:
            return colorSchemeManager.solarTermColor
        }
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 6) {  // 减少整体间距从12到6
                weekdayHeader
                grid
                    .padding(.horizontal, 4)  // 减少水平边距从8到4
                Spacer(minLength: 0)  // 设置最小长度为0，减少底部留白
            }
            .padding(.top, 8)  // 减少顶部边距从16到8
            .safeAreaInset(edge: .bottom) {
                // 为底部导航栏预留空间
                Color.clear.frame(height: 100)
            }
        }
        .navigationTitle("")
    #if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
    #endif
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button {
                    showingMonthPicker = true
                } label: {
                    Text(monthFormatter.string(from: currentMonth))
                        .font(.system(.title2, design: .default, weight: .semibold))
                        .foregroundColor(colorSchemeManager.primary)
                }
            }
        }
        // 使导航栏背景在滚动过渡时保持一致，避免工具栏项重复渲染
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(colorSchemeManager.background, for: .navigationBar)
        .alert("删除日程", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    if let schedules = schedulesToDelete {
                        // 删除多个日程
                        scheduleStore.deleteSchedules(with: schedules.map { $0.id })
                    } else if let schedule = scheduleToDelete {
                        // 删除单个日程
                        switch deleteType {
                        case .single:
                            if schedule.isRecurring {
                                scheduleStore.deleteSingleSchedule(with: schedule.id)
                            } else {
                                scheduleStore.deleteSchedules(with: [schedule.id])
                            }
                        case .allRepeating:
                            scheduleStore.deleteAllRepeatingSchedules(with: schedule.id)
                        }
                    }
                }
                // 清理状态
                scheduleToDelete = nil
                schedulesToDelete = nil
            }
        } message: {
            if let schedules = schedulesToDelete {
                Text("确定要删除这\(schedules.count)个日程吗？")
            } else if let schedule = scheduleToDelete {
                switch deleteType {
                 case .single:
                     Text("确定要删除\"\(schedule.title)\"\(schedule.isRecurring ? "（仅此日）" : "")吗？")
                 case .allRepeating:
                     Text("确定要删除\"\(schedule.title)\"的所有重复日程吗？")
                 }
            } else {
                Text("确定要删除这个日程吗？")
            }
        }
        .sheet(isPresented: $showingDateDetail) {
            DateDetailView(scheduleStore: scheduleStore, selectedDate: dateForDetail)
        }
        .sheet(isPresented: $showingMonthPicker) {
            MonthYearPickerView(selectedDate: $currentMonth)
        }
        .fullScreenCover(item: $editingItem) { editingItem in
            EditScheduleView(scheduleItem: editingItem, scheduleStore: scheduleStore)
        }

        .onAppear {
            calendarManager.updateMonth(currentMonth)
            colorSchemeManager.updateColors(for: colorScheme)
        }
        .onChange(of: currentMonth) { oldValue, newValue in
            calendarManager.updateMonth(newValue)
        }
        .onChange(of: colorScheme) { _, newScheme in
            colorSchemeManager.updateColors(for: newScheme)
        }
        .id(colorScheme)
    }
    

    
    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { weekday in
                Text(weekday)
                    .font(.system(size: 18, weight: .semibold))  // 增加字体大小从17到18
                    .foregroundColor(colorSchemeManager.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)  // 减少垂直边距从12到8
        .padding(.horizontal, 4)  // 减少水平边距从8到4
    }
    
    private var grid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 7), spacing: 1) {  // 减少间距从2到1
            ForEach(calendarManager.days.indices, id: \.self) { index in
                let day = calendarManager.days[index]
                let daySchedules = scheduleStore.schedulesForDate(day)
                let isSelected = selectedDate != nil && Calendar.current.isDate(day, inSameDayAs: selectedDate!)
                
                DayCellView(
                    day: day,
                    rate: 0.0, // TODO: Fix completion rate
                    daySchedules: daySchedules,
                    isSelected: isSelected,
                    weatherManager: weatherManager,
                    onTap: { 
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedDate = day
                            dateForDetail = day
                            showingDateDetail = true
                        }
                    },
                    onLongPress: {
                        if !daySchedules.isEmpty {
                            if daySchedules.count == 1 {
                                scheduleToDelete = daySchedules.first
                                showingDeleteAlert = true
                            } else {
                                selectedDate = day
                            }
                        }
                    }
                )
                .contextMenu {
                    // 上下文菜单
                    if !daySchedules.isEmpty {
                        ForEach(daySchedules, id: \.id) { schedule in
                            Button {
                                editingItem = schedule
                            } label: {
                                Label("编辑日程", systemImage: "pencil")
                            }

                            Button {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    scheduleStore.toggleCompletion(for: schedule.id)
                                }
                            } label: {
                                Label(schedule.isCompleted ? "标记为未完成" : "标记为完成", systemImage: schedule.isCompleted ? "arrow.uturn.backward" : "checkmark.circle")
                            }
                            if schedule.isRecurring {
                                Button {
                                    deleteType = .single
                                    scheduleToDelete = schedule
                                    showingDeleteAlert = true
                                } label: {
                                    Label("删除 \(schedule.title)（仅此日）", systemImage: "trash")
                                }
                                
                                Button(role: .destructive) {
                                    deleteType = .allRepeating
                                    scheduleToDelete = schedule
                                    showingDeleteAlert = true
                                } label: {
                                    Label("删除 \(schedule.title)（所有重复）", systemImage: "trash.fill")
                                }
                            } else if schedule.isFestival && schedule.isYearlyRecurring {
                                // 忆年日程的特殊处理
                                Button {
                                    deleteType = .single
                                    scheduleToDelete = schedule
                                    showingDeleteAlert = true
                                } label: {
                                    Label("删除 \(schedule.title)（仅此日）", systemImage: "trash")
                                }
                                
                                Button(role: .destructive) {
                                    deleteType = .allRepeating
                                    scheduleToDelete = schedule
                                    showingDeleteAlert = true
                                } label: {
                                    Label("删除 \(schedule.title)（所有周年）", systemImage: "trash.fill")
                                }
                            } else {
                                Button(role: .destructive) {
                                    deleteType = .single
                                    scheduleToDelete = schedule
                                    showingDeleteAlert = true
                                } label: {
                                    Label("删除 \(schedule.title)", systemImage: "trash")
                                }
                            }
                        }
                        
                        if daySchedules.count > 1 {
                            Divider()
                            Button(role: .destructive) {
                                deleteType = .single
                                scheduleToDelete = nil
                                schedulesToDelete = daySchedules
                                showingDeleteAlert = true
                            } label: {
                                Label("删除当日全部日程", systemImage: "trash.fill")
                            }
                        }
                    }
                }
                .id("day-\(index)-\(day.timeIntervalSince1970)")
            }
        }
        .id("calendar-\(currentMonth.timeIntervalSince1970)")
        .disabled(calendarManager.isUpdating)
        .opacity(calendarManager.isUpdating ? 0.6 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0.1), value: calendarManager.isUpdating)
        .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.2), value: currentMonth)
    }

    private func shiftMonth(_ delta: Int) {
        guard !calendarManager.isUpdating else { 
            print("📅 MonthView: 正在更新中，跳过月份切换")
            return 
        }
        
        guard let newMonth = Calendar.current.date(byAdding: .month, value: delta, to: currentMonth) else {
            print("❌ MonthView: 无法计算新月份")
            return
        }
        
        print("📅 MonthView: 切换月份 \(delta > 0 ? "下一月" : "上一月")")
        withAnimation(.easeInOut(duration: 0.3)) {
            currentMonth = newMonth
        }
    }
}
