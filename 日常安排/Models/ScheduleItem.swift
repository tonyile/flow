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
    case bell = "bell"
    case chime = "chime"
    case ding = "ding"
    case note = "note"
    case longMelody = "long_melody"
    // 已移除：extended_alarm / peaceful_chime / nature_sounds（向后兼容在解码中处理）
    // 新增四首音乐
    case doodoo = "dududu"
    case morningBell = "morning_bell"
    case freshMorning = "fresh_morning"
    case birdsChirping = "birds_chirping"
    case custom = "custom"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .defaultSound: return "默认"
        case .classicAlarm: return "经典闹铃"
        case .digitalAlarm: return "数字闹铃"
        case .gentleAlarm: return "轻柔闹铃"
        case .urgentAlarm: return "紧急闹铃"
        case .bell: return "铃铛"
        case .chime: return "钟声"
        case .ding: return "叮咚"
        case .note: return "音符"
        case .longMelody: return "悠长旋律"
        case .doodoo: return "嘟嘟嘟嘟"
        case .morningBell: return "晨钟暮鼓"
        case .freshMorning: return "清新晨光"
        case .birdsChirping: return "鸟语花香"
        case .custom: return "自定义"
        }
    }
    
    var systemSoundName: String? {
        switch self {
        case .defaultSound: return nil // 使用系统默认
        case .classicAlarm: return "classic_alarm"
        case .digitalAlarm: return "digital_alarm"
        case .gentleAlarm: return "gentle_alarm"
        case .urgentAlarm: return "urgent_alarm"
        case .bell: return "bell"
        case .chime: return "chime"
        case .ding: return "ding"
        case .note: return "note"
        case .longMelody: return "long_melody"
        case .doodoo: return "嘟嘟嘟嘟"
        case .morningBell: return "晨钟暮鼓"
        case .freshMorning: return "清新晨光"
        case .birdsChirping: return "鸟语花香"
        case .custom: return nil // 自定义音乐需要用户选择
        }
    }
    
    var icon: String {
        switch self {
        case .defaultSound: return "speaker.wave.2"
        case .classicAlarm: return "alarm"
        case .digitalAlarm: return "deskclock"
        case .gentleAlarm: return "bell.and.waves.left.and.right"
        case .urgentAlarm: return "exclamationmark.triangle"
        case .bell: return "bell"
        case .chime: return "bell.and.waves.left.and.right"
        case .ding: return "bell.circle"
        case .note: return "music.note"
        case .longMelody: return "music.note.list"
        case .doodoo: return "music.note"
        case .morningBell: return "music.note"
        case .freshMorning: return "music.note"
        case .birdsChirping: return "music.note"
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
    var reminderSound: ReminderSound = .defaultSound // 提醒音乐
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
    
    // 计算当前计划的状态
    var status: ScheduleStatus {
        let now = Date()
        
        // 如果已完成，返回已完成状态
        if isCompleted {
            return .completed
        }
        
        // 如果已过期（结束时间已过），返回过期状态
        if endTime < now {
            return .overdue
        }
        
        // 如果正在进行中（开始时间已过，结束时间未过）
        if startTime <= now && endTime >= now {
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
            item.reminderSound = ReminderSound(rawValue: soundRawValue) ?? .defaultSound
        }
        item.modifiedDate = record["modifiedDate"] as? Date ?? Date()
        item.isDeleted = record["isDeleted"] as? Bool ?? false
        item.city = record["city"] as? String
        
        return item
    }
}
