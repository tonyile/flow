import SwiftUI
import Foundation

struct CustomCalendarView: View {
    @Binding var selectedDate: Date
    @State private var currentMonth: Date = Date()
    @State private var showingMonthPicker = false
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月"
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 16) {
            // 月份标题栏
            HStack {
                Button(action: { showingMonthPicker = true }) {
                    Text(dateFormatter.string(from: currentMonth))
                        .font(.title)  // 放大月份标题
                        .fontWeight(.semibold)  // 统一使用semibold
                        .foregroundColor(.primary)  // 主要颜色突出显示
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal)
            
            // 星期标题行
            HStack {
                ForEach(Array(["周一", "周二", "周三", "周四", "周五", "周六", "周日"].enumerated()), id: \.offset) { index, day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(weekdayColor(for: index))  // 根据星期设置不同颜色
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)  // 增加与日历主体的间距
            
            // 日历网格 - 添加滑动手势
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(Array(daysInMonth.enumerated()), id: \.offset) { index, date in
                    if let date = date {
                        CalendarDayCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isCurrentMonth: calendar.isDate(date, equalTo: currentMonth, toGranularity: .month),
                            isToday: calendar.isDateInToday(date)
                        ) {
                            selectedDate = date
                        }
                        .id("\(Calendar.current.dateComponents([.year, .month, .day], from: date).year!)-\(Calendar.current.dateComponents([.year, .month, .day], from: date).month!)-\(Calendar.current.dateComponents([.year, .month, .day], from: date).day!)")
                    } else {
                        Color.clear
                            .frame(height: 60)
                            .id("empty-\(index)")
                    }
                }
            }
            .padding(.horizontal)
            .id(currentMonth.timeIntervalSince1970) // 添加月份标识符确保月份切换时正确更新
            .gesture(
                DragGesture()
                    .onEnded { value in
                        let threshold: CGFloat = 50
                        if value.translation.width > threshold {
                            // 向右滑动，显示上个月
                            withAnimation(.easeInOut(duration: 0.3)) {
                                previousMonth()
                            }
                        } else if value.translation.width < -threshold {
                            // 向左滑动，显示下个月
                            withAnimation(.easeInOut(duration: 0.3)) {
                                nextMonth()
                            }
                        }
                    }
            )
        }
        .padding(.vertical)
        #if os(iOS)
        .background(Color(.systemBackground))
        #else
        .background(Color(NSColor.controlBackgroundColor))
        #endif
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        .sheet(isPresented: $showingMonthPicker) {
            MonthYearPickerView(selectedDate: $currentMonth)
        }
    }
    
    private var daysInMonth: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth) else {
            return []
        }
        
        let firstOfMonth = monthInterval.start
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let numberOfDaysInMonth = calendar.range(of: .day, in: .month, for: currentMonth)?.count ?? 0
        
        var days: [Date?] = []
        
        // 转换为周一开始的索引 (1=周日, 2=周一...7=周六 -> 0=周一, 1=周二...6=周日)
        let mondayBasedWeekday = (firstWeekday + 5) % 7
        
        // 添加前面的空白天数
        for _ in 0..<mondayBasedWeekday {
            days.append(nil)
        }
        
        // 添加当月的天数
        for day in 1...numberOfDaysInMonth {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(date)
            }
        }
        
        return days
    }
    
    private func previousMonth() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
        }
    }
    
    private func nextMonth() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
        }
    }
    
    // 星期标题颜色配置
    private func weekdayColor(for index: Int) -> Color {
        switch index {
        case 5: return .accentColor // 周六使用品牌色（蓝色）
        case 6: return .red        // 周日使用红色
        default: return .secondary  // 其他工作日使用次要颜色
        }
    }
}

struct CalendarDayCell: View {
    let date: Date
    let isSelected: Bool
    let isCurrentMonth: Bool
    let isToday: Bool
    let onTap: () -> Void
    
    @StateObject private var scheduleStore = ScheduleStore.shared
    
    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()
    
