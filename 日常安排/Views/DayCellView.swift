import SwiftUI
import Foundation

struct DayCellView: View {
    let day: Date
    let rate: Double
    let daySchedules: [ScheduleItem]
    let isSelected: Bool
    let weatherManager: WeatherManager
    let onTap: () -> Void
    let onLongPress: () -> Void
    
    @EnvironmentObject var colorSchemeManager: ColorSchemeManager
    @State private var dayWeather: WeatherInfo?
    @State private var isLoadingWeather = false
    @State private var weatherTask: Task<Void, Never>?
    
    private let calendar = Calendar.current
    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                // 日期数字 - 主要信息，进一步加大加粗
                Text(dayFormatter.string(from: day))
                    .font(.system(size: 24, weight: .bold))  // 进一步加大字体并统一加粗
                    .foregroundColor(textColor)
                
                // 农历和忆年信息 - 次要信息
                VStack(spacing: 1) {
                    let lunarInfo = ChineseLunarCalendar.shared.getLunarInfo(for: day)
                    let festival = ChineseFestivalManager.shared.getPrimaryFestival(for: day)
                    
                    if let festival = festival {
                        Text(festival.name)
                            .font(.system(size: 10, weight: .medium))  // 调大字号从8到10
                            .foregroundColor(festivalColor(for: festival.type, festivalName: festival.name))
                            .lineLimit(1)
                    } else {
                        Text(lunarInfo.shortDisplay)
                            .font(.system(size: 10, weight: .regular))  // 调大字号从8到10
                            .foregroundColor(colorSchemeManager.secondary.opacity(0.7))  // 使用更浅的灰色
                            .lineLimit(1)
                    }
                }
                
                // 天气信息 - 次要信息，调大字号
                if let weather = dayWeather {
                    HStack(spacing: 1) {
                        Image(systemName: weather.icon)
                            .font(.system(size: 10))  // 调大图标从8到10
                            .foregroundColor(colorSchemeManager.secondary.opacity(0.7))  // 使用浅灰色
                        Text("\(weather.temperature)°")
                            .font(.system(size: 10, weight: .regular))  // 调大字号从8到10
                            .foregroundColor(colorSchemeManager.secondary.opacity(0.7))  // 使用浅灰色
                    }
                } else if isLoadingWeather {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(height: 10)
                }
                
                // 日程指示器
                if !daySchedules.isEmpty {
                    HStack(spacing: 4) {  // 增加间距从2到4
                        ForEach(0..<min(daySchedules.count, 3), id: \.self) { index in
                            Circle()
                                .fill(daySchedules[index].category.color)
                                .frame(width: 4, height: 4)  // 缩小圆点从5到4
                        }
                        if daySchedules.count > 3 {
                            Text("...")
                                .font(.system(size: 6, weight: .medium))  // 缩小字体从8到6
                                .foregroundColor(colorSchemeManager.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)  // 确保水平居中
                }
            }
            .frame(width: 56, height: 80)  // 增加宽度和高度，提供更多留白空间
            .padding(.vertical, 4)  // 增加垂直内边距
            .padding(.horizontal, 2)  // 增加水平内边距
            .background(backgroundColor)
            .cornerRadius(10)  // 稍微增加圆角
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(borderColor, lineWidth: isSelected ? 2 : 0)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture {
            onLongPress()
        }
        .onAppear {
            fetchWeatherForDay()
        }
        .onChange(of: day) { oldValue, newValue in
            fetchWeatherForDay()
        }
        .onDisappear {
            // 取消天气获取任务，避免内存泄漏
            weatherTask?.cancel()
        }
    }
    
    private var isToday: Bool {
        calendar.isDateInToday(day)
    }
    
    private var isCurrentMonth: Bool {
        calendar.isDate(day, equalTo: Date(), toGranularity: .month)
    }
    
    private var textColor: Color {
        if !isCurrentMonth {
            return colorSchemeManager.secondary.opacity(0.5)
        } else if isSelected {
            return colorSchemeManager.accentForegroundColor
        } else if isToday {
            return colorSchemeManager.primary
        } else {
            return colorSchemeManager.primary
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return colorSchemeManager.accent
        } else if isToday {
            return colorSchemeManager.accent.opacity(0.1)
        } else {
            return .clear
        }
    }
    
    private var borderColor: Color {
        if isSelected {
            return colorSchemeManager.accent
        } else {
            return .clear
        }
    }
    
    private func festivalColor(for type: ChineseFestivalType, festivalName: String = "") -> Color {
        switch type {
        case .lunar:
            return colorSchemeManager.lunarFestivalColor.opacity(0.8)  // 传统节假日使用温暖的橙色
        case .solar:
            // 区分法定假日和普通公历忆年
            let legalHolidays = ["元旦", "劳动节", "国庆节"]
            if legalHolidays.contains(festivalName) {
                return colorSchemeManager.legalHolidayColor.opacity(0.9)  // 法定假日使用醒目的红色
            } else {
                return colorSchemeManager.accent.opacity(0.8)  // 其他公历忆年使用品牌色（蓝色）
            }
        case .solarTerm:
            return colorSchemeManager.solarTermColor  // 节气使用浅绿色，弱化颜色强调信息性
        }
    }
    
    // 获取当天天气信息
    private func fetchWeatherForDay() {
        // 只为当前月份的日期获取天气
        guard isCurrentMonth else { 
            // 清理非当前月份的天气数据
            dayWeather = nil
            isLoadingWeather = false
            weatherTask?.cancel()
            return 
        }
        
        // 避免重复加载相同日期的天气
        if let currentWeather = dayWeather,
           calendar.isDate(currentWeather.dateTime, inSameDayAs: day) {
            return
        }
        
        // 取消之前的任务
        weatherTask?.cancel()
        
        isLoadingWeather = true
        
        weatherTask = Task { @MainActor in
            guard !Task.isCancelled else { return }
            
            // 使用中午12点作为该日期的代表时间
            let noonTime = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
            
            // 检查当天是否有带城市信息的日程，优先使用第一个有城市信息的日程的城市
            let cityToUse = daySchedules.first { !($0.city?.isEmpty ?? true) }?.city
            
            let weather: WeatherInfo?
            if let city = cityToUse, !city.isEmpty {
                weather = await weatherManager.fetchWeatherForCity(city, dateTime: noonTime)
            } else {
                weather = await weatherManager.fetchWeatherForTime(noonTime)
            }
            
            // 检查任务是否被取消
            guard !Task.isCancelled else { return }
            
            dayWeather = weather
            isLoadingWeather = false
        }
    }
}

#Preview {
    DayCellView(
        day: Date(),
        rate: 0.5,
        daySchedules: [],
        isSelected: false,
        weatherManager: WeatherManager.shared,
        onTap: {},
        onLongPress: {}
    )
    .padding()
}