import SwiftUI

struct ScheduleMergeView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var scheduleStore: ScheduleStore
    
    @State private var selectedSchedules: Set<UUID> = []
    @State private var showingMergeConfirmation = false
    @State private var mergePreview: ScheduleItem?
    
    let suggestedSchedules: [ScheduleItem]
    
    init(scheduleStore: ScheduleStore, suggestedSchedules: [ScheduleItem] = []) {
        self.scheduleStore = scheduleStore
        self.suggestedSchedules = suggestedSchedules.isEmpty ? 
            ScheduleMergeView.findMergeableSuggestions(from: scheduleStore.scheduleItems) : 
            suggestedSchedules
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if suggestedSchedules.isEmpty {
                    ContentUnavailableView(
                        "没有可合并的日程",
                        systemImage: "calendar.badge.plus",
                        description: Text("当前没有发现相似或重叠的日程可以合并")
                    )
                } else {
                    List {
                        Section(header: Text("建议合并的日程")) {
                            ForEach(suggestedSchedules, id: \.id) { schedule in
                                ScheduleMergeRow(
                                    schedule: schedule,
                                    isSelected: selectedSchedules.contains(schedule.id)
                                ) {
                                    toggleSelection(for: schedule.id)
                                }
                            }
                        }
                        
                        if selectedSchedules.count >= 2 {
                            Section(header: Text("合并预览")) {
                                if let preview = generateMergePreview() {
                                    SchedulePreviewRow(schedule: preview)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("合并日程")
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
                    Button("合并") {
                        showingMergeConfirmation = true
                    }
                    .disabled(selectedSchedules.count < 2)
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("合并") {
                        showingMergeConfirmation = true
                    }
                    .disabled(selectedSchedules.count < 2)
                }
                #endif
            }
            .alert("确认合并", isPresented: $showingMergeConfirmation) {
                Button("取消", role: .cancel) { }
                Button("合并") {
                    performMerge()
                }
            } message: {
                Text("将合并 \(selectedSchedules.count) 个日程为一个新日程，原日程将被删除。此操作不可撤销。")
            }
        }
    }
    
    private func toggleSelection(for id: UUID) {
        if selectedSchedules.contains(id) {
            selectedSchedules.remove(id)
        } else {
            selectedSchedules.insert(id)
        }
    }
    
    private func generateMergePreview() -> ScheduleItem? {
        let schedulesToMerge = suggestedSchedules.filter { selectedSchedules.contains($0.id) }
        guard schedulesToMerge.count >= 2 else { return nil }
        
        let mergedTitle = schedulesToMerge.map { $0.title }.joined(separator: " + ")
        let mergedNotes = schedulesToMerge.compactMap { $0.notes.isEmpty ? nil : $0.notes }.joined(separator: "\n")
        let earliestStart = schedulesToMerge.min { $0.startTime < $1.startTime }!.startTime
        let latestEnd = schedulesToMerge.max { $0.endTime < $1.endTime }!.endTime
        let highestPriority = schedulesToMerge.max { $0.priority.rawValue < $1.priority.rawValue }!.priority
        let firstCategory = schedulesToMerge[0].category
        
        return ScheduleItem(
            title: mergedTitle,
            notes: mergedNotes,
            category: firstCategory,
            priority: highestPriority,
            startTime: earliestStart,
            endTime: latestEnd,
            isCompleted: false
        )
    }
    
    private func performMerge() {
        let success = scheduleStore.mergeSchedules(Array(selectedSchedules))
        if success {
            dismiss()
        }
    }
    
    // 静态方法：查找可合并的日程建议
    static func findMergeableSuggestions(from schedules: [ScheduleItem]) -> [ScheduleItem] {
        let calendar = Calendar.current
        var suggestions: [ScheduleItem] = []
        
        // 按日期分组
        let groupedByDate = Dictionary(grouping: schedules) { schedule in
            calendar.startOfDay(for: schedule.startTime)
        }
        
        for (_, daySchedules) in groupedByDate {
            // 查找同一天内相似或重叠的日程
            for i in 0..<daySchedules.count {
                for j in (i+1)..<daySchedules.count {
                    let schedule1 = daySchedules[i]
                    let schedule2 = daySchedules[j]
                    
                    if areMergeable(schedule1, schedule2) {
                        if !suggestions.contains(where: { $0.id == schedule1.id }) {
                            suggestions.append(schedule1)
                        }
                        if !suggestions.contains(where: { $0.id == schedule2.id }) {
                            suggestions.append(schedule2)
                        }
                    }
                }
            }
        }
        
        return suggestions.sorted { $0.startTime < $1.startTime }
    }
    
    // 判断两个日程是否可以合并
    static func areMergeable(_ schedule1: ScheduleItem, _ schedule2: ScheduleItem) -> Bool {
        let calendar = Calendar.current
        
        // 必须在同一天
        guard calendar.isDate(schedule1.startTime, inSameDayAs: schedule2.startTime) else {
            return false
        }
        
        // 相同分类更容易合并
        if schedule1.category == schedule2.category {
            // 检查时间是否重叠或相邻（30分钟内）
            let gap = min(
                abs(schedule1.endTime.timeIntervalSince(schedule2.startTime)),
                abs(schedule2.endTime.timeIntervalSince(schedule1.startTime))
            )
            
            if gap <= 1800 { // 30分钟内
                return true
            }
        }
        
        // 检查标题相似性
        let similarity = calculateTitleSimilarity(schedule1.title, schedule2.title)
        if similarity > 0.6 { // 60%以上相似度
            return true
        }
        
        return false
    }
    
    // 计算标题相似度
    static func calculateTitleSimilarity(_ title1: String, _ title2: String) -> Double {
        let words1 = Set(title1.lowercased().components(separatedBy: .whitespacesAndNewlines))
        let words2 = Set(title2.lowercased().components(separatedBy: .whitespacesAndNewlines))
        
        let intersection = words1.intersection(words2)
        let union = words1.union(words2)
        
        return union.isEmpty ? 0 : Double(intersection.count) / Double(union.count)
    }
}

struct ScheduleMergeRow: View {
    let schedule: ScheduleItem
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onTap) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .gray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(schedule.title)
                    .font(.headline)
                
                HStack {
                    Label(schedule.category.label, systemImage: schedule.category.icon)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(schedule.startTime, formatter: DateFormatter.timeOnly) - \(schedule.endTime, formatter: DateFormatter.timeOnly)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if !schedule.notes.isEmpty {
                    Text(schedule.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

struct SchedulePreviewRow: View {
    let schedule: ScheduleItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "arrow.triangle.merge")
                    .foregroundColor(.accentColor)
                Text("合并后的日程")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(schedule.title)
                    .font(.headline)
                
                HStack {
                    Label(schedule.category.label, systemImage: schedule.category.icon)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(schedule.startTime, formatter: DateFormatter.timeOnly) - \(schedule.endTime, formatter: DateFormatter.timeOnly)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if !schedule.notes.isEmpty {
                    Text(schedule.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
            }
            .padding()
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

extension DateFormatter {
    static let timeOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview {
    let store = ScheduleStore.shared
    let sampleSchedules = [
        ScheduleItem(
            title: "工作会议",
            notes: "项目讨论",
            category: .work,
            priority: .high,
            startTime: Date(),
            endTime: Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date(),
            isCompleted: false
        ),
        ScheduleItem(
            title: "工作汇报",
            notes: "周报总结",
            category: .work,
            priority: .medium,
            startTime: Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date(),
            endTime: Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date(),
            isCompleted: false
        )
    ]
    
    ScheduleMergeView(scheduleStore: store, suggestedSchedules: sampleSchedules)
}