    private var daySchedules: [ScheduleItem] {
        scheduleStore.schedulesForDate(date)
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                // 日期数字
                Text(dayFormatter.string(from: date))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(textColor)
                    .padding(.top, 6)
                
                Spacer(minLength: 4)
                
                // 农历和忆年信息
                VStack(alignment: .center, spacing: 2) {
                    let lunarInfo = ChineseLunarCalendar.shared.getLunarInfo(for: date)
                    let festival = ChineseFestivalManager.shared.getPrimaryFestival(for: date)
                    
                    if let festival = festival {
                        Text(festival.name)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(festivalColor(for: festival.type, festivalName: festival.name))
                            .lineLimit(1)
                    } else {
                        Text(lunarInfo.shortDisplay)
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(.secondary.opacity(0.8))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 2)
                
                // 日程指示器
                if !daySchedules.isEmpty {
                    HStack(spacing: 3) {
                        ForEach(0..<min(daySchedules.count, 3), id: \.self) { index in
                            Circle()
                                .fill(daySchedules[index].category.color)
                                .frame(width: 5, height: 5)
                        }
                        if daySchedules.count > 3 {
                            Text("...")
                                .font(.system(size: 7, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 4)
                } else {
                    Spacer(minLength: 4)
                }
                
                Spacer(minLength: 2)
            }
            .frame(width: 50, height: 70)
            .background(backgroundColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: isSelected ? 2 : (isToday ? 1.5 : 0))
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var textColor: Color {
        if !isCurrentMonth {
            return .secondary.opacity(0.5)
        } else if isSelected {
            return .white
        } else if isToday {
            return .primary
        } else {
            return .primary
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return .accentColor
        } else if isToday {
            return .accentColor.opacity(0.15)
        } else {
            return .clear
        }
    }
    
    private var borderColor: Color {
        if isSelected {
            return .accentColor
        } else if isToday {
            return .accentColor.opacity(0.6)
        } else {
            return .clear
        }
    }
    
    private func festivalColor(for type: ChineseFestivalType, festivalName: String = "") -> Color {
        switch type {
        case .lunar:
            return .orange.opacity(0.8)  // 传统节假日使用温暖的橙色
        case .solar:
            // 区分法定假日和普通公历忆年
            let legalHolidays = ["元旦", "劳动节", "国庆节"]
            if legalHolidays.contains(festivalName) {
                return .red.opacity(0.9)  // 法定假日使用醒目的红色
            } else {
                return .accentColor.opacity(0.8)  // 其他公历忆年使用品牌色（蓝色）
            }
        case .solarTerm:
            return .green.opacity(0.6)  // 节气使用浅绿色，弱化颜色强调信息性
        }
    }
}

// 月份年份选择器视图
struct MonthYearPickerView: View {
    @Binding var selectedDate: Date
    @Environment(\.dismiss) private var dismiss
    @State private var selectedYear: Int
    @State private var selectedMonth: Int
    
    private let calendar = Calendar.current
    private let years = Array(2020...2030)
    private let months = Array(1...12)
    
    init(selectedDate: Binding<Date>) {
        self._selectedDate = selectedDate
        let components = Calendar.current.dateComponents([.year, .month], from: selectedDate.wrappedValue)
        self._selectedYear = State(initialValue: components.year ?? Calendar.current.component(.year, from: Date()))
        self._selectedMonth = State(initialValue: components.month ?? Calendar.current.component(.month, from: Date()))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("选择年月")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                HStack(spacing: 40) {
                    // 年份选择器
                    VStack {
                        Text("年份")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Picker("年份", selection: $selectedYear) {
                            ForEach(years, id: \.self) { year in
                                Text("\(year)年")
                                    .tag(year)
                            }
                        }
                        #if os(iOS)
                        .pickerStyle(WheelPickerStyle())
                        #else
                        .pickerStyle(.menu)
                        #endif
                        .frame(width: 120, height: 150)
                    }
                    
                    // 月份选择器
                    VStack {
                        Text("月份")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Picker("月份", selection: $selectedMonth) {
                            ForEach(months, id: \.self) { month in
                                Text("\(month)月")
                                    .tag(month)
                            }
                        }
                        #if os(iOS)
                        .pickerStyle(WheelPickerStyle())
                        #else
                        .pickerStyle(.menu)
                        #endif
                        .frame(width: 100, height: 150)
                    }
                }
                
                Spacer()
            }
#if os(iOS)
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确定") {
                        if let newDate = calendar.date(from: DateComponents(year: selectedYear, month: selectedMonth, day: 1)) {
                            selectedDate = newDate
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
#else
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        if let newDate = calendar.date(from: DateComponents(year: selectedYear, month: selectedMonth, day: 1)) {
                            selectedDate = newDate
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
#endif
#else
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        if let newDate = calendar.date(from: DateComponents(year: selectedYear, month: selectedMonth, day: 1)) {
                            selectedDate = newDate
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
#endif
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    CustomCalendarView(selectedDate: .constant(Date()))
        .padding()
}