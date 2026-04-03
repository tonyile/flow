import Foundation
import SwiftUI
import CloudKit

enum FestivalType: String, Codable, CaseIterable, Identifiable {
    case solar = "solar"
    case lunar = "lunar"
    case solarTerm = "solarTerm"
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .solar: return "阳历"
        case .lunar: return "阴历"
        case .solarTerm: return "节气"
        }
    }
}

// MARK: - 提醒音乐枚举
enum ReminderSound: String, Codable, CaseIterable, Identifiable {
    case defaultSound = "default"
    case classicAlarm = "classic_alarm"
    case digitalAlarm = "digital_alarm"
    case gentleAlarm = "gentle_alarm"
    case urgentAlarm = "urgent_alarm"
    case longMelody = "long_melody"
    // 已移除：extended_alarm / peaceful_chime / nature_sounds（向后兼容在解码中处理）
    // 新增四首音乐
    case doodoo = "dududu"
    case morningBell = "morning_bell"
    case freshMorning = "fresh_morning"
    case birdsChirping = "birds_chirping"
    case custom = "custom"

    // 自定义展示顺序并排除默认项（默认由“轻柔闹铃”替代）
    static var allCases: [ReminderSound] = [
        .gentleAlarm,
        .classicAlarm,
        .digitalAlarm,
        .urgentAlarm,
        .longMelody,
        .doodoo,
        .morningBell,
        .freshMorning,
        .birdsChirping,
        .custom
    ]
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .defaultSound: return "轻柔闹铃"
        case .classicAlarm: return "经典闹铃"
        case .digitalAlarm: return "数字闹铃"
        case .gentleAlarm: return "轻柔闹铃"
        case .urgentAlarm: return "紧急闹铃"
        case .longMelody: return "悠长旋律"
        case .doodoo: return "嘟嘟嘟嘟"
        case .morningBell: return "晨钟暮鼓"
        case .freshMorning: return "清新晨光"
        case .birdsChirping: return "鸟语花香"
        case .custom: return "自定义"
        }
    }
    
    /// 主 Bundle / Sounds 内音频文件的候选基名（无扩展名）：优先英文 `rawValue`，兼容历史中文文件名资源
    var bundleSoundBaseNameCandidates: [String] {
        switch self {
        case .defaultSound, .custom: return []
        case .morningBell: return ["morning_bell", "晨钟暮鼓"]
        case .doodoo: return ["dududu", "嘟嘟嘟嘟"]
        case .freshMorning: return ["fresh_morning", "清新晨光"]
        case .birdsChirping: return ["birds_chirping", "鸟语花香"]
        default: return [rawValue]
        }
    }

    /// 在 Bundle 中查找首个匹配的 wav/caf（含 `Sounds` 子目录）
    func firstBundleSoundURL() -> URL? {
        for base in bundleSoundBaseNameCandidates {
            if let url = Bundle.main.url(forResource: base, withExtension: "wav")
                ?? Bundle.main.url(forResource: base, withExtension: "wav", subdirectory: "Sounds")
                ?? Bundle.main.url(forResource: base, withExtension: "caf")
                ?? Bundle.main.url(forResource: base, withExtension: "caf", subdirectory: "Sounds") {
                return url
            }
        }
        return nil
    }
    
    var icon: String {
        switch self {
        case .defaultSound: return "speaker.wave.2"
        case .classicAlarm: return "alarm"
        case .digitalAlarm: return "deskclock"
        case .gentleAlarm: return "bell.and.waves.left.and.right"
        case .urgentAlarm: return "exclamationmark.triangle"
        case .longMelody: return "music.quarternote.3"
        case .doodoo: return "waveform"
        case .morningBell: return "bell.circle"
        case .freshMorning: return "sunrise"
        case .birdsChirping: return "bird"
        case .custom: return "music.note.list"
        }
    }

    // 自定义解码以兼容被移除的旧枚举值，防止崩溃
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        if let sound = ReminderSound(rawValue: value) {
            self = sound
            return
        }
        // 旧值映射与兜底
        switch value {
        case "extended_alarm":
            self = .longMelody // 迁移到悠长旋律
        case "peaceful_chime", "nature_sounds":
            self = .defaultSound // 回退到默认提示音
        case "bell", "chime", "ding", "note":
            self = .gentleAlarm // 已移除旧值映射到轻柔闹铃
        default:
            self = .defaultSound
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

enum ScheduleCategory: String, Codable, CaseIterable, Identifiable {
    case work, study, life, health, festival, other
    var id: String { rawValue }
    var label: String {
        switch self {
        case .work: return "工作"
        case .study: return "学习"
        case .life: return "生活"
        case .health: return "健康"
        case .festival: return "周年"
        case .other: return "其他"
        }
    }
    var icon: String {
        switch self {
        case .work: return "briefcase"
        case .study: return "book"
        case .life: return "house"
        case .health: return "heart"
        case .festival: return "calendar"
        case .other: return "tag"
        }
    }
    var color: Color {
        switch self {
        case .work: return .blue
        case .study: return .green
        case .life: return .orange
        case .health: return .red
        case .festival: return .pink
        case .other: return .purple
        }
    }
}

enum SchedulePriority: String, Codable, CaseIterable, Identifiable {
    case low, medium, high
    var id: String { rawValue }
    var label: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        }
    }
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }
}

