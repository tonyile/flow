import Foundation
import CoreLocation
import Combine

struct WeatherInfo {
    let temperature: Int
    let condition: String
    let icon: String
    let description: String
    let dateTime: Date // 添加时间信息
}

class WeatherManager: NSObject, ObservableObject {
    static let shared = WeatherManager()
    
    @Published var currentWeather: WeatherInfo?
    @Published var isLoading = false
    @Published var currentCityName: String? // 添加当前城市名称
    
    // 缓存特定时间的天气信息
    @Published var timeSpecificWeather: [String: WeatherInfo] = [:]
    
    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocation?
    private let geocoder = CLGeocoder() // 添加地理编码器
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        requestLocationPermission()
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    // 强制请求当前位置并获取城市名称
    func forceRequestLocationAndGetCity() async -> String? {
        // 检查权限状态
        let status = locationManager.authorizationStatus
        
        switch status {
        case .notDetermined:
            // 请求权限
            locationManager.requestWhenInUseAuthorization()
            // 等待权限响应
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 等待2秒
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.currentCityName = "权限被拒绝"
            }
            return "权限被拒绝"
        case .authorizedWhenInUse, .authorizedAlways:
            break
        @unknown default:
            DispatchQueue.main.async {
                self.currentCityName = "定位异常"
            }
            return "定位异常"
        }
        
        // 如果已有位置，直接使用
        if let location = currentLocation {
            return await getCityName(from: location)
        }
        
        // 请求新的位置
        locationManager.requestLocation()
        
        // 等待位置更新
        for _ in 0..<10 { // 最多等待10秒
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 等待1秒
            if let location = currentLocation {
                return await getCityName(from: location)
            }
        }
        
