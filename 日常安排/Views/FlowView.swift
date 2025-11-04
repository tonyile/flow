import SwiftUI

struct FlowView: View {
    @ObservedObject private var flowStore = FlowStore.shared
    @StateObject private var weatherManager = WeatherManager()
    @EnvironmentObject var colorSchemeManager: ColorSchemeManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingAddFlow = false
    @State private var selectedFlowItem: FlowItem?
    @State private var searchText = ""
    @State private var selectedType: FlowType? = nil
    @State private var selectedDateRange: DateRange = .all
    @State private var showingFilterSheet = false
    
    enum DateRange: String, CaseIterable {
        case all = "全部"
        case today = "今天"
        case thisWeek = "本周"
        case thisMonth = "本月"
        case thisYear = "今年"
    }
    
    var filteredFlowItems: [FlowItem] {
        var items = flowStore.flowItems
        
        // 搜索过滤
        if !searchText.isEmpty {
            items = flowStore.searchFlowItems(searchText)
        }
        
        // 类型过滤
        if let type = selectedType {
            items = items.filter { $0.type == type }
        }
        
        // 日期范围过滤
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedDateRange {
        case .all:
            break
        case .today:
            items = items.filter { calendar.isDate($0.date, inSameDayAs: now) }
        case .thisWeek:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let endOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.end ?? now
            items = items.filter { $0.date >= startOfWeek && $0.date <= endOfWeek }
        case .thisMonth:
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            let endOfMonth = calendar.dateInterval(of: .month, for: now)?.end ?? now
            items = items.filter { $0.date >= startOfMonth && $0.date <= endOfMonth }
        case .thisYear:
            let startOfYear = calendar.dateInterval(of: .year, for: now)?.start ?? now
            let endOfYear = calendar.dateInterval(of: .year, for: now)?.end ?? now
            items = items.filter { $0.date >= startOfYear && $0.date <= endOfYear }
        }
        
        return items.sorted { $0.date > $1.date }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索栏
                FlowSearchBar(text: $searchText)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                // 筛选栏
                FilterBar(
                    selectedType: $selectedType,
                    selectedDateRange: $selectedDateRange,
                    showingFilterSheet: $showingFilterSheet
                )
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                // 流水列表
                if filteredFlowItems.isEmpty {
                    EmptyFlowView()
                } else {
                    List {
                        ForEach(groupedFlowItems, id: \.key) { dateGroup in
                            Section(header: DateSectionHeader(date: dateGroup.key)) {
                                ForEach(dateGroup.value) { item in
                                    FlowItemRow(item: item)
                                        .onTapGesture {
                                            selectedFlowItem = item
                                        }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button("删除", role: .destructive) {
                                                flowStore.deleteItem(item)
                                            }
                                            
                                            Button("编辑") {
                                                selectedFlowItem = item
                                            }
                                            .tint(.blue)
                                        }
                                }
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                    .safeAreaInset(edge: .bottom) {
                        // 导航栏高度：12(vertical padding) + 32(button height) + 16(bottom padding) + 安全区域 ≈ 80-100
                        Color.clear.frame(height: 100)
                    }
                }
                
                Spacer()
            }
            .navigationTitle("")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("日常流水")
                        .font(.system(.title2, design: .default, weight: .semibold))
                        .foregroundColor(.primary)
                }
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    AnimatedPlusButton {
                        showingAddFlow = true
                    }
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    AnimatedPlusButton {
                        showingAddFlow = true
                    }
                }
                #endif
            }
            .sheet(isPresented: $showingAddFlow) {
                AddFlowView()
            }
            .sheet(item: $selectedFlowItem) { item in
                EditFlowView(flowItem: item)
            }
            .sheet(isPresented: $showingFilterSheet) {
                FilterSheetView(
                    selectedType: $selectedType,
                    selectedDateRange: $selectedDateRange
                )
            }
        }
        .alert("错误", isPresented: .constant(flowStore.errorMessage != nil)) {
            Button("确定") {
                flowStore.clearError()
            }
        } message: {
            Text(flowStore.errorMessage ?? "")
        }
        .onAppear {
            weatherManager.fetchWeather()
        }
        .onChange(of: colorScheme) { newScheme in
            colorSchemeManager.updateColors(for: newScheme)
        }
        .id(colorScheme)
    }
    
    @ViewBuilder
    private var flowTitleView: some View {
        let currentDate = Date()
        let lunarInfo = ChineseLunarCalendar.shared.getLunarInfo(for: currentDate)
        let festival = ChineseFestivalManager.shared.getPrimaryFestival(for: currentDate)
        let baseTitle = dayFormatter.string(from: currentDate)
        let lunarTitle = "\(lunarInfo.month)\(lunarInfo.day)"
        
        HStack(spacing: 4) {
            // 日期
            Text(baseTitle)
                .font(.system(.title3, design: .default, weight: .semibold))
                .foregroundColor(.primary)
            
            // 农历
            Text(lunarTitle)
                .font(.system(.caption2, design: .default, weight: .medium))
                .foregroundColor(.secondary)
            
            // 忆年标签
            if let festival = festival {
                Text(festival.name)
                    .font(.system(.caption2, design: .default, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(festivalTextColor(for: festival.type, festivalName: festival.name))
                    )
            }
            
            // 天气显示
            WeatherDisplayView(date: currentDate, weatherManager: weatherManager, isCompact: true)
        }
        .minimumScaleFactor(0.5)
        .lineLimit(1)
        .allowsTightening(true)
        .truncationMode(.tail)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
    
    private var dayFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "M月d日"
        df.locale = Locale(identifier: "zh_CN")
        return df
    }
    
    private func festivalTextColor(for type: ChineseFestivalType, festivalName: String = "") -> Color {
        switch type {
        case .lunar:
            return .orange
        case .solar:
            let legalHolidays = ["元旦", "劳动节", "国庆节"]
            if legalHolidays.contains(festivalName) {
                return .red
            } else {
                return .blue
            }
        case .solarTerm:
            return .green
        }
    }
    
    private var groupedFlowItems: [(key: Date, value: [FlowItem])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredFlowItems) { item in
            calendar.startOfDay(for: item.date)
        }
        return grouped.sorted { $0.key > $1.key }
    }
}

