import SwiftUI

struct StatisticsView: View {
    @ObservedObject var scheduleStore: ScheduleStore
    @State private var selectedMonth: Date = .now
    
    // 添加月份格式化器，与MonthView保持一致
    private let monthFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy年M月"
        df.locale = Locale(identifier: "zh_CN")
        return df
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                completionSection
                categorySection
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .safeAreaInset(edge: .bottom) {
            // 导航栏高度：12(vertical padding) + 32(button height) + 16(bottom padding) + 安全区域 ≈ 80-100
            Color.clear.frame(height: 100)
        }
        .navigationTitle("统计")
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("StatisticsMonthSwitchGesture"))) { notification in
            if let direction = notification.userInfo?["direction"] as? Int {
                shiftMonth(direction)
            }
        }
    }

    private var header: some View {
        return HStack {
            Spacer()
            
            Button(action: {
                // 点击日期标题也可以触发月份切换，这里可以显示日期选择器或其他交互
            }) {
                // 只显示主要月份，移除农历信息
                Text(monthFormatter.string(from: selectedMonth))
                    .font(.system(.title2, design: .default, weight: .semibold))
                    .foregroundColor(.primary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .allowsTightening(true)
                    .truncationMode(.tail)
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var completionSection: some View {
        let calendar = Calendar.current
        let monthSchedules = scheduleStore.scheduleItems.filter { item in
            calendar.isDate(item.startTime, equalTo: selectedMonth, toGranularity: .month)
        }
        
        let rate: Double
        let completedCount: Int
        let totalCount: Int
        
        if monthSchedules.isEmpty {
            rate = 1.0  // 没有日程时显示100%完成率
            completedCount = 0
            totalCount = 0
        } else {
            completedCount = monthSchedules.filter { $0.isCompleted }.count
            totalCount = monthSchedules.count
            rate = Double(completedCount) / Double(totalCount)
        }
        
        // 获取激励文字
        let motivationalText = getMotivationalText(rate: rate, completed: completedCount, total: totalCount)
        
        return VStack(spacing: 16) {
            // 激励性标题
            VStack(spacing: 8) {
                Text("月完成率")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                // 动态激励文字
                Text(motivationalText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(getMotivationalColor(rate: rate))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            ZStack {
                // 背景圆环
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    .frame(width: 120, height: 120)
                
                // 进度圆环
                Circle()
                    .trim(from: 0, to: rate)
                    .stroke(
                        LinearGradient(
                            colors: getProgressColors(rate: rate),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: rate)
                
                // 中心数据
                VStack(spacing: 4) {
                    Text(String(format: "%.0f%%", rate * 100))
                        .font(.largeTitle)
                        .fontWeight(.semibold)
                        .foregroundColor(getProgressColors(rate: rate)[1])
                    Text("\(completedCount)/\(totalCount)")
                        .font(.caption)
                        .fontWeight(.regular)
                        .foregroundColor(Color.secondary.opacity(0.7))
                }
            }
            
            // 成就徽章（当完成率达到特定阶段时显示）
            if let achievement = getAchievement(rate: rate, completed: completedCount) {
                HStack(spacing: 8) {
                    Image(systemName: achievement.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(achievement.color)
                    Text(achievement.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(achievement.color)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(achievement.color.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(achievement.color.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                #if os(iOS)
                .fill(Color(.systemBackground))
                #else
                .fill(Color(NSColor.controlBackgroundColor))
                #endif
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    // 获取激励文字
    private func getMotivationalText(rate: Double, completed: Int, total: Int) -> String {
        if total == 0 {
            return "暂无日程安排，享受自由时光 ✨"
        }
        
        switch rate {
        case 1.0:
            return "完美！所有任务都已完成 🎉"
        case 0.8..<1.0:
            return "表现优秀！再接再厉 💪"
        case 0.6..<0.8:
            return "进展不错，继续加油 🌟"
        case 0.4..<0.6:
            return "已完成一半，坚持下去 📈"
        case 0.2..<0.4:
            return "良好开端，继续努力 🚀"
        case 0.0..<0.2:
            return "刚刚起步，每一步都很重要 🌱"
        default:
            return "开始行动，成就更好的自己 ✊"
        }
    }
    
    // 获取激励文字颜色
    private func getMotivationalColor(rate: Double) -> Color {
        switch rate {
        case 0.8...1.0:
            return .green
        case 0.6..<0.8:
            return .blue
        case 0.4..<0.6:
            return .orange
        default:
            return .secondary
        }
    }
    
    // 获取进度条颜色
    private func getProgressColors(rate: Double) -> [Color] {
        switch rate {
        case 0.9...1.0:
            return [Color.green.opacity(0.6), Color.green]
        case 0.7..<0.9:
            return [Color.blue.opacity(0.6), Color.blue]
        case 0.5..<0.7:
            return [Color.orange.opacity(0.6), Color.orange]
        default:
            return [Color.red.opacity(0.6), Color.red]
        }
    }
    
    // 成就结构
    private struct Achievement {
        let icon: String
        let title: String
        let color: Color
    }
    
    // 获取成就徽章
    private func getAchievement(rate: Double, completed: Int) -> Achievement? {
        if rate == 1.0 && completed >= 10 {
            return Achievement(icon: "crown.fill", title: "完美执行者", color: .yellow)
        } else if rate == 1.0 && completed >= 5 {
            return Achievement(icon: "star.fill", title: "任务达人", color: .orange)
        } else if rate >= 0.9 {
            return Achievement(icon: "flame.fill", title: "效率之星", color: .red)
        } else if rate >= 0.8 {
            return Achievement(icon: "bolt.fill", title: "行动力强", color: .blue)
        } else if completed >= 20 {
            return Achievement(icon: "target", title: "勤奋执行", color: .purple)
        }
        return nil
    }

    private var categorySection: some View {
        let items = scheduleStore.scheduleItems.filter { 
            Calendar.current.isDate($0.startTime, equalTo: selectedMonth, toGranularity: .month) 
        }
        
        // 获取所有分类的统计数据
        let allCategories = ScheduleCategory.allCases
        let categoryData = allCategories.map { category in
            let categoryItems = items.filter { $0.category == category }
            let completed = categoryItems.filter { $0.isCompleted }.count
            let total = categoryItems.count
            return (category, completed, total)
        }

        return VStack(alignment: .leading, spacing: 0) {
            Text("按分类完成")
                .font(.title2)
                .fontWeight(.semibold)  // 统一使用semibold
                .padding(.leading, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)
            
            VStack(spacing: 0) {
                ForEach(Array(categoryData.enumerated()), id: \.element.0) { index, data in
                    CategoryRowView(
                        category: data.0,
                        completed: data.1,
                        total: data.2
                    )
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    #if os(iOS)
                    .fill(Color(.systemBackground))
                    #else
                    .fill(Color(NSColor.controlBackgroundColor))
                    #endif
            )
            .padding(.horizontal, 16)
        }
    }

    private func shiftMonth(_ direction: Int) {
        selectedMonth = Calendar.current.date(byAdding: .month, value: direction, to: selectedMonth) ?? selectedMonth
    }
}

struct CategoryRowView: View {
    let category: ScheduleCategory
    let completed: Int
    let total: Int
    
    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // 图标 - 使用分类颜色的背景圆圈
            ZStack {
                Circle()
                    .fill(category.color.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Image(systemName: category.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(category.color)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                // 分类名称和统计数字
                HStack {
                    Text(category.label)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // 数值右对齐，与屏幕边缘保持固定间距
                    Text("\(completed)/\(total)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .frame(minWidth: 40, alignment: .trailing)
                }
                
                // 进度条 - 更细、更现代的设计
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // 背景条 - 更细的设计，圆角末端
                        Capsule()
                            #if os(iOS)
                            .fill(Color(.systemGray6))
                            #else
                            .fill(Color(NSColor.quaternaryLabelColor))
                            #endif
                            .frame(height: 6)
                        
                        // 进度条 - 只有在进度大于0时才显示颜色
                        if progress > 0 {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            category.color.opacity(0.7),
                                            category.color
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * progress, height: 6)
                                .animation(.easeInOut(duration: 0.8), value: progress)
                        }
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

extension ScheduleCategory {
    // 移除重复的color定义，使用ScheduleItem.swift中的定义
}