enum ScheduleStatus: String, Codable, CaseIterable, Identifiable {
    case normal      // 正常计划
    case upcoming    // 快到期（15分钟内开始）
    case inProgress  // 进行中
    case completed   // 已完成
    case overdue     // 过期未完成
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .normal: return "待处理"
        case .upcoming: return "即将开始"
        case .inProgress: return "进行中"
        case .completed: return "已完成"
        case .overdue: return "已过期"
        }
    }
    
    var color: Color {
        switch self {
        case .normal: return .green
        case .upcoming: return .yellow
        case .inProgress: return .blue
        case .completed: return .green // 改为绿色，建立积极的视觉关联
        case .overdue: return Color(red: 0.4, green: 0.4, blue: 0.4) // 深灰色，营造"沉没"感觉
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .normal: return .green.opacity(0.1)
        case .upcoming: return .yellow.opacity(0.1)
        case .inProgress: return .blue.opacity(0.1)
        case .completed: return .green.opacity(0.1) // 浅绿色背景
        case .overdue: return Color.white // 纯白色背景，使其看起来"被搁置"
        }
    }
    
    var borderColor: Color {
        switch self {
        case .normal: return .green.opacity(0.3)
        case .upcoming: return .yellow.opacity(0.5)
        case .inProgress: return .blue.opacity(0.5)
        case .completed: return .green.opacity(0.3) // 浅绿色边框
        case .overdue: return Color(red: 0.95, green: 0.95, blue: 0.95) // 极浅灰色边框
        }
    }
    
    // 新增：状态标签的填充颜色
    var labelBackgroundColor: Color {
        switch self {
        case .normal: return .green
        case .upcoming: return .yellow
        case .inProgress: return .blue
        case .completed: return .green // 绿色填充
        case .overdue: return Color(red: 0.8, green: 0.4, blue: 0.4) // 柔和的砖红色填充
        }
    }
    
    // 新增：状态标签的文字颜色
    var labelTextColor: Color {
        switch self {
        case .normal: return .white
        case .upcoming: return .black // 黄色背景用黑色文字
        case .inProgress: return .white
        case .completed: return .white // 白色文字
        case .overdue: return .white // 白色文字，提供高对比度
        }
    }
}

