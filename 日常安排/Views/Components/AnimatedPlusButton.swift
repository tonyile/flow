import SwiftUI

struct AnimatedPlusButton: View {
    let action: () -> Void
    @State private var isAnimating = false
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        Button(action: {
            // 触发动画
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                scale = 0.8
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    scale = 1.0
                }
            }
            
            action()
        }) {
            ZStack {
                // 背景圆圈
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.red.opacity(0.7),
                                Color.orange.opacity(0.7),
                                Color.yellow.opacity(0.7),
                                Color.green.opacity(0.7),
                                Color.blue.opacity(0.7),
                                Color.purple.opacity(0.7)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                    .rotationEffect(.degrees(rotation))
                    .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
                    .scaleEffect(scale)
                    .animation(.easeInOut(duration: 0.1), value: scale)
                
                // "+" 符号
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white)
                    .scaleEffect(scale)
            }
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            // 启动持续的旋转动画
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

// 预览
struct AnimatedPlusButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            AnimatedPlusButton {
                // 按钮被点击
            }
            
            // 在不同背景下的预览
            AnimatedPlusButton {
                // 按钮被点击
            }
            .background(Color.gray.opacity(0.2))
            .cornerRadius(10)
            .padding()
        }
        .padding()
    }
}