        DispatchQueue.main.async {
            self.currentCityName = "定位超时"
        }
        return "定位超时"
    }
    
    // 从位置获取城市名称的辅助方法
    private func getCityName(from location: CLLocation) async -> String? {
        return await withCheckedContinuation { continuation in
            geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
                if let error = error {
                    print("地理编码错误: \(error)")
                    let errorMessage = "地理编码失败"
                    DispatchQueue.main.async {
                        self?.currentCityName = errorMessage
                    }
                    continuation.resume(returning: errorMessage)
                    return
                }
                
                if let placemark = placemarks?.first {
                    let cityName = placemark.locality ?? placemark.administrativeArea ?? "未知城市"
                    DispatchQueue.main.async {
                        self?.currentCityName = cityName
                    }
                    continuation.resume(returning: cityName)
                } else {
                    let unknownMessage = "未知位置"
                    DispatchQueue.main.async {
                        self?.currentCityName = unknownMessage
                    }
                    continuation.resume(returning: unknownMessage)
                }
            }
        }
    }
    
    // 获取当前位置的城市名称
    func getCurrentCityName() async -> String? {
        guard let location = currentLocation else {
            return nil
        }
        
        return await withCheckedContinuation { continuation in
            geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
                if let error = error {
                    print("地理编码错误: \(error)")
                    continuation.resume(returning: nil)
                    return
                }
                
                if let placemark = placemarks?.first {
                    let cityName = placemark.locality ?? placemark.administrativeArea ?? "未知城市"
                    DispatchQueue.main.async {
                        self?.currentCityName = cityName
                    }
                    continuation.resume(returning: cityName)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    // 获取当前位置的城市名称（回调版本）
    func getCurrentCityName(completion: @escaping (String?) -> Void) {
        guard let location = currentLocation else {
            completion(nil)
            return
        }
        
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            if let error = error {
                print("地理编码错误: \(error)")
                completion(nil)
                return
            }
            
            if let placemark = placemarks?.first {
                let cityName = placemark.locality ?? placemark.administrativeArea ?? "未知城市"
                DispatchQueue.main.async {
                    self?.currentCityName = cityName
                }
                completion(cityName)
            } else {
                completion(nil)
            }
        }
    }

    func fetchWeather() {
        guard let location = currentLocation else {
            requestLocationPermission()
            return
        }
        
        isLoading = true
        fetchWeatherData(for: location)
    }
    
    // 新增：根据城市名称获取天气信息
    func fetchWeatherForCity(_ cityName: String, dateTime: Date = Date()) async -> WeatherInfo? {
        return await withCheckedContinuation { continuation in
            fetchWeatherForCity(cityName, dateTime: dateTime) { weather in
                continuation.resume(returning: weather)
            }
        }
    }
    
    // 根据城市名称获取天气信息（回调版本）
    func fetchWeatherForCity(_ cityName: String, dateTime: Date = Date(), completion: @escaping (WeatherInfo?) -> Void) {
        let cacheKey = weatherCacheKey(for: dateTime, city: cityName)
        
        // 检查缓存
        if let cachedWeather = timeSpecificWeather[cacheKey] {
            completion(cachedWeather)
            return
        }
        
        // 如果是"当前位置"，使用现有的位置获取逻辑
        if cityName == "当前位置" || cityName.isEmpty {
            fetchWeatherForTime(dateTime, completion: completion)
            return
        }
        
        // 对于指定城市，生成基于城市名称的模拟数据
        let cityWeather = getMockWeatherData(for: dateTime, city: cityName)
        timeSpecificWeather[cacheKey] = cityWeather
        completion(cityWeather)
    }
    
    // 生成缓存键（支持城市）
    func weatherCacheKey(for dateTime: Date, city: String? = nil) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH"
        let timeKey = formatter.string(from: dateTime)
        if let city = city, !city.isEmpty {
            return "\(city)-\(timeKey)"
        }
        return timeKey
    }
    
    // 获取特定时间的天气（异步版本）
    func fetchWeatherForTime(_ dateTime: Date) async -> WeatherInfo? {
        return await withCheckedContinuation { continuation in
            fetchWeatherForTime(dateTime) { weather in
                continuation.resume(returning: weather)
            }
        }
    }
    
    // 获取特定时间的天气（回调版本）
    func fetchWeatherForTime(_ dateTime: Date, completion: @escaping (WeatherInfo?) -> Void) {
        let cacheKey = weatherCacheKey(for: dateTime)
        
        // 检查缓存
        if let cachedWeather = timeSpecificWeather[cacheKey] {
            completion(cachedWeather)
            return
        }
        
        guard let location = currentLocation else {
            // 如果没有位置信息，使用模拟数据
            let mockWeather = getMockWeatherData(for: dateTime)
            timeSpecificWeather[cacheKey] = mockWeather
            completion(mockWeather)
            return
        }
        
        // 获取特定时间的天气数据
        fetchWeatherData(for: location, dateTime: dateTime) { [weak self] weather in
            if let weather = weather {
                self?.timeSpecificWeather[cacheKey] = weather
            }
            completion(weather)
        }
    }
    
    // 生成缓存键
    func weatherCacheKey(for dateTime: Date) -> String {
        return weatherCacheKey(for: dateTime, city: nil)
    }
    
    private func fetchWeatherData(for location: CLLocation, dateTime: Date? = nil, completion: ((WeatherInfo?) -> Void)? = nil) {
        // 暂时使用模拟数据，避免API密钥问题
        let targetDateTime = dateTime ?? Date()
        print("获取位置天气数据: \(location.coordinate.latitude), \(location.coordinate.longitude), 时间: \(targetDateTime)")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            if dateTime == nil {
                self?.isLoading = false
                self?.currentWeather = self?.getMockWeatherData(for: targetDateTime)
            }
            
            let weather = self?.getMockWeatherData(for: targetDateTime)
            completion?(weather)
        }
        
        // 如果有真实的API密钥，可以取消注释以下代码
        /*
        let apiKey = "your_api_key_here" // 需要替换为实际的API密钥
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        
        // 根据是否有特定时间选择不同的API端点
        let urlString: String
        if let dateTime = dateTime {
            // 使用预报API获取特定时间的天气
            let timestamp = Int(dateTime.timeIntervalSince1970)
            urlString = "https://api.openweathermap.org/data/2.5/forecast?lat=\(lat)&lon=\(lon)&appid=\(apiKey)&units=metric&lang=zh_cn"
        } else {
            // 使用当前天气API
            urlString = "https://api.openweathermap.org/data/2.5/weather?lat=\(lat)&lon=\(lon)&appid=\(apiKey)&units=metric&lang=zh_cn"
        }
        
        guard let url = URL(string: urlString) else {
            if dateTime == nil {
                isLoading = false
            }
            completion?(getMockWeatherData(for: dateTime ?? Date()))
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if dateTime == nil {
                    self?.isLoading = false
                }
                
                if let error = error {
                    print("Weather API error: \(error)")
                    let mockWeather = self?.getMockWeatherData(for: dateTime ?? Date())
                    if dateTime == nil {
                        self?.currentWeather = mockWeather
                    }
                    completion?(mockWeather)
                    return
                }
                
                guard let data = data else {
                    let mockWeather = self?.getMockWeatherData(for: dateTime ?? Date())
                    if dateTime == nil {
                        self?.currentWeather = mockWeather
                    }
                    completion?(mockWeather)
                    return
                }
                
                do {
                    if dateTime != nil {
                        // 处理预报数据
                        let forecastResponse = try JSONDecoder().decode(ForecastResponse.self, from: data)
                        let targetWeather = self?.findClosestForecast(in: forecastResponse, to: dateTime!)
                        completion?(targetWeather)
                    } else {
                        // 处理当前天气数据
                        let weatherResponse = try JSONDecoder().decode(WeatherResponse.self, from: data)
                        let weather = WeatherInfo(
                            temperature: Int(weatherResponse.main.temp),
                            condition: weatherResponse.weather.first?.main ?? "Clear",
                            icon: self?.getWeatherIcon(for: weatherResponse.weather.first?.main ?? "Clear") ?? "sun.max",
                            description: weatherResponse.weather.first?.description ?? "晴朗",
                            dateTime: Date()
                        )
                        self?.currentWeather = weather
                        completion?(weather)
                    }
                } catch {
                    print("JSON parsing error: \(error)")
                    let mockWeather = self?.getMockWeatherData(for: dateTime ?? Date())
                    if dateTime == nil {
                        self?.currentWeather = mockWeather
                    }
                    completion?(mockWeather)
                }
            }
        }.resume()
        */
    }
    
    // 修改模拟数据方法以支持特定时间和城市
    private func getMockWeatherData(for dateTime: Date = Date(), city: String? = nil) -> WeatherInfo {
        let hour = Calendar.current.component(.hour, from: dateTime)
        let day = Calendar.current.component(.day, from: dateTime)
        let month = Calendar.current.component(.month, from: dateTime)
        
        // 根据时间生成不同的模拟天气，增加更多变化
        let weatherConditions = [
            (condition: "Clear", icon: "sun.max", description: "晴朗", temp: 22),
            (condition: "Clouds", icon: "cloud", description: "多云", temp: 18),
            (condition: "Rain", icon: "cloud.rain", description: "小雨", temp: 15),
            (condition: "Partly Cloudy", icon: "cloud.sun", description: "晴转多云", temp: 20),
            (condition: "Light Rain", icon: "cloud.drizzle", description: "毛毛雨", temp: 16),
            (condition: "Overcast", icon: "cloud.fill", description: "阴天", temp: 17)
        ]
        
        // 使用时间、日期、月份和城市名称生成更复杂的伪随机索引
        var seedValue = hour * 2 + day + month * 3
        if let city = city, !city.isEmpty {
            // 为不同城市添加不同的种子值
            let cityHash = city.hash
            seedValue += abs(cityHash) % 100
        }
        let index = seedValue % weatherConditions.count
        let weather = weatherConditions[index]
        
        // 根据时间调整温度，使其更真实
        var temperature = weather.temp
        
        // 根据城市调整基础温度（模拟不同城市的气候差异）
        if let city = city, !city.isEmpty {
            switch city {
            case "北京":
                temperature += 2
            case "上海":
                temperature += 3
            case "广州":
                temperature += 8
            case "深圳":
                temperature += 9
            case "杭州":
                temperature += 4
            case "南京":
                temperature += 1
            case "成都":
                temperature += 0
            case "重庆":
                temperature += 2
            case "西安":
                temperature -= 1
            case "武汉":
                temperature += 1
            case "天津":
                temperature += 1
            case "青岛":
                temperature += 2
            case "大连":
                temperature -= 2
            case "厦门":
                temperature += 7
            case "三亚":
                temperature += 12
            case "哈尔滨":
                temperature -= 8
            case "长春":
                temperature -= 6
            case "沈阳":
                temperature -= 4
            case "昆明":
                temperature += 5
            case "拉萨":
                temperature -= 3
            default:
                // 其他城市使用城市名称的哈希值来调整温度
                let cityTempAdjustment = (abs(city.hash) % 20) - 10
                temperature += cityTempAdjustment
            }
        }
        
        // 一天中的温度变化
        if hour >= 6 && hour < 9 {
            temperature += 1 // 早晨
        } else if hour >= 9 && hour < 12 {
            temperature += 3 // 上午
        } else if hour >= 12 && hour < 15 {
            temperature += 6 // 中午最热
        } else if hour >= 15 && hour < 18 {
            temperature += 4 // 下午
        } else if hour >= 18 && hour < 21 {
            temperature += 2 // 傍晚
        } else if hour >= 21 || hour < 6 {
            temperature -= 2 // 夜间较凉
        }
        
        // 季节性调整（简化版）
        if month >= 12 || month <= 2 {
            temperature -= 8 // 冬季
        } else if month >= 3 && month <= 5 {
            temperature += 2 // 春季
        } else if month >= 6 && month <= 8 {
            temperature += 8 // 夏季
        } else {
            temperature += 0 // 秋季
        }
        
        // 确保温度在合理范围内
        temperature = max(-10, min(40, temperature))
        
        return WeatherInfo(
            temperature: temperature,
            condition: weather.condition,
            icon: weather.icon,
            description: weather.description,
            dateTime: dateTime
        )
    }
    
    // 从预报数据中找到最接近目标时间的天气
    private func findClosestForecast(in forecast: ForecastResponse, to targetTime: Date) -> WeatherInfo? {
        var closestForecast: ForecastItem?
        var minTimeDifference: TimeInterval = .greatestFiniteMagnitude
        
        for item in forecast.list {
            let timeDifference = abs(item.dt_txt.timeIntervalSince(targetTime))
            if timeDifference < minTimeDifference {
                minTimeDifference = timeDifference
                closestForecast = item
            }
        }
        
        guard let forecast = closestForecast else { return nil }
        
        return WeatherInfo(
            temperature: Int(forecast.main.temp),
            condition: forecast.weather.first?.main ?? "Clear",
            icon: getWeatherIcon(for: forecast.weather.first?.main ?? "Clear"),
            description: forecast.weather.first?.description ?? "晴朗",
            dateTime: forecast.dt_txt
        )
    }
    
    private func getWeatherIcon(for condition: String) -> String {
        switch condition.lowercased() {
        case "clear":
            return "sun.max"
        case "clouds":
            return "cloud"
        case "rain":
            return "cloud.rain"
        case "snow":
            return "cloud.snow"
        case "thunderstorm":
            return "cloud.bolt"
        case "drizzle":
            return "cloud.drizzle"
        case "mist", "fog":
            return "cloud.fog"
        default:
            return "sun.max"
        }
    }
}

