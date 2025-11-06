import SwiftUI
import Foundation

struct DateDetailView: View {
    @ObservedObject var scheduleStore: ScheduleStore
    let selectedDate: Date
    @Environment(\.dismiss) private var dismiss
    @State private var showAdd: Bool = false
    @StateObject private var weatherManager = WeatherManager.shared
    @State private var showingDeleteAlert = false
    @State private var scheduleToDelete: ScheduleItem?
    @State private var deleteType: DeleteType = .single
    @State private var editingItem: ScheduleItem?
    
    enum DeleteType {
        case single
        case allRepeating
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: -8) {
                content
            }
            .navigationTitle("")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("返回") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .principal) {
                    customTitleView
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    AnimatedPlusButton {
                        showAdd = true
                    }
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("返回") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .principal) {
                    customTitleView
                }
                ToolbarItem(placement: .primaryAction) {
                    AnimatedPlusButton {
                        showAdd = true
                    }
                }
                #endif
            }
        }
        .sheet(isPresented: $showAdd) {
            AddScheduleView(scheduleStore: scheduleStore, baseDate: selectedDate)
        }
        .fullScreenCover(item: $editingItem) { editingItem in
            EditScheduleView(scheduleItem: editingItem, scheduleStore: scheduleStore)
        }
        .alert("删除日程", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                if let schedule = scheduleToDelete {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        switch deleteType {
                        case .single:
                            if schedule.isRecurring {
                                scheduleStore.deleteSingleSchedule(with: schedule.id)
                            } else {
                                scheduleStore.deleteSchedules(with: [schedule.id])
                            }
                        case .allRepeating:
                            scheduleStore.deleteAllRepeatingSchedules(with: schedule.id)
                        }
                    }
                }
                // 清理状态
                scheduleToDelete = nil
            }
        } message: {
            if let schedule = scheduleToDelete {
                 switch deleteType {
                 case .single:
                     Text("确定要删除\"\(schedule.title)\"\(schedule.isRecurring ? "（仅此日）" : "")吗？")
                 case .allRepeating:
                     Text("确定要删除\"\(schedule.title)\"的所有重复日程吗？")
                 }
             } else {
                Text("确定要删除这个日程吗？")
            }
        }
        .onAppear {
            weatherManager.fetchWeather()
        }

    }
    
    @ViewBuilder
    private var customTitleView: some View {
        let lunarInfo = ChineseLunarCalendar.shared.getLunarInfo(for: selectedDate)
        let festival = ChineseFestivalManager.shared.getPrimaryFestival(for: selectedDate)
        let isToday = Calendar.current.isDateInToday(selectedDate)
        let baseTitle = isToday ? todayFormatter.string(from: selectedDate) : dayFormatter.string(from: selectedDate)
        let lunarTitle = "\(lunarInfo.month)\(lunarInfo.day)"
        
        HStack(spacing: 4) {
            // 主日期显示
            Text(baseTitle)
                .font(.system(isToday ? .title : .title2, design: .default, weight: isToday ? .bold : .semibold))
                .foregroundColor(isToday ? .black : .primary)
                .padding(.horizontal, isToday ? 8 : 0)
                .padding(.vertical, isToday ? 4 : 0)
                .background(
                    isToday ? 
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .shadow(color: .gray.opacity(0.3), radius: 2, x: 0, y: 1)
                    : nil
                )
            
            // 农历信息
            Text(lunarTitle)
                .font(.system(.caption2, design: .default, weight: .medium))
                .foregroundColor(.secondary)
            
            // 忆年显示
            if let festival = festival {
                Text(festival.name)
                    .font(.system(.caption2, design: .default, weight: .medium))
                    .foregroundColor(festivalTextColor(for: festival.type, festivalName: festival.name))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(festivalTextColor(for: festival.type, festivalName: festival.name).opacity(0.1))
                    )
            }
            
            // 天气显示
            WeatherDisplayView(date: selectedDate, weatherManager: weatherManager, isCompact: true)
        }
        .minimumScaleFactor(0.5)  // 提高缩放范围，允许缩小到50%
        .lineLimit(1)
        .allowsTightening(true)
        .truncationMode(.tail)  // 添加截断模式
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)  // 限制动态字体最大尺寸
    }
    
    private func festivalTextColor(for type: ChineseFestivalType, festivalName: String = "") -> Color {
        switch type {
        case .lunar:
            return .orange  // 传统节假日使用温暖的橙色
        case .solar:
            // 区分法定假日和普通公历忆年
            let legalHolidays = ["元旦", "劳动节", "国庆节"]
            if legalHolidays.contains(festivalName) {
                return .red  // 法定假日使用醒目的红色
            } else {
                return .accentColor  // 其他公历忆年使用品牌色（蓝色）
            }
        case .solarTerm:
            return .green.opacity(0.8)  // 节气使用浅绿色，弱化颜色强调信息性
        }
    }
    
    @ViewBuilder
    private var content: some View {
        let items = scheduleStore.schedulesForDate(selectedDate)
        if items.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "calendar.badge.exclamationmark").font(.largeTitle)
                Text("当日暂无日程")
                    .foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(items, id: \.id) { item in
                    ScheduleCardView(item: item, scheduleStore: scheduleStore, onEdit: {
                        editingItem = item
                    })
                        .contextMenu {
                            // 编辑
                            Button {
                                editingItem = item
                            } label: {
                                Label("编辑日程", systemImage: "pencil")
                            }
                            // 完成状态切换
                            Button {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    scheduleStore.toggleCompletion(for: item.id)
                                }
                            } label: {
                                Label(item.isCompleted ? "标记为未完成" : "标记为完成", systemImage: item.isCompleted ? "arrow.uturn.backward" : "checkmark.circle")
                            }
                            Divider()
                            if item.isRecurring {
                                Button {
                                    deleteType = .single
                                    scheduleToDelete = item
                                    showingDeleteAlert = true
                                } label: {
                                    Label("删除此日程", systemImage: "trash")
                                }
                                Button(role: .destructive) {
                                    deleteType = .allRepeating
                                    scheduleToDelete = item
                                    showingDeleteAlert = true
                                } label: {
                                    Label("删除所有重复日程", systemImage: "trash.fill")
                                }
                            } else {
                                Button(role: .destructive) {
                                    deleteType = .single
                                    scheduleToDelete = item
                                    showingDeleteAlert = true
                                } label: {
                                    Label("删除日程", systemImage: "trash")
                                }
                            }
                        }
                }
                .onDelete { indexSet in
                    // 如果只有一个项目，使用单项删除确认
                    if indexSet.count == 1, let index = indexSet.first {
                        let item = items[index]
                        scheduleToDelete = item
                        deleteType = .single
                        showingDeleteAlert = true
                    } else {
                        // 多项删除直接执行（滑动删除通常期望立即执行）
                        withAnimation {
                            let ids = indexSet.map { items[$0].id }
                            scheduleStore.deleteSchedules(with: ids)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .animation(.easeInOut(duration: 0.3), value: items.count)
        }
    }
    
    private var dayFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        df.locale = Locale(identifier: "zh_CN")
        return df
    }
    
    private var todayFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "M月d日"  // 只显示月份和日期，不显示年份
        df.locale = Locale(identifier: "zh_CN")
        return df
    }
    
    private var enhancedDateTitle: String {
        let lunarInfo = ChineseLunarCalendar.shared.getLunarInfo(for: selectedDate)
        let festival = ChineseFestivalManager.shared.getPrimaryFestival(for: selectedDate)
        let baseTitle = dayFormatter.string(from: selectedDate)
        let lunarTitle = "\(lunarInfo.month)\(lunarInfo.day)"
        
        if let festival = festival {
            return "\(baseTitle) \(lunarTitle) \(festival.name)"
        } else {
            return "\(baseTitle) \(lunarTitle)"
        }
    }
}