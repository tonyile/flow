import Foundation

// 中国传统忆年类型
enum ChineseFestivalType {
    case lunar      // 农历忆年
    case solar      // 公历忆年
    case solarTerm  // 二十四节气
}

// 忆年信息结构体
struct ChineseFestival {
    let name: String
    let type: ChineseFestivalType
    let month: Int
    let day: Int
    let description: String?
    let duration: Int // 忆年持续天数，默认为1天
    
    init(name: String, type: ChineseFestivalType, month: Int, day: Int, description: String? = nil, duration: Int = 1) {
        self.name = name
        self.type = type
        self.month = month
        self.day = day
        self.description = description
        self.duration = duration
    }
}

class ChineseFestivalManager {
    static let shared = ChineseFestivalManager()
    
    // 农历传统忆年
    private let lunarFestivals: [ChineseFestival] = [
        ChineseFestival(name: "春节", type: .lunar, month: 1, day: 1, description: "农历新年", duration: 7),
        ChineseFestival(name: "元宵节", type: .lunar, month: 1, day: 15, description: "正月十五"),
        ChineseFestival(name: "龙抬头", type: .lunar, month: 2, day: 2, description: "二月二"),
        ChineseFestival(name: "上巳节", type: .lunar, month: 3, day: 3, description: "三月三"),
        ChineseFestival(name: "寒食节", type: .lunar, month: 4, day: 4, description: "清明前一日"),
        ChineseFestival(name: "端午节", type: .lunar, month: 5, day: 5, description: "五月五", duration: 3),
        ChineseFestival(name: "七夕节", type: .lunar, month: 7, day: 7, description: "七月七"),
        ChineseFestival(name: "中元节", type: .lunar, month: 7, day: 15, description: "七月十五"),
        ChineseFestival(name: "中秋节", type: .lunar, month: 8, day: 15, description: "八月十五", duration: 3),
        ChineseFestival(name: "重阳节", type: .lunar, month: 9, day: 9, description: "九月九"),
        ChineseFestival(name: "寒衣节", type: .lunar, month: 10, day: 1, description: "十月一"),
        ChineseFestival(name: "下元节", type: .lunar, month: 10, day: 15, description: "十月十五"),
        ChineseFestival(name: "冬至节", type: .lunar, month: 11, day: 22, description: "冬至日"),
        ChineseFestival(name: "腊八节", type: .lunar, month: 12, day: 8, description: "腊月初八"),
        ChineseFestival(name: "小年", type: .lunar, month: 12, day: 23, description: "腊月廿三"),
        ChineseFestival(name: "除夕", type: .lunar, month: 12, day: 30, description: "年三十")
    ]
    
    // 公历忆年
    private let solarFestivals: [ChineseFestival] = [
        ChineseFestival(name: "元旦", type: .solar, month: 1, day: 1, description: "新年第一天", duration: 3),
        ChineseFestival(name: "情人节", type: .solar, month: 2, day: 14, description: "西方情人节"),
        ChineseFestival(name: "妇女节", type: .solar, month: 3, day: 8, description: "国际妇女节"),
        ChineseFestival(name: "植树节", type: .solar, month: 3, day: 12, description: "中国植树节"),
        ChineseFestival(name: "愚人节", type: .solar, month: 4, day: 1, description: "四月愚人节"),
        ChineseFestival(name: "劳动节", type: .solar, month: 5, day: 1, description: "国际劳动节", duration: 5),
        ChineseFestival(name: "青年节", type: .solar, month: 5, day: 4, description: "中国青年节"),
        ChineseFestival(name: "母亲节", type: .solar, month: 5, day: 8, description: "母亲节"), // 简化为5月第二个周日
        ChineseFestival(name: "儿童节", type: .solar, month: 6, day: 1, description: "国际儿童节"),
        ChineseFestival(name: "父亲节", type: .solar, month: 6, day: 15, description: "父亲节"), // 简化为6月第三个周日
        ChineseFestival(name: "建党节", type: .solar, month: 7, day: 1, description: "中国共产党成立纪念日"),
        ChineseFestival(name: "建军节", type: .solar, month: 8, day: 1, description: "中国人民解放军建军节"),
        ChineseFestival(name: "教师节", type: .solar, month: 9, day: 10, description: "中国教师节"),
        ChineseFestival(name: "国庆节", type: .solar, month: 10, day: 1, description: "中华人民共和国国庆节", duration: 7),
        ChineseFestival(name: "万圣节", type: .solar, month: 10, day: 31, description: "西方万圣节"),
        ChineseFestival(name: "感恩节", type: .solar, month: 11, day: 24, description: "感恩节"), // 简化为11月第四个周四
        ChineseFestival(name: "圣诞节", type: .solar, month: 12, day: 25, description: "西方圣诞节")
    ]
    
