import Foundation

class ChineseLunarCalendar {
    static let shared = ChineseLunarCalendar()
    
    // 农历月份名称
    private let lunarMonths = ["正月", "二月", "三月", "四月", "五月", "六月",
                              "七月", "八月", "九月", "十月", "冬月", "腊月"]
    
    // 农历日期名称
    private let lunarDays = ["初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
                            "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
                            "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"]
    
    // 天干
    private let heavenlyStems = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"]
    
    // 地支
    private let earthlyBranches = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]
    
    // 生肖
    private let zodiacAnimals = ["鼠", "牛", "虎", "兔", "龙", "蛇", "马", "羊", "猴", "鸡", "狗", "猪"]
    
    // 农历数据表 (1900-2100年)
    private let lunarInfo: [UInt32] = [
        0x04bd8, 0x04ae0, 0x0a570, 0x054d5, 0x0d260, 0x0d950, 0x16554, 0x056a0, 0x09ad0, 0x055d2,
        0x04ae0, 0x0a5b6, 0x0a4d0, 0x0d250, 0x1d255, 0x0b540, 0x0d6a0, 0x0ada2, 0x095b0, 0x14977,
        0x04970, 0x0a4b0, 0x0b4b5, 0x06a50, 0x06d40, 0x1ab54, 0x02b60, 0x09570, 0x052f2, 0x04970,
        0x06566, 0x0d4a0, 0x0ea50, 0x06e95, 0x05ad0, 0x02b60, 0x186e3, 0x092e0, 0x1c8d7, 0x0c950,
        0x0d4a0, 0x1d8a6, 0x0b550, 0x056a0, 0x1a5b4, 0x025d0, 0x092d0, 0x0d2b2, 0x0a950, 0x0b557,
        0x06ca0, 0x0b550, 0x15355, 0x04da0, 0x0a5b0, 0x14573, 0x052b0, 0x0a9a8, 0x0e950, 0x06aa0,
        0x0aea6, 0x0ab50, 0x04b60, 0x0aae4, 0x0a570, 0x05260, 0x0f263, 0x0d950, 0x05b57, 0x056a0,
        0x096d0, 0x04dd5, 0x04ad0, 0x0a4d0, 0x0d4d4, 0x0d250, 0x0d558, 0x0b540, 0x0b6a0, 0x195a6,
        0x095b0, 0x049b0, 0x0a974, 0x0a4b0, 0x0b27a, 0x06a50, 0x06d40, 0x0af46, 0x0ab60, 0x09570,
        0x04af5, 0x04970, 0x064b0, 0x074a3, 0x0ea50, 0x06b58, 0x055c0, 0x0ab60, 0x096d5, 0x092e0,
        0x0c960, 0x0d954, 0x0d4a0, 0x0da50, 0x07552, 0x056a0, 0x0abb7, 0x025d0, 0x092d0, 0x0cab5,
        0x0a950, 0x0b4a0, 0x0baa4, 0x0ad50, 0x055d9, 0x04ba0, 0x0a5b0, 0x15176, 0x052b0, 0x0a930,
        0x07954, 0x06aa0, 0x0ad50, 0x05b52, 0x04b60, 0x0a6e6, 0x0a4e0, 0x0d260, 0x0ea65, 0x0d530,
        0x05aa0, 0x076a3, 0x096d0, 0x04afb, 0x04ad0, 0x0a4d0, 0x1d0b6, 0x0d250, 0x0d520, 0x0dd45,
        0x0b5a0, 0x056d0, 0x055b2, 0x049b0, 0x0a577, 0x0a4b0, 0x0aa50, 0x1b255, 0x06d20, 0x0ada0,
        0x14b63, 0x09370, 0x049f8, 0x04970, 0x064b0, 0x168a6, 0x0ea50, 0x06b20, 0x1a6c4, 0x0aae0,
        0x0a2e0, 0x0d2e3, 0x0c960, 0x0d557, 0x0d4a0, 0x0da50, 0x05d55, 0x056a0, 0x0a6d0, 0x055d4,
        0x052d0, 0x0a9b8, 0x0a950, 0x0b4a0, 0x0b6a6, 0x0ad50, 0x055a0, 0x0aba4, 0x0a5b0, 0x052b0,
        0x0b273, 0x06930, 0x07337, 0x06aa0, 0x0ad50, 0x14b55, 0x04b60, 0x0a570, 0x054e4, 0x0d160,
        0x0e968, 0x0d520, 0x0daa0, 0x16aa6, 0x056d0, 0x04ae0, 0x0a9d4, 0x0a2d0, 0x0d150, 0x0f252,
        0x0d520
    ]
    
    private init() {}
    
    // 获取农历信息
    func getLunarInfo(for date: Date) -> LunarInfo {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        
        guard let year = components.year,
              let month = components.month,
              let day = components.day else {
            return LunarInfo(year: "", month: "", day: "", zodiac: "", isLeapMonth: false)
        }
        
        // 计算农历日期
        let lunarDate = solarToLunar(year: year, month: month, day: day)
        
        // 生成农历年份（天干地支）
        let yearIndex = (lunarDate.year - 4) % 60
        let heavenlyIndex = max(0, min(yearIndex % 10, heavenlyStems.count - 1))
        let earthlyIndex = max(0, min(yearIndex % 12, earthlyBranches.count - 1))
        let zodiacIndex = max(0, min((lunarDate.year - 4) % 12, zodiacAnimals.count - 1))
        
        let heavenlyStem = heavenlyStems[heavenlyIndex]
        let earthlyBranch = earthlyBranches[earthlyIndex]
        let zodiac = zodiacAnimals[zodiacIndex]
        let lunarYearName = "\(heavenlyStem)\(earthlyBranch)年"
        
        // 生成农历月份名称
        let monthIndex = max(0, min(lunarDate.month - 1, lunarMonths.count - 1))
        let monthName = lunarMonths[monthIndex]
        
        // 生成农历日期名称
        let dayIndex = max(0, min(lunarDate.day - 1, lunarDays.count - 1))
        let dayName = lunarDays[dayIndex]
        
        return LunarInfo(
            year: lunarYearName,
            month: monthName,
            day: dayName,
            zodiac: zodiac,
            isLeapMonth: lunarDate.isLeapMonth
        )
    }
    
    // 农历转公历的核心算法
    func lunarToSolar(year: Int, month: Int, day: Int, isLeapMonth: Bool = false) -> Date? {
        // 验证输入参数
        guard year >= 1900 && year <= 2100,
              month >= 1 && month <= 12,
              day >= 1 && day <= 30 else {
            return nil
        }
        
        // 计算从农历1900年正月初一到目标日期的天数
        var totalDays = 0
        
        // 累加年份天数
        for y in 1900..<year {
            totalDays += getDaysInLunarYear(y)
        }
        
        // 累加月份天数
        let leapMonth = getLeapMonth(year)
        for m in 1..<month {
            totalDays += getDaysInLunarMonth(year, month: m)
            // 如果当前月份之前有闰月，需要加上闰月天数
            if leapMonth > 0 && m == leapMonth {
                totalDays += getDaysInLeapMonth(year)
            }
        }
        
        // 如果目标月份是闰月
        if isLeapMonth && leapMonth == month {
            totalDays += getDaysInLunarMonth(year, month: month)
        }
        
        // 加上日期天数
        totalDays += day - 1
        
        // 基准日期：1900年1月31日为农历1900年正月初一
        let calendar = Calendar.current
        let baseDate = calendar.date(from: DateComponents(year: 1900, month: 1, day: 31))!
        
        // 计算目标日期
        return calendar.date(byAdding: .day, value: totalDays, to: baseDate)
    }
    
    // 公历转农历的核心算法
    private func solarToLunar(year: Int, month: Int, day: Int) -> (year: Int, month: Int, day: Int, isLeapMonth: Bool) {
        // 基准日期：1900年1月31日为农历1900年正月初一
        let baseYear = 1900
        let baseMonth = 1
        let baseDay = 31
        
        // 计算距离基准日期的天数
        var totalDays = 0
        
        // 计算年份差异的天数
        for y in baseYear..<year {
            totalDays += isLeapYear(y) ? 366 : 365
        }
        
        // 计算月份差异的天数
        for m in baseMonth..<month {
            totalDays += daysInMonth(year: year, month: m)
        }
        
        // 加上日期差异
        totalDays += day - baseDay
        
        // 从农历1900年开始计算
        var lunarYear = 1900
        var lunarMonth = 1
        var lunarDay = 1
        var isLeapMonth = false
        
        // 逐年减去农历年的天数
        while totalDays > 0 {
            let daysInLunarYear = getDaysInLunarYear(lunarYear)
            if totalDays >= daysInLunarYear {
                totalDays -= daysInLunarYear
                lunarYear += 1
            } else {
                break
            }
        }
        
        // 逐月减去农历月的天数
        let leapMonth = getLeapMonth(lunarYear)
        var monthCount = 1
        
        while totalDays > 0 {
            var daysInCurrentMonth: Int
            
            if leapMonth > 0 && monthCount == leapMonth + 1 && !isLeapMonth {
                // 闰月
                isLeapMonth = true
                daysInCurrentMonth = getDaysInLeapMonth(lunarYear)
            } else {
                if isLeapMonth {
                    isLeapMonth = false
                    monthCount += 1
                }
                daysInCurrentMonth = getDaysInLunarMonth(lunarYear, month: monthCount)
            }
            
            if totalDays >= daysInCurrentMonth {
                totalDays -= daysInCurrentMonth
                if !isLeapMonth {
                    lunarMonth = monthCount
                    monthCount += 1
                }
            } else {
                if !isLeapMonth {
                    lunarMonth = monthCount
                }
                break
            }
        }
        
        lunarDay = totalDays + 1
        
        return (lunarYear, lunarMonth, lunarDay, isLeapMonth)
    }
    
    // 判断公历年是否为闰年
    private func isLeapYear(_ year: Int) -> Bool {
        return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)
    }
    
    // 获取公历月份的天数
    private func daysInMonth(year: Int, month: Int) -> Int {
        let daysInMonths = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        if month == 2 && isLeapYear(year) {
            return 29
        }
        return daysInMonths[month - 1]
    }
    
    // 获取农历年的总天数
    private func getDaysInLunarYear(_ year: Int) -> Int {
        let index = year - 1900
        guard index >= 0 && index < lunarInfo.count else { return 365 }
        
        var days = 0
        
        // 计算12个月的天数
        for month in 1...12 {
            days += getDaysInLunarMonth(year, month: month)
        }
        
        // 加上闰月天数
        let leapMonth = getLeapMonth(year)
        if leapMonth > 0 {
            days += getDaysInLeapMonth(year)
        }
        
        return days
    }
    
    // 获取农历月的天数
    private func getDaysInLunarMonth(_ year: Int, month: Int) -> Int {
        let index = year - 1900
        guard index >= 0 && index < lunarInfo.count else { return 29 }
        
        let info = lunarInfo[index]
        return (info & (0x10000 >> month)) != 0 ? 30 : 29
    }
    
    // 获取闰月月份（0表示无闰月）
    private func getLeapMonth(_ year: Int) -> Int {
        let index = year - 1900
        guard index >= 0 && index < lunarInfo.count else { return 0 }
        
        let info = lunarInfo[index]
        return Int(info & 0xf)
    }
    
    // 获取闰月天数
    private func getDaysInLeapMonth(_ year: Int) -> Int {
        let leapMonth = getLeapMonth(year)
        if leapMonth == 0 { return 0 }
        
        let index = year - 1900
        guard index >= 0 && index < lunarInfo.count else { return 29 }
        
        let info = lunarInfo[index]
        return (info & 0x10000) != 0 ? 30 : 29
    }
}

// 农历信息结构体
struct LunarInfo {
    let year: String        // 农历年份（如：甲子年）
    let month: String       // 农历月份（如：正月）
    let day: String         // 农历日期（如：初一）
    let zodiac: String      // 生肖（如：鼠）
    let isLeapMonth: Bool   // 是否闰月
    
    // 简短显示格式
    var shortDisplay: String {
        return day
    }
    
    // 完整显示格式
    var fullDisplay: String {
        let leapPrefix = isLeapMonth ? "闰" : ""
        return "\(year) \(leapPrefix)\(month)\(day)"
    }
}