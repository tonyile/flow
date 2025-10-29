import SwiftUI
import UIKit

// UITabBar透明度配置助手
struct UITabBarAppearanceHelper {
    static func configureTransparentTabBar() {
        // 检查iOS版本兼容性
        if #available(iOS 15.0, *) {
            // iOS 15及以上版本使用UITabBarAppearance
            let appearance = UITabBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = .clear
            appearance.shadowColor = .clear
            
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        } else {
            // iOS 15以下版本直接设置UITabBar属性
            UITabBar.appearance().backgroundColor = .clear
            UITabBar.appearance().backgroundImage = UIImage()
            UITabBar.appearance().shadowImage = UIImage()
            UITabBar.appearance().isTranslucent = true
        }
    }
}

// SwiftUI视图修饰符
struct TransparentTabBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                UITabBarAppearanceHelper.configureTransparentTabBar()
            }
    }
}

extension View {
    func transparentTabBar() -> some View {
        self.modifier(TransparentTabBarModifier())
    }
}