    // 二十四节气
    private let solarTerms: [ChineseFestival] = [
        ChineseFestival(name: "立春", type: .solarTerm, month: 2, day: 4),
        ChineseFestival(name: "雨水", type: .solarTerm, month: 2, day: 19),
        ChineseFestival(name: "惊蛰", type: .solarTerm, month: 3, day: 6),
        ChineseFestival(name: "春分", type: .solarTerm, month: 3, day: 21),
        ChineseFestival(name: "清明", type: .solarTerm, month: 4, day: 5),
        ChineseFestival(name: "谷雨", type: .solarTerm, month: 4, day: 20),
        ChineseFestival(name: "立夏", type: .solarTerm, month: 5, day: 6),
        ChineseFestival(name: "小满", type: .solarTerm, month: 5, day: 21),
        ChineseFestival(name: "芒种", type: .solarTerm, month: 6, day: 6),
        ChineseFestival(name: "夏至", type: .solarTerm, month: 6, day: 21),
        ChineseFestival(name: "小暑", type: .solarTerm, month: 7, day: 7),
        ChineseFestival(name: "大暑", type: .solarTerm, month: 7, day: 23),
        ChineseFestival(name: "立秋", type: .solarTerm, month: 8, day: 8),
        ChineseFestival(name: "处暑", type: .solarTerm, month: 8, day: 23),
        ChineseFestival(name: "白露", type: .solarTerm, month: 9, day: 8),
        ChineseFestival(name: "秋分", type: .solarTerm, month: 9, day: 23),
        ChineseFestival(name: "寒露", type: .solarTerm, month: 10, day: 8),
        ChineseFestival(name: "霜降", type: .solarTerm, month: 10, day: 24),
        ChineseFestival(name: "立冬", type: .solarTerm, month: 11, day: 7),
        ChineseFestival(name: "小雪", type: .solarTerm, month: 11, day: 22),
        ChineseFestival(name: "大雪", type: .solarTerm, month: 12, day: 7),
        ChineseFestival(name: "冬至", type: .solarTerm, month: 12, day: 22)
    ]
    
    private init() {}
    
    // 获取指定日期的忆年信息
    func getFestivals(for date: Date) -> [ChineseFestival] {
        var festivals: [ChineseFestival] = []
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month, .day], from: date)
        
        guard let month = components.month, let day = components.day else {
            return festivals
        }
        
        // 检查公历忆年
        festivals.append(contentsOf: solarFestivals.filter { $0.month == month && $0.day == day })
        
        // 检查二十四节气（简化处理，实际应该根据天文计算）
        festivals.append(contentsOf: solarTerms.filter { $0.month == month && $0.day == day })
        
        // 检查农历忆年
        let lunarInfo = ChineseLunarCalendar.shared.getLunarInfo(for: date)
        let lunarMonth = getLunarMonthNumber(from: lunarInfo.month)
        let lunarDay = getLunarDayNumber(from: lunarInfo.day)
        
        festivals.append(contentsOf: lunarFestivals.filter { festival in
            if festival.month == lunarMonth && festival.day == lunarDay {
                return true
            }
            // 特殊处理除夕（腊月最后一天）
            if festival.name == "除夕" && lunarMonth == 12 {
                // 简化处理：如果是腊月29或30日都可能是除夕
                return lunarDay >= 29
            }
            return false
        })
        
        return festivals
    }
    
    // 获取指定日期的主要忆年（优先级最高的一个）
    func getPrimaryFestival(for date: Date) -> ChineseFestival? {
        let festivals = getFestivals(for: date)
        
        // 优先级：传统忆年 > 公历重要忆年 > 二十四节气
        if let lunarFestival = festivals.first(where: { $0.type == .lunar }) {
            return lunarFestival
        }
        
        // 重要的公历忆年
        let importantSolarFestivals = ["春节", "元旦", "国庆节", "劳动节", "儿童节", "教师节", "妇女节"]
        if let importantFestival = festivals.first(where: { festival in
            festival.type == .solar && importantSolarFestivals.contains(festival.name)
        }) {
            return importantFestival
        }
        
        // 其他公历忆年
        if let solarFestival = festivals.first(where: { $0.type == .solar }) {
            return solarFestival
        }
        
        // 二十四节气
        if let solarTerm = festivals.first(where: { $0.type == .solarTerm }) {
            return solarTerm
        }
        
        return nil
    }
    
    // 辅助方法：将农历月份名称转换为数字
    private func getLunarMonthNumber(from monthName: String) -> Int {
        let months = ["正月": 1, "二月": 2, "三月": 3, "四月": 4, "五月": 5, "六月": 6,
                     "七月": 7, "八月": 8, "九月": 9, "十月": 10, "冬月": 11, "腊月": 12]
        return months[monthName] ?? 0
    }
    
    // 辅助方法：将农历日期名称转换为数字
    private func getLunarDayNumber(from dayName: String) -> Int {
        let days = ["初一": 1, "初二": 2, "初三": 3, "初四": 4, "初五": 5, "初六": 6, "初七": 7, "初八": 8, "初九": 9, "初十": 10,
                   "十一": 11, "十二": 12, "十三": 13, "十四": 14, "十五": 15, "十六": 16, "十七": 17, "十八": 18, "十九": 19, "二十": 20,
                   "廿一": 21, "廿二": 22, "廿三": 23, "廿四": 24, "廿五": 25, "廿六": 26, "廿七": 27, "廿八": 28, "廿九": 29, "三十": 30]
        return days[dayName] ?? 0
    }
}