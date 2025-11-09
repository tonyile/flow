import SwiftUI
import Foundation

struct CustomDatePickerView: View {
    @Binding var selectedDate: Date
    var showLunarDate: Bool = false
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        return formatter
    }()
    
    private var displayDateString: String {
        if showLunarDate {
            let lunarInfo = ChineseLunarCalendar.shared.getLunarInfo(for: selectedDate)
            let calendar = Calendar.current
            let year = calendar.component(.year, from: selectedDate)
            return "\(year)年\(lunarInfo.month)\(lunarInfo.day)"
        } else {
            return dateFormatter.string(from: selectedDate)
        }
    }
    
    var body: some View {
        DatePicker(
            "",
            selection: $selectedDate,
            displayedComponents: [.date]
        )
        .datePickerStyle(.compact)
        .labelsHidden()
        .environment(\.locale, Locale(identifier: "zh_CN"))
    }
}

struct CustomDateCell: View {
    let date: Date
    let isSelected: Bool
    let isCurrentMonth: Bool
    let onTap: () -> Void
    
    private let calendar = Calendar.current
    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()
    
    private var isToday: Bool {
        calendar.isDateInToday(date)
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                // 公历日期
                Text(dayFormatter.string(from: date))
                    .font(.system(size: 16, weight: isSelected ? .bold : .medium))
                    .foregroundColor(textColor)
                
                // 农历和忆年信息
                VStack(spacing: 1) {
                    let lunarInfo = ChineseLunarCalendar.shared.getLunarInfo(for: date)
                    let festival = ChineseFestivalManager.shared.getPrimaryFestival(for: date)
                    
                    if let festival = festival {
                        Text(festival.name)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(festivalColor(for: festival.type, festivalName: festival.name))
                            .lineLimit(1)
                    } else {
                        Text(lunarInfo.day)
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(width: 40, height: 60)
            .background(backgroundColor)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(isCurrentMonth ? 1.0 : 0.3)
    }
    
    private var textColor: Color {
        if isSelected {
            return .white
        } else if isToday {
            return .blue
        } else if isCurrentMonth {
            return .primary
        } else {
            return .secondary
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return .blue
        } else if isToday {
            return .blue.opacity(0.1)
        } else {
            return .clear
        }
    }
    
    private func festivalColor(for type: ChineseFestivalType, festivalName: String = "") -> Color {
        switch type {
        case .lunar:
            return .red
        case .solar:
            if festivalName.contains("节") || festivalName.contains("日") {
                return .orange
            } else {
                return .blue
            }
        case .solarTerm:
            return .green
        }
    }
}

struct DatePickerMonthYearView: View {
    @Binding var selectedDate: Date
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedYear: Int
    @State private var selectedMonth: Int
    
    private let calendar = Calendar.current
    private let currentYear = Calendar.current.component(.year, from: Date())
    private let years: [Int]
    private let months = Array(1...12)
    
    init(selectedDate: Binding<Date>) {
        self._selectedDate = selectedDate
        let date = selectedDate.wrappedValue
        self._selectedYear = State(initialValue: Calendar.current.component(.year, from: date))
        self._selectedMonth = State(initialValue: Calendar.current.component(.month, from: date))
        
        // 提供前后10年的选择范围
        let currentYear = Calendar.current.component(.year, from: Date())
        self.years = Array((currentYear - 10)...(currentYear + 10))
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    // 年份选择器
                    Picker("年份", selection: $selectedYear) {
                        ForEach(years, id: \.self) { year in
                            Text("\(year)").tag(year)
                        }
                    }
                    #if os(iOS)
                    .pickerStyle(.wheel)
                    #else
                    .pickerStyle(.menu)
                    #endif
                    .frame(maxWidth: .infinity)
                    
                    // 月份选择器
                    Picker("月份", selection: $selectedMonth) {
                        ForEach(months, id: \.self) { month in
                            Text("\(month)").tag(month)
                        }
                    }
                    #if os(iOS)
                    .pickerStyle(.wheel)
                    #else
                    .pickerStyle(.menu)
                    #endif
                    .frame(maxWidth: .infinity)
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("选择日期")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
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
                }
                #else
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
                }
                #endif
            }
        }
    }
}

#Preview {
    CustomDatePickerView(selectedDate: .constant(Date()))
        .padding()
}