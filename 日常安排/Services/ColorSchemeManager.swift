
import SwiftUI
import Combine

class ColorSchemeManager: ObservableObject {
    static let shared = ColorSchemeManager()

    @Published var primary: Color = .primary
    @Published var secondary: Color = .secondary
    @Published var accent: Color = .accentColor
    @Published var background: Color = Color(.systemBackground)
    @Published var secondaryBackground: Color = Color(.secondarySystemBackground)
    @Published var tertiaryBackground: Color = Color(.tertiarySystemBackground)

    @Published var lunarFestivalColor: Color = .orange
    @Published var legalHolidayColor: Color = .red
    @Published var solarTermColor: Color = .green.opacity(0.8)
    @Published var blue: Color = .blue
    @Published var accentForegroundColor: Color = .white

    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        updateColors()
        
        // 监听系统颜色模式变化
        NotificationCenter.default.publisher(for: Notification.Name("NSSystemColorsDidChangeNotification"))
            .sink { _ in
                self.updateColors()
            }
            .store(in: &cancellables)
    }

    func updateColors() {
        let colorScheme = UITraitCollection.current.userInterfaceStyle == .dark ? ColorScheme.dark : ColorScheme.light
        
        if colorScheme == .dark {
            self.primary = .white
            self.secondary = Color(white: 0.85)
            self.accent = .accentColor
            self.background = .black
            self.secondaryBackground = Color(white: 0.2)
            self.tertiaryBackground = Color(white: 0.3)
            
            // Brighter colors for dark mode
            self.lunarFestivalColor = Color(red: 1.0, green: 0.6, blue: 0.2) // Brighter Orange
            self.legalHolidayColor = Color(red: 1.0, green: 0.3, blue: 0.3) // Brighter Red
            self.solarTermColor = Color(red: 0.4, green: 0.9, blue: 0.4) // Brighter Green
            self.blue = Color(red: 0.2, green: 0.6, blue: 1.0) // Brighter Blue
            self.accentForegroundColor = .white
        } else {
            self.primary = .black
            self.secondary = Color(white: 0.15)
            self.accent = .accentColor
            self.background = .white
            self.secondaryBackground = Color(white: 0.9)
            self.tertiaryBackground = Color(white: 0.8)
            
            // Standard colors for light mode
            self.lunarFestivalColor = .orange
            self.legalHolidayColor = .red
            self.solarTermColor = .green.opacity(0.8)
            self.blue = .blue
            self.accentForegroundColor = .white
        }
    }
}