struct ScheduleItem: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var notes: String
    var category: ScheduleCategory
    var priority: SchedulePriority
    var startTime: Date
    var endTime: Date
    var isCompleted: Bool
    
    // 重复日程相关字段
    var isRecurring: Bool = false
    var recurringStartDate: Date?
    var recurringEndDate: Date?
    var recurringWeekdays: [Int] = []
    
    // 忆年相关属性
    var isFestival: Bool = false
    var festivalType: FestivalType = .solar
    var isYearlyRecurring: Bool = false // 1=周日, 2=周一, ..., 7=周六
    var parentId: UUID? // 用于标识重复日程的父ID
    
    // 提醒相关字段
    var hasReminder: Bool = false
    var reminderTime: Date?
    var reminderMinutesBefore: Int = 15 // 提前多少分钟提醒
    var notificationId: String? // 本地通知ID
    var reminderSound: ReminderSound = .morningBell // 提醒音乐（默认晨钟暮鼓）
    var customSoundURL: URL? // 自定义音乐文件路径
    
    // 城市相关属性
    var city: String? // 日程关联的城市，用于获取天气信息
    
    // CloudKit同步相关字段
    var recordName: String? // CloudKit记录名
    var modifiedDate: Date = Date() // 最后修改时间
    var isDeleted: Bool = false // 软删除标记
    
    init(title: String, notes: String, category: ScheduleCategory, priority: SchedulePriority, startTime: Date, endTime: Date, isCompleted: Bool = false, city: String? = nil) {
        self.title = title
        self.notes = notes
        self.category = category
        self.priority = priority
        self.startTime = startTime
        self.endTime = endTime
        self.isCompleted = isCompleted
        self.city = city
        self.modifiedDate = Date()
        
        // 为新创建的日程生成通知ID
        self.notificationId = "schedule_\(self.id.uuidString)"
    }

    /// 日历意义上的结束时间。同一天内若结束钟点早于开始钟点，视为跨到次日该时刻结束（如 22:00 → 次日 02:00）。
    var effectiveEndTime: Date {
        let cal = Calendar.current
        if cal.isDate(endTime, inSameDayAs: startTime), endTime < startTime {
            return cal.date(byAdding: .day, value: 1, to: endTime) ?? endTime
        }
        return endTime
    }

    /// 是否与 `day` 所在公历日有交集（跨天日程在中间日期也应出现）
    func intersectsCalendarDay(_ day: Date) -> Bool {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: day)
        guard let dayEndExclusive = cal.date(byAdding: .day, value: 1, to: dayStart) else { return false }
        return startTime < dayEndExclusive && effectiveEndTime > dayStart
    }
    
    // 计算当前计划的状态
    var status: ScheduleStatus {
        let now = Date()
        
        // 如果已完成，返回已完成状态
        if isCompleted {
            return .completed
        }
        
        // 如果已过期（按有效结束时间判断，避免跨天/凌晨结束被误判）
        if effectiveEndTime < now {
            return .overdue
        }
        
        // 如果正在进行中（开始时间已过，有效结束时间未过）
        if startTime <= now && effectiveEndTime >= now {
            return .inProgress
        }
        
        // 如果即将开始（15分钟内），返回即将开始状态
        let timeUntilStart = startTime.timeIntervalSince(now)
        if timeUntilStart <= 15 * 60 && timeUntilStart > 0 {
            return .upcoming
        }
        
        // 其他情况返回正常状态
        return .normal
    }
}

// MARK: - Equatable Conformance
extension ScheduleItem: Equatable {
    static func == (lhs: ScheduleItem, rhs: ScheduleItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.notes == rhs.notes &&
        lhs.category == rhs.category &&
        lhs.priority == rhs.priority &&
        lhs.startTime == rhs.startTime &&
        lhs.endTime == rhs.endTime &&
        lhs.isCompleted == rhs.isCompleted &&
        lhs.isRecurring == rhs.isRecurring &&
        lhs.recurringStartDate == rhs.recurringStartDate &&
        lhs.recurringEndDate == rhs.recurringEndDate &&
        lhs.recurringWeekdays == rhs.recurringWeekdays &&
        lhs.isFestival == rhs.isFestival &&
        lhs.festivalType == rhs.festivalType &&
        lhs.isYearlyRecurring == rhs.isYearlyRecurring &&
        lhs.parentId == rhs.parentId &&
        lhs.hasReminder == rhs.hasReminder &&
        lhs.reminderTime == rhs.reminderTime &&
        lhs.reminderMinutesBefore == rhs.reminderMinutesBefore &&
        lhs.notificationId == rhs.notificationId &&
        lhs.reminderSound == rhs.reminderSound &&
        lhs.customSoundURL == rhs.customSoundURL &&
        lhs.city == rhs.city &&
        lhs.recordName == rhs.recordName &&
        lhs.modifiedDate == rhs.modifiedDate &&
        lhs.isDeleted == rhs.isDeleted
    }
}

