import SwiftUI

struct ScheduleCardView: View {
    let item: ScheduleItem
    @ObservedObject var scheduleStore: ScheduleStore
    @State private var showEditView = false
    @StateObject private var weatherManager = WeatherManager.shared
    @State private var scheduleWeather: WeatherInfo?
    @State private var isLoadingWeather = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // 状态指示器
                RoundedRectangle(cornerRadius: 2)
                    .fill(item.status == .normal || item.status == .upcoming || item.status == .inProgress ? item.category.color : item.status.color)
                    .frame(width: 4, height: 40)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(item.title)
                            .font(.headline) // 使用headline突出主要信息
                            .fontWeight(.semibold)
                            .foregroundColor(item.isCompleted ? .secondary : .primary)
                        
                        Spacer()
                        
                        // 状态标签 - 统一所有状态的显示样式为填充背景+白色文字
                        Text(item.status.label)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(item.status.labelBackgroundColor)
                            .foregroundColor(item.status.labelTextColor)
                            .cornerRadius(8)
                    }
                    
                    if !item.notes.isEmpty {
                        Text(item.notes)
                            .font(.caption)
                            .foregroundColor(.secondary) // 使用标准的secondary颜色
                            .lineLimit(2)
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 12) {
                                Text(item.startTime.formatted(date: .omitted, time: .shortened))
                                Text("⟶")
                                Text(item.endTime.formatted(date: .omitted, time: .shortened))
                            }
                            .font(.subheadline) // 从caption改为subheadline，提高可读性
                            .foregroundStyle(.secondary) // 使用标准的secondary颜色
                            
                            // 显示城市和天气信息在同一行
                            HStack(spacing: 8) {
                                // 城市信息
                                if let city = item.city, !city.isEmpty, city != "当前位置" {
                                    HStack(spacing: 4) {
                                        Image(systemName: "location")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(city)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                // 天气信息
                                if isLoadingWeather {
                                    HStack(spacing: 4) {
                                        ProgressView()
                                            .scaleEffect(0.5)
                                            .frame(width: 12, height: 12)
                                        Text("加载中...")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                } else if let weather = scheduleWeather {
                                    HStack(spacing: 4) {
                                        Image(systemName: weather.icon)
                                            .foregroundColor(.brandPrimary.opacity(0.7))
                                            .font(.caption)
                                        Text("\(weather.temperature)°C")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(weather.description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: item.category.icon)
                            .foregroundStyle(item.category.color.opacity(0.7))
                        
                        Circle().fill(item.category.color).frame(width: 10, height: 10)
                    }
                }
            }
            
        }
        .padding(.horizontal, 14) // 从16减少到14
        .padding(.vertical, 10) // 从12减少到10，使卡片更紧凑
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            item.category.color.opacity(0.08),
                            item.category.color.opacity(0.04)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .contextMenu {
            Button(action: {
                showEditView = true
            }) {
                Label("编辑日程", systemImage: "pencil")
            }
            
            Button(action: {
                scheduleStore.toggleCompletion(for: item.id)
            }) {
                Label(item.isCompleted ? "未完成" : "完成", 
                      systemImage: item.isCompleted ? "circle" : "checkmark.circle")
            }
            
            Divider()
            
            Button(role: .destructive, action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    scheduleStore.deleteSchedules(with: [item.id])
                }
            }) {
                Label("删除日程", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            // 删除按钮放在最右边，支持全滑删除
            Button(role: .destructive) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    scheduleStore.deleteSchedules(with: [item.id])
                }
            } label: {
                Label("删除", systemImage: "trash")
            }
            
            Button {
                showEditView = true
            } label: {
                Label("编辑", systemImage: "pencil")
            }
            .tint(.blue)
            
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    scheduleStore.toggleCompletion(for: item.id)
                }
            } label: {
                Label(item.isCompleted ? "未完成" : "完成", systemImage: item.isCompleted ? "arrow.uturn.backward" : "checkmark.circle")
            }.tint(item.status.color)
        }
        .sheet(isPresented: $showEditView) {
            EditScheduleView(scheduleItem: item, scheduleStore: scheduleStore)
        }
        .onAppear {
            fetchScheduleWeather()
        }
        .onChange(of: item.startTime) { oldValue, newValue in
            fetchScheduleWeather()
        }
    }
    
    // 获取日程对应时间的天气
    private func fetchScheduleWeather() {
        // 避免重复加载相同时间的天气
        if let currentWeather = scheduleWeather,
           Calendar.current.isDate(currentWeather.dateTime, equalTo: item.startTime, toGranularity: .hour) {
            return
        }
        
        isLoadingWeather = true
        
        Task {
            let weather: WeatherInfo?
            
            // 如果日程有城市信息，使用城市获取天气；否则使用当前位置
            if let city = item.city, !city.isEmpty {
                weather = await weatherManager.fetchWeatherForCity(city, dateTime: item.startTime)
            } else {
                weather = await weatherManager.fetchWeatherForTime(item.startTime)
            }
            
            await MainActor.run {
                self.scheduleWeather = weather
                self.isLoadingWeather = false
            }
        }
    }
}
