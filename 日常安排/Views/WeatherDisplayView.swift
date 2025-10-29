import SwiftUI

struct WeatherDisplayView: View {
    let date: Date
    @ObservedObject var weatherManager: WeatherManager
    let isCompact: Bool
    
    init(date: Date, weatherManager: WeatherManager = WeatherManager.shared, isCompact: Bool = false) {
        self.date = date
        self.weatherManager = weatherManager
        self.isCompact = isCompact
    }
    
    var body: some View {
        Group {
            if weatherManager.isLoading {
                loadingView
            } else if let weather = weatherForDate {
                weatherContentView(weather: weather)
            } else {
                emptyWeatherView
            }
        }
        .onAppear {
            weatherManager.fetchWeatherForTime(date) { _ in }
        }
    }
    
    private var weatherForDate: WeatherInfo? {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return weatherManager.currentWeather
        } else {
            let key = weatherManager.weatherCacheKey(for: date)
            return weatherManager.timeSpecificWeather[key]
        }
    }
    
    @ViewBuilder
    private var loadingView: some View {
        if isCompact {
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("加载中")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        } else {
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("正在获取天气...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var emptyWeatherView: some View {
        if isCompact {
            HStack(spacing: 4) {
                Image(systemName: "cloud.slash")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
                Text("无天气")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
            }
        } else {
            HStack(spacing: 6) {
                Image(systemName: "cloud.slash")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.7))
                Text("暂无天气信息")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.7))
            }
        }
    }
    
    @ViewBuilder
    private func weatherContentView(weather: WeatherInfo) -> some View {
        if isCompact {
            compactWeatherView(weather: weather)
        } else {
            fullWeatherView(weather: weather)
        }
    }
    
    @ViewBuilder
    private func compactWeatherView(weather: WeatherInfo) -> some View {
        HStack(spacing: 4) {
            Image(systemName: weatherIcon(for: weather.condition))
                .font(.body)
                .foregroundColor(weatherColor(for: weather.condition))
            
            Text("\(Int(weather.temperature))°")
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
    
    @ViewBuilder
    private func fullWeatherView(weather: WeatherInfo) -> some View {
        HStack(spacing: 6) {
            Image(systemName: weatherIcon(for: weather.condition))
                .font(.title3)
                .foregroundColor(weatherColor(for: weather.condition))
            
            VStack(alignment: .leading, spacing: 1) {
                Text("\(Int(weather.temperature))°C")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(weatherDescription(for: weather.condition))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func weatherIcon(for condition: String) -> String {
        switch condition.lowercased() {
        case "clear", "sunny":
            return "sun.max.fill"
        case "partly cloudy", "partly_cloudy":
            return "cloud.sun.fill"
        case "cloudy", "overcast":
            return "cloud.fill"
        case "rainy", "rain", "light rain", "heavy rain":
            return "cloud.rain.fill"
        case "snowy", "snow":
            return "cloud.snow.fill"
        case "stormy", "thunderstorm":
            return "cloud.bolt.rain.fill"
        case "foggy", "fog":
            return "cloud.fog.fill"
        case "windy":
            return "wind"
        default:
            return "cloud"
        }
    }
    
    private func weatherColor(for condition: String) -> Color {
        switch condition.lowercased() {
        case "clear", "sunny":
            return .orange
        case "partly cloudy", "partly_cloudy":
            return .blue
        case "cloudy", "overcast":
            return .gray
        case "rainy", "rain", "light rain", "heavy rain":
            return .blue
        case "snowy", "snow":
            return .cyan
        case "stormy", "thunderstorm":
            return .purple
        case "foggy", "fog":
            return .gray
        case "windy":
            return .mint
        default:
            return .secondary
        }
    }
    
    private func weatherDescription(for condition: String) -> String {
        switch condition.lowercased() {
        case "clear", "sunny":
            return "晴朗"
        case "partly cloudy", "partly_cloudy":
            return "多云"
        case "cloudy", "overcast":
            return "阴天"
        case "rainy", "rain":
            return "雨天"
        case "light rain":
            return "小雨"
        case "heavy rain":
            return "大雨"
        case "snowy", "snow":
            return "雪天"
        case "stormy", "thunderstorm":
            return "雷雨"
        case "foggy", "fog":
            return "雾天"
        case "windy":
            return "大风"
        default:
            return condition
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        WeatherDisplayView(date: Date(), isCompact: false)
        WeatherDisplayView(date: Date(), isCompact: true)
    }
    .padding()
}