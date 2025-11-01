import SwiftUI

struct ContentView: View {
    @State private var selectedTab: TabBarItem = .time
    @StateObject private var colorSchemeManager = ColorSchemeManager.shared

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                DayView(scheduleStore: ScheduleStore.shared)
                    .tag(TabBarItem.time)
                WeekView(scheduleStore: ScheduleStore.shared)
                    .tag(TabBarItem.week)
                MonthView(scheduleStore: ScheduleStore.shared)
                    .tag(TabBarItem.month)
                FlowView()
                    .tag(TabBarItem.flow)
                StatisticsView(scheduleStore: ScheduleStore.shared)
                    .tag(TabBarItem.statistics)
                SettingsView(scheduleStore: ScheduleStore.shared)
                    .tag(TabBarItem.settings)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea(.all, edges: .bottom)

            CustomTabBar(selectedTab: $selectedTab)
                .padding(.bottom)
        }
        .environmentObject(colorSchemeManager)
        .ignoresSafeArea(.keyboard)
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: TabBarItem
    private let displayItems: [TabBarItem] = [.time, .flow, .statistics, .settings]

    var body: some View {
        HStack {
            ForEach(displayItems, id: \.self) { item in
                Button {
                    selectedTab = item
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.iconName)
                            .font(.system(size: 22))
                        Text(item.title)
                            .font(.system(size: 10))
                    }
                }
                .foregroundColor(isSelected(item) ? .accentColor : .gray)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 50)
        .padding(.horizontal)
        .background(.thinMaterial)
        .cornerRadius(25)
        .padding(.horizontal, 20)
    }

    private func isSelected(_ item: TabBarItem) -> Bool {
        if item == .time {
            return selectedTab == .time || selectedTab == .week || selectedTab == .month
        }
        return selectedTab == item
    }
}

enum TabBarItem: Int, CaseIterable {
    case time, week, month, flow, statistics, settings

    var title: String {
        switch self {
        case .time: return "日程"
        case .week: return "周历"
        case .month: return "月历"
        case .flow: return "流水"
        case .statistics: return "统计"
        case .settings: return "设置"
        }
    }

    var iconName: String {
        switch self {
        case .time: return "clock"
        case .week: return "calendar.week.leading"
        case .month: return "calendar"
        case .flow: return "list.bullet"
        case .statistics: return "chart.bar.fill"
        case .settings: return "gear"
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ColorSchemeManager.shared)
}
