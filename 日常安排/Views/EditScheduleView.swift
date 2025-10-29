import SwiftUI
import AVFoundation
import Foundation

struct EditScheduleView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var scheduleStore: ScheduleStore
    
    let scheduleItem: ScheduleItem
    
    @State private var title: String
    @State private var notes: String
    @State private var category: ScheduleCategory
    @State private var priority: SchedulePriority
    @State private var scheduleDate: Date
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var isMultiDay: Bool
    @State private var endDate: Date
    @State private var selectedWeekdays: Set<Int>
    @State private var hasReminder: Bool
    @State private var reminderMinutesBefore: Int
    @State private var reminderSound: ReminderSound
    @State private var customSoundURL: URL?
    @State private var isShowingSoundSelection = false
    
    // 统一日程管理
    @State private var isUnifiedSchedule: Bool = false
    @State private var showUnifiedScheduleAlert: Bool = false
    @State private var showUnifiedDeleteAlert: Bool = false
    @State private var unifiedScheduleCount: Int = 0
    
    // 城市选择相关状态
    @State private var selectedCity: String = ""
    @State private var showCitySelection = false
    
    private let parentId = UUID()
    
    init(scheduleItem: ScheduleItem, scheduleStore: ScheduleStore) {
        self.scheduleItem = scheduleItem
        self.scheduleStore = scheduleStore
        
        _title = State(initialValue: scheduleItem.title)
        _notes = State(initialValue: scheduleItem.notes)
        _category = State(initialValue: scheduleItem.category)
        _priority = State(initialValue: scheduleItem.priority)
        _scheduleDate = State(initialValue: scheduleItem.startTime)
        _startTime = State(initialValue: scheduleItem.startTime)
        _endTime = State(initialValue: scheduleItem.endTime)
        _isMultiDay = State(initialValue: scheduleItem.isRecurring)
        _endDate = State(initialValue: scheduleItem.recurringEndDate ?? scheduleItem.startTime)
        _selectedWeekdays = State(initialValue: Set(scheduleItem.recurringWeekdays))
        _hasReminder = State(initialValue: scheduleItem.hasReminder)
        _reminderMinutesBefore = State(initialValue: scheduleItem.reminderMinutesBefore)
        _reminderSound = State(initialValue: scheduleItem.reminderSound)
        _customSoundURL = State(initialValue: scheduleItem.customSoundURL)
        
        // 初始化城市选择
        _selectedCity = State(initialValue: scheduleItem.city ?? "")
        
        // 检查是否为统一日程
        let unifiedSchedules = scheduleStore.findUnifiedSchedules(for: scheduleItem)
        _isUnifiedSchedule = State(initialValue: unifiedSchedules.count > 1)
        _unifiedScheduleCount = State(initialValue: unifiedSchedules.count)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基本信息")) {
                    TextField("标题", text: $title)
                        .onSubmit {
                            hideKeyboard()
                        }
                    TextField("备注", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                        .onSubmit {
                            hideKeyboard()
                        }
                }
                
                Section(header: Text("分类")) {
                    Picker("分类", selection: $category) {
                        ForEach(ScheduleCategory.allCases) { c in
                            HStack {
                                Image(systemName: c.icon)
                                Text(c.label)
                            }
                            .tag(c)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section(header: Text("优先级")) {
                    Picker("优先级", selection: $priority) {
                        ForEach(SchedulePriority.allCases) { p in
                            HStack {
                                Circle()
                                    .fill(p.color)
                                    .frame(width: 12, height: 12)
                                Text(p.label)
                            }
                            .tag(p)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    // 统一日程管理选项
                    if isUnifiedSchedule {
                        HStack {
                            Image(systemName: "link")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("统一日程")
                                    .font(.body)
                                Text("发现 \(unifiedScheduleCount) 个相同名称和时间的日程")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("统一修改") {
                                showUnifiedScheduleAlert = true
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section(header: Text("城市选择")) {
                    Button(action: {
                        showCitySelection = true
                    }) {
                        HStack {
                            Image(systemName: "location")
                                .foregroundColor(.blue)
                            Text("城市")
                            Spacer()
                            Text(selectedCity.isEmpty ? "未选择" : selectedCity)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.primary)
                }

                Section(header: Text("日期范围")) {
                    HStack {
                        Text("开始日期")
                        Spacer()
                        Text(scheduleDate, style: .date)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("多天日程")
                        Spacer()
                        Text(isMultiDay ? "是" : "否")
                            .foregroundColor(.secondary)
                    }
                    
                    if isMultiDay {
                        HStack {
                            Text("结束日期")
                            Spacer()
                            Text(endDate, style: .date)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(header: Text("时间")) {
                    DatePicker("开始时间", selection: $startTime, displayedComponents: .hourAndMinute)
                        .onChange(of: startTime) { _, newValue in
                            // 如果结束时间小于开始时间，自动调整结束时间为开始时间
                            if endTime < newValue {
                                endTime = newValue
                            }
                        }
                    DatePicker("结束时间", selection: $endTime, displayedComponents: .hourAndMinute)
                        .onChange(of: endTime) { _, newValue in
                            // 确保结束时间不早于开始时间
                            if newValue < startTime {
                                endTime = startTime
                            }
                        }
                }
                
                if isMultiDay {
                    Section(header: Text("重复日期")) {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                            let weekdays = [
                                (2, "周一"), (3, "周二"), (4, "周三"), (5, "周四"),
                                (6, "周五"), (7, "周六"), (1, "周日")
                            ]
                            ForEach(weekdays, id: \.0) { weekday in
                                Text(weekday.1)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(selectedWeekdays.contains(weekday.0) ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(selectedWeekdays.contains(weekday.0) ? .white : .secondary)
                                    .cornerRadius(16)
                            }
                        }
                        .padding(.vertical, 8)
                        
                        if selectedWeekdays.isEmpty && isMultiDay {
                            Text("未设置重复日期")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(header: Text("提醒设置")) {
                    Toggle("启用提醒", isOn: $hasReminder)
                    
                    if hasReminder {
                        Picker("提前提醒", selection: $reminderMinutesBefore) {
                            ForEach([5, 10, 15, 30, 60], id: \.self) { minutes in
                                Text("\(minutes)分钟").tag(minutes)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        
                        Picker("提醒音", selection: $reminderSound) {
                            ForEach(ReminderSound.allCases, id: \.self) { sound in
                                Text(sound.displayName).tag(sound)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                }
            }
            .navigationTitle("编辑日程")
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
                    HStack {
                        if isUnifiedSchedule {
                            Button(role: .destructive) {
                                showUnifiedDeleteAlert = true
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                        Button("保存") {
                            updateSchedule()
                        }
                        .disabled(title.isEmpty || (isMultiDay && selectedWeekdays.isEmpty))
                    }
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    HStack {
                        if isUnifiedSchedule {
                            Button(role: .destructive) {
                                showUnifiedDeleteAlert = true
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                        Button("保存") {
                            updateSchedule()
                        }
                        .disabled(title.isEmpty || (isMultiDay && selectedWeekdays.isEmpty))
                    }
                }
                #endif
            }
            .onTapGesture {
                hideKeyboard()
            }
            .sheet(isPresented: $isShowingSoundSelection) {
                SoundSelectionView(
                    selectedSound: $reminderSound,
                    customSoundURL: $customSoundURL
                )
            }
            .sheet(isPresented: $showCitySelection) {
                CitySelectionView(selectedCity: $selectedCity)
            }
            .alert("统一修改日程", isPresented: $showUnifiedScheduleAlert) {
                Button("仅修改当前") {
                    updateSingleScheduleDirectly()
                    dismiss()
                }
                Button("统一修改全部") {
                    updateUnifiedSchedules()
                    dismiss()
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text("发现 \(unifiedScheduleCount) 个相同名称和时间的日程。您希望如何处理？")
            }
            .alert("统一删除日程", isPresented: $showUnifiedDeleteAlert) {
                Button("仅删除当前") {
                    scheduleStore.deleteSchedules(with: [scheduleItem.id])
                    dismiss()
                }
                Button("统一删除全部", role: .destructive) {
                    scheduleStore.deleteUnifiedSchedules(for: scheduleItem)
                    dismiss()
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text("发现 \(unifiedScheduleCount) 个相同名称和时间的日程。您希望如何处理？")
            }
        }
    }
    
    private func updateSchedule() {
        // 检查是否为统一日程，如果是则显示选择对话框
        if isUnifiedSchedule {
            showUnifiedScheduleAlert = true
            return
        }
        
        // 原有的单个日程更新逻辑
        updateSingleScheduleDirectly()
        dismiss()
    }
    

    
    // 检查是否有重大变化需要重新创建重复日程系列
    private func hasSignificantChanges() -> Bool {
        // 检查重复日期是否发生变化
        if scheduleItem.recurringWeekdays != Array(selectedWeekdays) {
            return true
        }
        
        // 检查日期范围是否发生变化
        if let originalStart = scheduleItem.recurringStartDate,
           let originalEnd = scheduleItem.recurringEndDate {
            if !Calendar.current.isDate(originalStart, inSameDayAs: scheduleDate) ||
               !Calendar.current.isDate(originalEnd, inSameDayAs: endDate) {
                return true
            }
        }
        
        return false
    }
    
    // 批量更新现有重复日程系列
    private func updateRecurringScheduleSeries() {
        let parentId = scheduleItem.parentId ?? scheduleItem.id
        let relatedSchedules = scheduleStore.scheduleItems.filter { 
            $0.parentId == parentId || $0.id == parentId 
        }
        
        for schedule in relatedSchedules {
            var updatedSchedule = schedule
            updatedSchedule.title = title
            updatedSchedule.notes = notes
            updatedSchedule.category = category
            updatedSchedule.priority = priority
            
            // 保持原有的日期，只更新时间
            let calendar = Calendar.current
            let newStartTime = calendar.date(
                bySettingHour: calendar.component(.hour, from: startTime),
                minute: calendar.component(.minute, from: startTime),
                second: 0,
                of: schedule.startTime
            ) ?? schedule.startTime
            
            let newEndTime = calendar.date(
                bySettingHour: calendar.component(.hour, from: endTime),
                minute: calendar.component(.minute, from: endTime),
                second: 0,
                of: schedule.startTime
            ) ?? schedule.endTime
            
            updatedSchedule.startTime = newStartTime
            updatedSchedule.endTime = newEndTime
            
            // 更新提醒设置
            updatedSchedule.hasReminder = hasReminder
            if hasReminder {
                updatedSchedule.reminderMinutesBefore = reminderMinutesBefore
                updatedSchedule.reminderSound = reminderSound
                updatedSchedule.customSoundURL = customSoundURL
            }
            
            scheduleStore.updateSchedule(updatedSchedule)
        }
    }
    
    // 处理单天日程的日期变化
    private func updateSingleScheduleWithDateChange() {
        let calendar = Calendar.current
        
        // 计算时间差，保持相对时间不变
        let _ = calendar.startOfDay(for: scheduleItem.startTime)
        let newDate = calendar.startOfDay(for: scheduleDate)
        
        let startTimeComponents = calendar.dateComponents([.hour, .minute], from: scheduleItem.startTime)
        let endTimeComponents = calendar.dateComponents([.hour, .minute], from: scheduleItem.endTime)
        
        let newStartTime = calendar.date(bySettingHour: startTimeComponents.hour ?? 0,
                                       minute: startTimeComponents.minute ?? 0,
                                       second: 0,
                                       of: newDate) ?? scheduleDate
        
        let newEndTime = calendar.date(bySettingHour: endTimeComponents.hour ?? 0,
                                     minute: endTimeComponents.minute ?? 0,
                                     second: 0,
                                     of: newDate) ?? scheduleDate
        
        var updatedItem = scheduleItem
        updatedItem.title = title
        updatedItem.notes = notes
        updatedItem.category = category
        updatedItem.priority = priority
        updatedItem.startTime = newStartTime
        updatedItem.endTime = newEndTime
        
        // 设置提醒
        updatedItem.hasReminder = hasReminder
        if hasReminder {
            updatedItem.reminderTime = nil
            updatedItem.reminderMinutesBefore = reminderMinutesBefore
            updatedItem.reminderSound = reminderSound
            updatedItem.customSoundURL = customSoundURL
        } else {
            updatedItem.reminderTime = nil
            updatedItem.reminderMinutesBefore = 0
            updatedItem.reminderSound = ReminderSound.defaultSound
            updatedItem.customSoundURL = nil
        }
        
        scheduleStore.updateSchedule(updatedItem)
    }
    
    private func updateUnifiedSchedules() {
        // 创建更新后的日程模板
        var updatedSchedule = ScheduleItem(
            title: title,
            notes: notes,
            category: category,
            priority: priority,
            startTime: scheduleItem.startTime, // 保持原始时间，统一修改方法会处理
            endTime: scheduleItem.endTime,
            isCompleted: scheduleItem.isCompleted
        )
        
        // 设置其他属性
        updatedSchedule.id = scheduleItem.id
        updatedSchedule.hasReminder = hasReminder
        updatedSchedule.reminderMinutesBefore = hasReminder ? reminderMinutesBefore : 0
        updatedSchedule.reminderSound = hasReminder ? reminderSound : ReminderSound.defaultSound
        updatedSchedule.customSoundURL = hasReminder ? customSoundURL : nil
        updatedSchedule.parentId = scheduleItem.parentId
        
        // 调用统一修改方法
        scheduleStore.updateUnifiedSchedules(updatedSchedule)
    }
    
    private func createRecurringScheduleSeries() {
        let calendar = Calendar.current
        let parentId = scheduleItem.parentId ?? scheduleItem.id
        var currentDate = scheduleDate
        
        while currentDate <= endDate {
            let weekday = calendar.component(.weekday, from: currentDate)
            
            if selectedWeekdays.contains(weekday) {
                let startDateTime = calendar.date(
                    bySettingHour: calendar.component(.hour, from: startTime),
                    minute: calendar.component(.minute, from: startTime),
                    second: 0,
                    of: currentDate
                ) ?? currentDate
                
                let endDateTime = calendar.date(
                    bySettingHour: calendar.component(.hour, from: endTime),
                    minute: calendar.component(.minute, from: endTime),
                    second: 0,
                    of: currentDate
                ) ?? currentDate
                
                var newItem = ScheduleItem(
                    title: title,
                    notes: notes,
                    category: category,
                    priority: priority,
                    startTime: startDateTime,
                    endTime: endDateTime,
                    isCompleted: false
                )
                
                // 设置重复日程属性
                newItem.isRecurring = true
                newItem.recurringStartDate = scheduleDate
                newItem.recurringEndDate = endDate
                newItem.recurringWeekdays = Array(selectedWeekdays)
                newItem.parentId = parentId
                
                // 设置提醒
                newItem.hasReminder = hasReminder
                if hasReminder {
                    newItem.reminderMinutesBefore = reminderMinutesBefore
                    newItem.reminderSound = reminderSound
                    newItem.customSoundURL = customSoundURL
                }
                
                scheduleStore.addSchedule(newItem)
            }
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
    }
    
    private func createSingleSchedule() {
        let calendar = Calendar.current
        let startDateTime = calendar.date(
            bySettingHour: calendar.component(.hour, from: startTime),
            minute: calendar.component(.minute, from: startTime),
            second: 0,
            of: scheduleDate
        ) ?? scheduleDate
        
        let endDateTime = calendar.date(
            bySettingHour: calendar.component(.hour, from: endTime),
            minute: calendar.component(.minute, from: endTime),
            second: 0,
            of: scheduleDate
        ) ?? scheduleDate
        
        var newItem = ScheduleItem(
            title: title,
            notes: notes,
            category: category,
            priority: priority,
            startTime: startDateTime,
            endTime: endDateTime,
            isCompleted: false,
            city: selectedCity.isEmpty ? nil : selectedCity
        )
        
        // 设置提醒
        newItem.hasReminder = hasReminder
        if hasReminder {
            newItem.reminderMinutesBefore = reminderMinutesBefore
            newItem.reminderSound = reminderSound
            newItem.customSoundURL = customSoundURL
        }
        
        scheduleStore.addSchedule(newItem)
    }
    
    private func updateSingleScheduleDirectly() {
        let calendar = Calendar.current
        let startDateTime = calendar.date(
            bySettingHour: calendar.component(.hour, from: startTime),
            minute: calendar.component(.minute, from: startTime),
            second: 0,
            of: scheduleDate
        ) ?? scheduleDate
        
        let endDateTime = calendar.date(
            bySettingHour: calendar.component(.hour, from: endTime),
            minute: calendar.component(.minute, from: endTime),
            second: 0,
            of: scheduleDate
        ) ?? scheduleDate
        
        var updatedItem = scheduleItem
        updatedItem.title = title
        updatedItem.notes = notes
        updatedItem.category = category
        updatedItem.priority = priority
        updatedItem.startTime = startDateTime
        updatedItem.endTime = endDateTime
        updatedItem.city = selectedCity.isEmpty ? nil : selectedCity
        
        // 设置提醒
        updatedItem.hasReminder = hasReminder
        if hasReminder {
            updatedItem.reminderMinutesBefore = reminderMinutesBefore
            updatedItem.reminderSound = reminderSound
            updatedItem.customSoundURL = customSoundURL
        }
        
        scheduleStore.updateSchedule(updatedItem)
    }
    
    private func hideKeyboard() {
        #if os(iOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #else
        // macOS doesn't need this functionality as keyboard handling is different
        #endif
    }
}

#Preview {
    let sampleItem = ScheduleItem(
        title: "示例日程",
        notes: "这是一个示例日程",
        category: .work,
        priority: .medium,
        startTime: Date(),
        endTime: Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date(),
        isCompleted: false
    )
    
    EditScheduleView(scheduleItem: sampleItem, scheduleStore: ScheduleStore.shared)
}