extension WeatherManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        fetchWeatherData(for: location)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
        // 使用模拟数据
        currentWeather = getMockWeatherData()
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("位置权限状态变更: \(status.rawValue)")
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            print("位置权限已授权，开始获取位置")
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            print("位置权限被拒绝，使用模拟天气数据")
            // 使用模拟数据
            currentWeather = getMockWeatherData()
        case .notDetermined:
            print("位置权限未确定，请求权限")
            locationManager.requestWhenInUseAuthorization()
        @unknown default:
            print("未知的位置权限状态")
            currentWeather = getMockWeatherData()
        }
    }
}

// MARK: - Weather API Response Models
struct WeatherResponse: Codable {
    let main: MainWeather
    let weather: [Weather]
}

struct MainWeather: Codable {
    let temp: Double
    let humidity: Int
}

struct Weather: Codable {
    let main: String
    let description: String
    let icon: String
}

// 新增：预报API响应模型
struct ForecastResponse: Codable {
    let list: [ForecastItem]
}

struct ForecastItem: Codable {
    let dt: TimeInterval
    let main: MainWeather
    let weather: [Weather]
    let dt_txt: Date
    
    private enum CodingKeys: String, CodingKey {
        case dt, main, weather, dt_txt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dt = try container.decode(TimeInterval.self, forKey: .dt)
        main = try container.decode(MainWeather.self, forKey: .main)
        weather = try container.decode([Weather].self, forKey: .weather)
        
        let dateString = try container.decode(String.self, forKey: .dt_txt)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dt_txt = formatter.date(from: dateString) ?? Date()
    }
}