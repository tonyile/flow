import Foundation
import SwiftUI
import CloudKit
import Combine

// 流水类型枚举
enum FlowType: String, Codable, CaseIterable, Identifiable {
    case event = "event"        // 事件
    case income = "income"      // 收入
    case expense = "expense"    // 支出
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .event: return "事件"
        case .income: return "收入"
        case .expense: return "支出"
        }
    }
    
    var icon: String {
        switch self {
        case .event: return "calendar.badge.clock"
        case .income: return "arrow.up.circle"
        case .expense: return "arrow.down.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .event: return .blue
        case .income: return .green
        case .expense: return .red
        }
    }
    
    var amountPrefix: String {
        switch self {
        case .income: return "+"
        case .expense: return "-"
        default: return ""
        }
    }
    
    var amountColor: Color {
        switch self {
        case .income: return .green
        case .expense: return .red
        default: return .primary
        }
    }
    
    var hasAmount: Bool {
        switch self {
        case .income, .expense: return true
        case .event: return false
        }
    }
}

// 流水项目数据模型
class FlowItem: ObservableObject, Identifiable, Codable {
    let id = UUID()
    @Published var title: String
    @Published var type: FlowType
    @Published var amount: Double?           // 金额（可选，用于账单、馈赠、收支）
    @Published var currency: String          // 货币单位
    @Published var relatedPeople: [String]   // 相关人员
    @Published var relatedItems: [String]    // 对应物品
    @Published var date: Date
    @Published var notes: String             // 备注
    @Published var tags: [String]            // 标签
    @Published var location: String?         // 地点
    @Published var isCompleted: Bool         // 是否完成
    @Published var createdDate: Date
    @Published var modifiedDate: Date
    
    // CloudKit相关
    @Published var recordID: CKRecord.ID?
    @Published var isDeleted: Bool = false
    
    init(
        title: String = "",
        type: FlowType = .event,
        amount: Double? = nil,
        currency: String = "¥",
        relatedPeople: [String] = [],
        relatedItems: [String] = [],
        date: Date = Date(),
        notes: String = "",
        tags: [String] = [],
        location: String? = nil,
        isCompleted: Bool = false
    ) {
        self.title = title
        self.type = type
        self.amount = amount
        self.currency = currency
        self.relatedPeople = relatedPeople
        self.relatedItems = relatedItems
        self.date = date
        self.notes = notes
        self.tags = tags
        self.location = location
        self.isCompleted = isCompleted
        self.createdDate = Date()
        self.modifiedDate = Date()
    }
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, title, type, amount, currency, relatedPeople, relatedItems
        case date, notes, tags, location, isCompleted, createdDate, modifiedDate
        case recordID, isDeleted
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        title = try container.decode(String.self, forKey: .title)
        type = try container.decode(FlowType.self, forKey: .type)
        amount = try container.decodeIfPresent(Double.self, forKey: .amount)
        currency = try container.decode(String.self, forKey: .currency)
        relatedPeople = try container.decode([String].self, forKey: .relatedPeople)
        relatedItems = try container.decode([String].self, forKey: .relatedItems)
        date = try container.decode(Date.self, forKey: .date)
        notes = try container.decode(String.self, forKey: .notes)
        tags = try container.decode([String].self, forKey: .tags)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        createdDate = try container.decode(Date.self, forKey: .createdDate)
        modifiedDate = try container.decode(Date.self, forKey: .modifiedDate)
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        
        // CloudKit Record ID处理
        if let recordIDString = try container.decodeIfPresent(String.self, forKey: .recordID) {
            recordID = CKRecord.ID(recordName: recordIDString)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(title, forKey: .title)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(amount, forKey: .amount)
        try container.encode(currency, forKey: .currency)
        try container.encode(relatedPeople, forKey: .relatedPeople)
        try container.encode(relatedItems, forKey: .relatedItems)
        try container.encode(date, forKey: .date)
        try container.encode(notes, forKey: .notes)
        try container.encode(tags, forKey: .tags)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encode(createdDate, forKey: .createdDate)
        try container.encode(modifiedDate, forKey: .modifiedDate)
        try container.encode(isDeleted, forKey: .isDeleted)
        
        // CloudKit Record ID处理
        try container.encodeIfPresent(recordID?.recordName, forKey: .recordID)
    }
    
    // MARK: - CloudKit Methods
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "FlowItem", recordID: recordID ?? CKRecord.ID())
        
        record["title"] = title as CKRecordValue
        record["type"] = type.rawValue as CKRecordValue
        record["amount"] = amount as CKRecordValue?
        record["currency"] = currency as CKRecordValue
        record["relatedPeople"] = relatedPeople as CKRecordValue
        record["relatedItems"] = relatedItems as CKRecordValue
        record["date"] = date as CKRecordValue
        record["notes"] = notes as CKRecordValue
        record["tags"] = tags as CKRecordValue
        record["location"] = location as CKRecordValue?
        record["isCompleted"] = isCompleted as CKRecordValue
        record["createdDate"] = createdDate as CKRecordValue
        record["modifiedDate"] = modifiedDate as CKRecordValue
        record["isDeleted"] = isDeleted as CKRecordValue
        
        return record
    }
    
    static func fromCKRecord(_ record: CKRecord) -> FlowItem {
        let item = FlowItem()
        
        item.recordID = record.recordID
        item.title = record["title"] as? String ?? ""
        if let typeString = record["type"] as? String,
           let flowType = FlowType(rawValue: typeString) {
            item.type = flowType
        }
        item.amount = record["amount"] as? Double
        item.currency = record["currency"] as? String ?? "¥"
        item.relatedPeople = record["relatedPeople"] as? [String] ?? []
        item.relatedItems = record["relatedItems"] as? [String] ?? []
        item.date = record["date"] as? Date ?? Date()
        item.notes = record["notes"] as? String ?? ""
        item.tags = record["tags"] as? [String] ?? []
        item.location = record["location"] as? String
        item.isCompleted = record["isCompleted"] as? Bool ?? false
        item.createdDate = record["createdDate"] as? Date ?? Date()
        item.modifiedDate = record["modifiedDate"] as? Date ?? Date()
        item.isDeleted = record["isDeleted"] as? Bool ?? false
        
        return item
    }
    
    // MARK: - Helper Methods
    var formattedAmount: String {
        guard let amount = amount else { return "" }
        let _ = amount  // 使用amount变量避免警告
        return String(format: "%.2f", amount)
    }
    
    var displayAmount: String {
        guard let amount = amount else { return "" }
        return "\(currency)\(formattedAmount)"
    }
    
    func updateModifiedDate() {
        modifiedDate = Date()
    }
}

// MARK: - Extensions
extension FlowItem: Hashable {
    static func == (lhs: FlowItem, rhs: FlowItem) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}