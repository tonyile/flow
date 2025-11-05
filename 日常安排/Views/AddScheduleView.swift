import SwiftUI
import AVFoundation
import AudioToolbox
import Foundation

struct AddScheduleView: View {
    @ObservedObject var scheduleStore: ScheduleStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var category: ScheduleCategory = .work
    @State private var priority: SchedulePriority = .medium
    
    // 分离的日期和时间状态
    @State private var scheduleDate: Date
    @State private var startTime: Date
    @State private var endTime: Date
    
    // 日期范围相关状态
    @State private var isMultiDay: Bool = false
    @State private var endDate: Date
    
    // 重复日程相关状态 - 多天选择时自动启用
    @State private var selectedWeekdays: Set<Int> = []
    
    // 忆年相关状态
    @State private var isFestival: Bool = false
    @State private var festivalType: FestivalType = .solar
    @State private var isYearlyRecurring: Bool = false
    
    // 提醒相关状态
    @State private var hasReminder: Bool = true
    @State private var reminderMinutesBefore: Int = 15
    @State private var reminderSound: ReminderSound = .defaultSound
    @State private var customSoundURL: URL?
    @State private var isShowingSoundSelection = false
    @State private var audioPlayer: AVAudioPlayer?
    

    
    // 城市选择相关状态
    @State private var selectedCity: String = ""
    @State private var isShowingCitySelection = false
    @ObservedObject private var weatherManager = WeatherManager.shared
    
    @State private var showingErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    @State private var isSaving: Bool = false
    
    // 重新排列的周选择 - 周一到周日
    // 日期格式化器
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
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
    
    private let weekdays = [
        (2, "周一"), (3, "周二"), (4, "周三"), (5, "周四"),
        (6, "周五"), (7, "周六"), (1, "周日")
    ]
    
    private let reminderOptions = [
        (5, "5分钟前"),
        (15, "15分钟前"),
        (30, "30分钟前"),
        (60, "1小时前"),
        (120, "2小时前"),
        (1440, "1天前")
    ]
    
    private let soundOptions = [
        ("default", "默认"),
        ("bell", "铃声"),
        ("chime", "钟声"),
        ("ding", "叮咚"),
        ("note", "音符"),
        ("ping", "提示音"),
        ("pop", "弹出音"),
        ("tweet", "鸟鸣")
    ]
    
