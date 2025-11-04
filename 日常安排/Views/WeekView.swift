import SwiftUI
import Foundation

struct WeekView: View {
    @ObservedObject var scheduleStore: ScheduleStore
    @EnvironmentObject var colorSchemeManager: ColorSchemeManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedWeekStart: Date = Date().startOfWeek
    @State private var showAdd: Bool = false
    @State private var showCalendar: Bool = false
    @State private var selectedDateForAdd: Date = Date()
    @State private var editingItem: ScheduleItem?
    @StateObject private var weatherManager = WeatherManager.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 周导航栏
                weekNavigationBar
                
                // 周日程列表
                weekScheduleList
            }
            .navigationTitle("")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        weekTitleView
                    }
                }
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 8) {
                        // 添加按钮 - 动感多彩小圆圈
                        AnimatedPlusButton {
                            selectedDateForAdd = Date()
                            showAdd = true
                        }
                    }
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 8) {
                        // 添加按钮 - 动感多彩小圆圈
                        AnimatedPlusButton {
                            selectedDateForAdd = Date()
                            showAdd = true
                        }
                    }
                }
                #endif
            }
        }
        .sheet(isPresented: $showAdd) {
            AddScheduleView(scheduleStore: scheduleStore, baseDate: selectedDateForAdd)
        }
        .fullScreenCover(item: $editingItem) { editingItem in
            EditScheduleView(scheduleItem: editingItem, scheduleStore: scheduleStore)
        }
        .sheet(isPresented: $showCalendar) {
            NavigationView {
                CustomCalendarView(selectedDate: .constant(selectedWeekStart))
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
                        ToolbarItem(placement: .automatic) {
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
            colorSchemeManager.updateColors(for: colorScheme)
        }
        .onChange(of: colorScheme) { newScheme in
            colorSchemeManager.updateColors(for: newScheme)
        }
        .id(colorScheme)
    }

    // MARK: - 周导航栏
    @ViewBuilder
    private var weekNavigationBar: some View {
        HStack(spacing: 16) {
            ForEach(weekDays, id: \.self) { date in
                weekDayCell(for: date)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        #if os(iOS)
        .background(colorSchemeManager.background)
        #else
        .background(colorSchemeManager.background)
        #endif
        .shadow(color: colorSchemeManager.secondary.opacity(0.1), radius: 1, x: 0, y: 1)
        .id("week-\(selectedWeekStart.timeIntervalSince1970)")
        .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.2), value: selectedWeekStart)
    }

    @ViewBuilder
    private func weekDayCell(for date: Date) -> some View {
        let isToday = Calendar.current.isDateInToday(date)
        
        VStack(spacing: 4) {
            Text(weekdayFormatter.string(from: date))
                .font(.caption)
                .foregroundColor(colorSchemeManager.secondary)
            
            Text(dayFormatter.string(from: date))
                .font(.system(.title3, design: .default, weight: isToday ? .bold : .medium))
                .foregroundColor(isToday ? .white : colorSchemeManager.primary)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(isToday ? colorSchemeManager.accent : Color.clear)
                )
        }
        .frame(minWidth: 44)
        .onTapGesture {
            selectedDateForAdd = date
            showAdd = true
        }
    }
    
    // MARK: - 格式化器
    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }
    
    private var weekdayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }
    
    // MARK: - 周标题视图
    @ViewBuilder
    private var weekTitleView: some View {
        let weekEndDate = Calendar.current.date(byAdding: .day, value: 6, to: selectedWeekStart) ?? selectedWeekStart
        
        Text("\(weekTitleFormatter.string(from: selectedWeekStart)) - \(weekTitleFormatter.string(from: weekEndDate))")
            .font(.system(.title2, design: .default, weight: .semibold))
            .foregroundColor(colorSchemeManager.primary)
    }
    
    private var weekTitleFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }
    
    // MARK: - 周日程列表
    @ViewBuilder
    private var weekScheduleList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(weekDays, id: \.self) { date in
                    weekDaySection(for: date)
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 8)
        }
        .safeAreaInset(edge: .bottom) {
            // 导航栏高度：12(vertical padding) + 32(button height) + 16(bottom padding) + 安全区域 ≈ 80-100
            Color.clear.frame(height: 100)
        }
    }
    
    @ViewBuilder
    private func weekDaySection(for date: Date) -> some View {
        let items = scheduleStore.schedulesForDate(date)
        let isToday = Calendar.current.isDateInToday(date)
        
        VStack(alignment: .leading, spacing: 8) {
            // 日期标题
            HStack {
                Text(dayHeaderTitle(for: date))
                    .font(.system(.headline, design: .default, weight: .semibold))
                    .foregroundColor(isToday ? colorSchemeManager.accent : colorSchemeManager.primary)
                
                if isToday {
                    Text("今天")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(colorSchemeManager.accent.opacity(0.1))
                        .foregroundColor(colorSchemeManager.accent)
                        .cornerRadius(4)
                }
                
                // 天气显示
                WeatherDisplayView(date: date, weatherManager: weatherManager, isCompact: true)
                
                Spacer()
                
                Text("\(items.count)个日程")
                    .font(.caption)
                    .foregroundColor(colorSchemeManager.secondary)
            }
            
            // 日程卡片
            if items.isEmpty {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(colorSchemeManager.secondary.opacity(0.6))
                    Text("暂无日程")
                        .font(.callout)
                        .foregroundColor(colorSchemeManager.secondary.opacity(0.8))
                    Spacer()
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                #if os(iOS)
                .background(colorSchemeManager.secondaryBackground)
                #else
                .background(colorSchemeManager.secondaryBackground)
                #endif
                .cornerRadius(8)
            } else {
                ForEach(items, id: \.id) { item in
                    ScheduleCardView(item: item, scheduleStore: scheduleStore, onEdit: {
                        editingItem = item
                    })
                            .contextMenu {
                                Button {
                                    editingItem = item
                                } label: {
                                    Label("编辑日程", systemImage: "pencil")
                                }
                                if item.isRecurring {
                                    Divider()
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
                                Divider()
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
            }
        }
    }
    
    // MARK: - 计算属性和辅助方法
    private var weekDays: [Date] {
        var days: [Date] = []
        let calendar = Calendar.current
        
        for i in 0..<7 {
            if let day = calendar.date(byAdding: .day, value: i, to: selectedWeekStart) {
                days.append(day)
            }
        }
        
        return days
    }
    
    private func dayHeaderTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 EEEE"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

// MARK: - Date Extension
extension Date {
    var startOfWeek: Date {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // 设置周一为一周的开始 (1=周日, 2=周一)
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components) ?? self
    }
}