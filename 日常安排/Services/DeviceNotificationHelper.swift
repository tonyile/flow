import Foundation
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

/// 设备特定的通知助手类，处理真机和模拟器的差异
class DeviceNotificationHelper {
    static let shared = DeviceNotificationHelper()
    
    private init() {}
    
    /// 检查设备是否支持通知的完整功能
    func checkDeviceNotificationCapabilities() -> DeviceNotificationCapabilities {
        var capabilities = DeviceNotificationCapabilities()
        
        #if targetEnvironment(simulator)
        capabilities.isSimulator = true
        capabilities.supportsBackgroundRefresh = true
        capabilities.supportsTimeSensitiveNotifications = true
        #else
        capabilities.isSimulator = false
        #if canImport(UIKit)
        capabilities.supportsBackgroundRefresh = UIApplication.shared.backgroundRefreshStatus == .available
        capabilities.supportsTimeSensitiveNotifications = true
        capabilities.isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        #else
        // macOS上的默认值
        capabilities.supportsBackgroundRefresh = true
        capabilities.supportsTimeSensitiveNotifications = true
        capabilities.isLowPowerModeEnabled = false
        #endif
        #endif
        
        return capabilities
    }
    
    /// 获取推荐的通知缓冲时间
    func getRecommendedBufferTime() -> TimeInterval {
        #if targetEnvironment(simulator)
        return 5  // 模拟器5秒
        #else
        // 真机根据设备状态调整
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            return 60  // 低电量模式下增加到60秒
        } else {
            return 30  // 正常情况30秒
        }
        #endif
    }
    
    /// 获取推荐的通知配置
    func getRecommendedNotificationContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        
        #if !targetEnvironment(simulator)
        // 真机特有配置
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 1.0
        }
        #endif
        
        return content
    }
    
    /// 检查并报告设备通知限制
    func checkDeviceNotificationRestrictions() async -> [String] {
        var restrictions: [String] = []
        
        #if !targetEnvironment(simulator) && canImport(UIKit)
        // 检查后台刷新状态
        let backgroundRefreshStatus = UIApplication.shared.backgroundRefreshStatus
        switch backgroundRefreshStatus {
        case .denied:
            restrictions.append("后台刷新被拒绝")
        case .restricted:
            restrictions.append("后台刷新受限")
        default:
            break
        }
        
        // 检查低电量模式
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            restrictions.append("设备处于低电量模式")
        }
        
        // 检查通知设置
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        
        if settings.authorizationStatus != .authorized {
            restrictions.append("通知权限未授权")
        }
        
        if settings.alertSetting == .disabled {
            restrictions.append("通知横幅被禁用")
        }
        
        if settings.soundSetting == .disabled {
            restrictions.append("通知声音被禁用")
        }
        
        if settings.lockScreenSetting == .disabled {
            restrictions.append("锁屏通知被禁用")
        }
        
        if #available(iOS 15.0, *) {
            if settings.timeSensitiveSetting == .disabled {
                restrictions.append("时效性通知被禁用")
            }
        }
        #endif
        
        return restrictions
    }
}

/// 设备通知能力结构体
struct DeviceNotificationCapabilities {
    var isSimulator: Bool = false
    var supportsBackgroundRefresh: Bool = false
    var supportsTimeSensitiveNotifications: Bool = false
    var isLowPowerModeEnabled: Bool = false
    
    var description: String {
        var desc = isSimulator ? "模拟器" : "真机"
        desc += ", 后台刷新: \(supportsBackgroundRefresh ? "支持" : "不支持")"
        desc += ", 时效性通知: \(supportsTimeSensitiveNotifications ? "支持" : "不支持")"
        if !isSimulator {
            desc += ", 低电量模式: \(isLowPowerModeEnabled ? "开启" : "关闭")"
        }
        return desc
    }
}