// MARK: - 搜索栏
struct FlowSearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("搜索流水记录", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if !text.isEmpty {
                Button("清除") {
                    text = ""
                }
                .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - 筛选栏
struct FilterBar: View {
    @Binding var selectedType: FlowType?
    @Binding var selectedDateRange: FlowView.DateRange
    @Binding var showingFilterSheet: Bool
    
    var body: some View {
        HStack {
            // 类型筛选
            Menu {
                Button("全部类型") {
                    selectedType = nil
                }
                
                ForEach(FlowType.allCases, id: \.self) { type in
                    Button(type.displayName) {
                        selectedType = type
                    }
                }
            } label: {
                HStack {
                    Text(selectedType?.displayName ?? "全部类型")
                    Image(systemName: "chevron.down")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
            
            Spacer()
            
            // 日期范围筛选
            Menu {
                ForEach(FlowView.DateRange.allCases, id: \.self) { range in
                    Button(range.rawValue) {
                        selectedDateRange = range
                    }
                }
            } label: {
                HStack {
                    Text(selectedDateRange.rawValue)
                    Image(systemName: "chevron.down")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
}

// MARK: - 日期分组标题
struct DateSectionHeader: View {
    let date: Date
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "今天 M月d日"
        } else if calendar.isDateInYesterday(date) {
            formatter.dateFormat = "昨天 M月d日"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
            formatter.dateFormat = "M月d日 EEEE"
        } else {
            formatter.dateFormat = "yyyy年M月d日 EEEE"
        }
        
        return formatter
    }
    
    var body: some View {
        Text(dateFormatter.string(from: date))
            .font(.system(.subheadline, design: .default, weight: .medium))
            .foregroundColor(.secondary)
            .padding(.vertical, 4)
    }
}

// MARK: - 流水项目行
struct FlowItemRow: View {
    let item: FlowItem
    
    var body: some View {
        HStack(spacing: 12) {
            // 图标
            Image(systemName: item.type.icon)
                .font(.title2)
                .foregroundColor(item.type.color)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                // 标题
                Text(item.title)
                    .font(.system(.body, design: .default, weight: .medium))
                    .lineLimit(1)
                
                // 详细信息
                HStack {
                    if let amount = item.amount, amount != 0 {
                        Text("\(item.type.amountPrefix)\(amount, specifier: "%.2f") \(item.currency)")
                            .font(.caption)
                            .foregroundColor(item.type.amountColor)
                    }
                    
                    if !item.relatedPeople.isEmpty {
                        Text("👤 \(item.relatedPeople.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                // 相关物品和标签
                if !item.relatedItems.isEmpty || !item.tags.isEmpty {
                    HStack {
                        if !item.relatedItems.isEmpty {
                            Text("📦 \(item.relatedItems.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        if !item.tags.isEmpty {
                            Text("#\(item.tags.joined(separator: " #"))")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .lineLimit(1)
                        }
                    }
                }
            }
            
            Spacer()
            
            // 时间
            VStack(alignment: .trailing) {
                Text(timeFormatter.string(from: item.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }
}

// MARK: - 空状态视图
struct EmptyFlowView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("暂无流水记录")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("点击右上角的 + 按钮添加第一条流水记录")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - 筛选表单视图
struct FilterSheetView: View {
    @Binding var selectedType: FlowType?
    @Binding var selectedDateRange: FlowView.DateRange
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("类型筛选") {
                    Picker("类型", selection: $selectedType) {
                        Text("全部类型").tag(nil as FlowType?)
                        ForEach(FlowType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type as FlowType?)
                        }
                    }
                    #if os(iOS)
                    .pickerStyle(WheelPickerStyle())
                    #else
                    .pickerStyle(.menu)
                    #endif
                }
                
                Section("日期范围") {
                    Picker("日期范围", selection: $selectedDateRange) {
                        ForEach(FlowView.DateRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    #if os(iOS)
                    .pickerStyle(WheelPickerStyle())
                    #else
                    .pickerStyle(.menu)
                    #endif
                }
                
                Section("日期范围") {
                    Picker("日期范围", selection: $selectedDateRange) {
                        ForEach(FlowView.DateRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    #if os(iOS)
                    .pickerStyle(WheelPickerStyle())
                    #else
                    .pickerStyle(.menu)
                    #endif
                }
            }
            .navigationTitle("筛选条件")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
                #endif
            }
        }
    }
}

#Preview {
    FlowView()
}