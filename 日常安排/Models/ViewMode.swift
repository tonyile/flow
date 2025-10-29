import SwiftUI

enum ViewMode: String, CaseIterable {
    case day = "day"
    case week = "week"
    case month = "month"
    
    var title: String {
        switch self {
        case .day:
            return "今日"
        case .week:
            return "周历"
        case .month:
            return "月历"
        }
    }
    
    var icon: String {
        switch self {
        case .day:
            return "calendar.day.timeline.left"
        case .week:
            return "calendar.badge.clock"
        case .month:
            return "calendar"
        }
    }
    
    var nextMode: ViewMode {
        switch self {
        case .day:
            return .week
        case .week:
            return .month
        case .month:
            return .day
        }
    }
    
    var previousMode: ViewMode {
        switch self {
        case .day:
            return .month
        case .week:
            return .day
        case .month:
            return .week
        }
    }
}