    init(scheduleStore: ScheduleStore, baseDate: Date = Date()) {
        self.scheduleStore = scheduleStore
        self._scheduleDate = State(initialValue: baseDate)
        self._startTime = State(initialValue: baseDate)
        self._endTime = State(initialValue: Calendar.current.date(byAdding: .hour, value: 1, to: baseDate) ?? baseDate)
        self._endDate = State(initialValue: baseDate)
        
        // 尝试获取当前位置的城市名称作为默认值
        if let currentCityName = WeatherManager.shared.currentCityName {
            self._selectedCity = State(initialValue: currentCityName)
        } else {
            self._selectedCity = State(initialValue: "")
        }
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
                    .onChange(of: category) { _, newValue in
                        isFestival = (newValue == .festival)
                    }
                    
                    if isFestival {
                        Toggle("年度重复", isOn: $isYearlyRecurring)
                        
                        if isYearlyRecurring {
                            Picker("周年类型", selection: $festivalType) {
                                ForEach(FestivalType.allCases.filter { $0 != .solarTerm }) { type in
                                    Text(type.label).tag(type)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
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
                }
                
                Section(header: Text("城市选择")) {
                    Button(action: {
                        isShowingCitySelection = true
                    }) {
                        HStack {
                            Image(systemName: "location")
                                .foregroundColor(.blue)
                            Text("城市")
                            Spacer()
                            Text(selectedCity)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.primary)
                }

                Section(header: Text("日期范围")) {
                    DatePicker("开始日期", selection: $scheduleDate, displayedComponents: .date)
                        .onChange(of: scheduleDate) { _, newValue in
                            // 如果是多天日程且非忆年，自动更新选择的星期
                            if isMultiDay && !isFestival {
                                let calendar = Calendar.current
                                let weekday = calendar.component(.weekday, from: newValue)
                                selectedWeekdays.removeAll()
                                selectedWeekdays.insert(weekday)
                            }
                        }
                    
                    if !isFestival {
                        Toggle("多天日程", isOn: $isMultiDay)
                            .onChange(of: isMultiDay) { _, newValue in
                                if newValue {
                                    // 启用多天日程时，自动选择开始日期对应的星期
                                    let calendar = Calendar.current
                                    let weekday = calendar.component(.weekday, from: scheduleDate)
                                    selectedWeekdays.insert(weekday)
                                } else {
                                    // 禁用多天日程时，清空选择的星期
                                    selectedWeekdays.removeAll()
                                }
                            }
                        
                        if isMultiDay {
                            DatePicker("结束日期", selection: $endDate, displayedComponents: .date)
                                .onChange(of: endDate) { _, newValue in
                                    // 确保结束日期不早于开始日期
                                    if newValue < scheduleDate {
                                        endDate = scheduleDate
                                    }
                                }
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
                
                // 重复日期选择 - 仅在多天日程且非忆年时显示
                if isMultiDay && !isFestival {
                    Section(header: Text("重复日期")) {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                            ForEach(weekdays, id: \.0) { weekday in
                                Button(action: {
                                    if selectedWeekdays.contains(weekday.0) {
                                        selectedWeekdays.remove(weekday.0)
                                    } else {
                                        selectedWeekdays.insert(weekday.0)
                                    }
                                }) {
                                    Text(weekday.1)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(selectedWeekdays.contains(weekday.0) ? Color.blue : Color.gray.opacity(0.2))
                                        .foregroundColor(selectedWeekdays.contains(weekday.0) ? .white : .primary)
                                        .cornerRadius(16)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.vertical, 8)
                        
                        if selectedWeekdays.isEmpty && isMultiDay && !isFestival {
                            Text("请至少选择一个重复日期")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                
                // 忆年期间显示
                if isFestival && isYearlyRecurring {
                    Section(header: Text("周年期间")) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("周年期间内所有天数将自动包含")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            // 显示农历时间信息
                            if festivalType == .lunar {
                                let lunarInfo = ChineseLunarCalendar.shared.getLunarInfo(for: scheduleDate)
                                HStack {
                                    Image(systemName: "moon.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption2)
                                    Text("农历时间：\(lunarInfo.month)\(lunarInfo.day)")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                }
                            } else {
                                HStack {
                                    Image(systemName: "sun.max.fill")
                                        .foregroundColor(.blue)
                                        .font(.caption2)
                                    Text("阳历时间：\(scheduleDate, formatter: dateFormatter)")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // 提醒设置
                Section(header: Text("提醒设置")) {
                    Toggle("启用提醒", isOn: $hasReminder)
                    
                    if hasReminder {
                        Picker("提前提醒", selection: $reminderMinutesBefore) {
                            ForEach([5, 10, 15, 30, 60], id: \.self) { minutes in
                                Text("\(minutes)分钟").tag(minutes)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        
                        Button(action: {
                            isShowingSoundSelection = true
                        }) {
                            HStack {
                                Image(systemName: "bell")
                                    .foregroundColor(.blue)
                                Text("提醒音")
                                Spacer()
                                Text(reminderSound.displayName)
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle("添加日程")
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
                    Button("保存") {
                        saveSchedule()
                    }
                    .disabled(title.isEmpty || (isMultiDay && selectedWeekdays.isEmpty && !isFestival) || isSaving)
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveSchedule()
                    }
                    .disabled(title.isEmpty || (isMultiDay && selectedWeekdays.isEmpty && !isFestival) || isSaving)
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
            .sheet(isPresented: $isShowingCitySelection) {
                CitySelectionView(selectedCity: $selectedCity)
            }
            .alert("保存失败", isPresented: $showingErrorAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // 隐藏键盘的辅助方法
    private func hideKeyboard() {
        #if os(iOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
    
    private func saveSchedule() {
        // 防止重复保存
        guard !isSaving else { return }
        
        // 验证输入
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showError("请输入日程标题")
            return
        }
        
        if isMultiDay && selectedWeekdays.isEmpty && !isFestival {
            showError("多天日程请至少选择一个重复日期")
            return
        }
        
        // 验证时间设置
        if endTime < startTime {
            showError("结束时间不能早于开始时间")
            return
        }
        
        isSaving = true
        
        do {
            if isFestival && isYearlyRecurring {
                try saveFestivalSchedule()
            } else if isMultiDay && !selectedWeekdays.isEmpty {
                try saveMultiDaySchedule()
            } else {
                try saveSingleSchedule()
            }
            
            dismiss()
        } catch {
            showError("保存失败: \(error.localizedDescription)")
        }
        
        isSaving = false
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingErrorAlert = true
        isSaving = false
    }
    
    private func saveMultiDaySchedule() throws {
        // 创建重复日程
        let parentId = UUID()
        let calendar = Calendar.current
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
                
                var item = ScheduleItem(
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                    category: category,
                    priority: priority,
                    startTime: startDateTime,
                    endTime: endDateTime,
                    isCompleted: false,
                    city: selectedCity.isEmpty ? nil : selectedCity
                )
                
                // 设置重复日程属性
                item.isRecurring = true
                item.recurringStartDate = scheduleDate
                item.recurringEndDate = endDate
                item.recurringWeekdays = Array(selectedWeekdays)
                item.parentId = parentId
                
                scheduleStore.addSchedule(item)
            }
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
    }
    
    private func saveSingleSchedule() throws {
        // 创建单次日程
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
        
        var item = ScheduleItem(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            priority: priority,
            startTime: startDateTime,
            endTime: endDateTime,
            isCompleted: false,
            city: selectedCity.isEmpty ? nil : selectedCity
        )
        
        // 设置忆年相关属性
        item.isFestival = isFestival
        item.festivalType = festivalType
        item.isYearlyRecurring = isYearlyRecurring
        
        // 设置提醒
        item.hasReminder = hasReminder
        if hasReminder {
            item.reminderMinutesBefore = reminderMinutesBefore
            item.reminderSound = reminderSound
            item.customSoundURL = customSoundURL
        }
        
        scheduleStore.addSchedule(item)
    }
    
    private func saveFestivalSchedule() throws {
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
        
        // 获取选中日期的忆年信息（如果存在）
        let festivals = ChineseFestivalManager.shared.getFestivals(for: scheduleDate)
        let selectedFestival = festivals.first
        
        // 如果没有找到预定义的忆年，创建一个默认的忆年信息
        let festivalDuration = selectedFestival?.duration ?? 1 // 默认持续1天
        
        // 为未来几年创建忆年日程（默认15年）
        let currentYear = calendar.component(.year, from: Date())
        let selectedMonth = calendar.component(.month, from: scheduleDate)
        let selectedDay = calendar.component(.day, from: scheduleDate)
        
        var successCount = 0
        var failureCount = 0
        
        for yearOffset in 0..<15 {
            let targetYear = currentYear + yearOffset
            
            // 根据忆年类型计算日期
            var targetDate: Date?
            
            if festivalType == .solar {
                // 阳历忆年：直接使用月日
                targetDate = calendar.date(from: DateComponents(year: targetYear, month: selectedMonth, day: selectedDay))
            } else {
                // 农历忆年：获取用户选择日期对应的农历信息
                let lunarInfo = ChineseLunarCalendar.shared.getLunarInfo(for: scheduleDate)
                let lunarMonth = getLunarMonthNumber(from: lunarInfo.month)
                let lunarDay = getLunarDayNumber(from: lunarInfo.day)
                
                // 验证农历转换参数
                guard lunarMonth > 0 && lunarMonth <= 12,
                      lunarDay > 0 && lunarDay <= 30 else {
                    print("❌ 农历参数无效: 月份=\(lunarMonth), 日期=\(lunarDay)")
                    failureCount += 1
                    continue
                }
                
                // 对于当前年份，如果是今天或之前的日期，直接使用选择的日期
                if yearOffset == 0 && calendar.isDate(scheduleDate, inSameDayAs: Date()) {
                    targetDate = scheduleDate
                    print("🌙 使用当天选择的日期: \(scheduleDate)")
                } else {
                    // 使用农历转阳历的方法获取目标年份的阳历日期
                    targetDate = ChineseLunarCalendar.shared.lunarToSolar(
                        year: targetYear, 
                        month: lunarMonth, 
                        day: lunarDay, 
                        isLeapMonth: lunarInfo.isLeapMonth
                    )
                }
                
                if targetDate == nil {
                    print("❌ 农历转换失败: \(targetYear)年农历\(lunarMonth)月\(lunarDay)日")
                    failureCount += 1
                    continue
                }
            }
            
            guard let validTargetDate = targetDate else { 
                failureCount += 1
                continue 
            }
            
            // 为忆年期间的每一天创建日程
            for dayOffset in 0..<festivalDuration {
                guard let festivalDay = calendar.date(byAdding: .day, value: dayOffset, to: validTargetDate) else { continue }
                
                let yearlyStartDateTime = calendar.date(
                    bySettingHour: calendar.component(.hour, from: startDateTime),
                    minute: calendar.component(.minute, from: startDateTime),
                    second: 0,
                    of: festivalDay
                ) ?? festivalDay
                
                let yearlyEndDateTime = calendar.date(
                    bySettingHour: calendar.component(.hour, from: endDateTime),
                    minute: calendar.component(.minute, from: endDateTime),
                    second: 0,
                    of: festivalDay
                ) ?? festivalDay
                
                var item = ScheduleItem(
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                    category: category,
                    priority: priority,
                    startTime: yearlyStartDateTime,
                    endTime: yearlyEndDateTime,
                    isCompleted: false,
                    city: selectedCity.isEmpty ? nil : selectedCity
                )
                
                // 设置提醒
                item.hasReminder = hasReminder
                if hasReminder {
                    item.reminderMinutesBefore = reminderMinutesBefore
                    item.reminderSound = reminderSound
                    item.customSoundURL = customSoundURL
                }
                
                // 设置忆年相关属性
                item.isFestival = true
                item.festivalType = festivalType
                item.isYearlyRecurring = true
                // 不设置isRecurring，因为忆年日程是直接创建多个独立的日程项，而不是重复日程系列
                
                print("🌙 创建农历忆年日程: \(item.title) - \(item.startTime) - isFestival: \(item.isFestival)")
                
                scheduleStore.addSchedule(item)
                successCount += 1
            }
        }
        
        // 检查是否有成功创建的日程
        if successCount == 0 {
            if festivalType == .lunar {
                throw NSError(domain: "FestivalScheduleError", code: 1001, userInfo: [
                    NSLocalizedDescriptionKey: "农历忆年日程创建失败。请检查选择的日期是否为有效的农历日期。"
                ])
            } else {
                throw NSError(domain: "FestivalScheduleError", code: 1002, userInfo: [
                    NSLocalizedDescriptionKey: "忆年日程创建失败。请检查日期设置。"
                ])
            }
        }
        
        print("✅ 忆年日程创建完成: 成功\(successCount)个，失败\(failureCount)个")
    }
}