// MARK: - CloudKit Extensions
extension ScheduleItem {
    // 转换为CloudKit记录
    func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: recordName ?? id.uuidString)
        let record = CKRecord(recordType: "ScheduleItem", recordID: recordID)
        
        record["title"] = title
        record["notes"] = notes
        record["category"] = category.rawValue
        record["priority"] = priority.rawValue
        record["startTime"] = startTime
        record["endTime"] = endTime
        record["isCompleted"] = isCompleted
        record["isRecurring"] = isRecurring
        record["recurringStartDate"] = recurringStartDate
        record["recurringEndDate"] = recurringEndDate
        record["recurringWeekdays"] = recurringWeekdays
        record["parentId"] = parentId?.uuidString
        record["isFestival"] = isFestival
        record["festivalType"] = festivalType.rawValue
        record["isYearlyRecurring"] = isYearlyRecurring
        record["hasReminder"] = hasReminder
        record["reminderTime"] = reminderTime
        record["reminderMinutesBefore"] = reminderMinutesBefore
        record["reminderSound"] = reminderSound.rawValue
        record["modifiedDate"] = modifiedDate
        record["isDeleted"] = isDeleted
        record["city"] = city
        
        return record
    }
    
    // 从CloudKit记录创建
    static func fromCKRecord(_ record: CKRecord) -> ScheduleItem? {
        guard let title = record["title"] as? String,
              let notes = record["notes"] as? String,
              let categoryRaw = record["category"] as? String,
              let category = ScheduleCategory(rawValue: categoryRaw),
              let priorityRaw = record["priority"] as? String,
              let priority = SchedulePriority(rawValue: priorityRaw),
              let startTime = record["startTime"] as? Date,
              let endTime = record["endTime"] as? Date,
              let isCompleted = record["isCompleted"] as? Bool else {
            return nil
        }
        
        var item = ScheduleItem(title: title, notes: notes, category: category, priority: priority, startTime: startTime, endTime: endTime, isCompleted: isCompleted)
        
        item.id = UUID(uuidString: record.recordID.recordName) ?? UUID()
        item.recordName = record.recordID.recordName
        item.isRecurring = record["isRecurring"] as? Bool ?? false
        item.recurringStartDate = record["recurringStartDate"] as? Date
        item.recurringEndDate = record["recurringEndDate"] as? Date
        
        if let weekdaysArray = record["recurringWeekdays"] as? [Int] {
            item.recurringWeekdays = weekdaysArray
        }
        
        if let parentIdString = record["parentId"] as? String {
            item.parentId = UUID(uuidString: parentIdString)
        }
        
        item.isFestival = record["isFestival"] as? Bool ?? false
        if let festivalTypeRaw = record["festivalType"] as? String,
           let festivalType = FestivalType(rawValue: festivalTypeRaw) {
            item.festivalType = festivalType
        }
        item.isYearlyRecurring = record["isYearlyRecurring"] as? Bool ?? false
        
        item.hasReminder = record["hasReminder"] as? Bool ?? false
        item.reminderTime = record["reminderTime"] as? Date
        item.reminderMinutesBefore = record["reminderMinutesBefore"] as? Int ?? 15
        if let soundRawValue = record["reminderSound"] as? String {
            switch soundRawValue {
            case "bell", "chime", "ding", "note":
                item.reminderSound = .gentleAlarm // 旧值迁移到轻柔闹铃
            default:
                item.reminderSound = ReminderSound(rawValue: soundRawValue) ?? .defaultSound
            }
        }
        item.modifiedDate = record["modifiedDate"] as? Date ?? Date()
        item.isDeleted = record["isDeleted"] as? Bool ?? false
        item.city = record["city"] as? String
        
        return item
    }
}
