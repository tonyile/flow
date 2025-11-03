import SwiftUI
import AVFoundation
import MediaPlayer
import AudioToolbox
import Foundation
import OSLog
#if canImport(UIKit)
import UIKit
#endif

struct SoundSelectionView: View {
    @Binding var selectedSound: ReminderSound
    @Binding var customSoundURL: URL?
    @State private var isShowingDocumentPicker = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var lastClickedSound: String = "无"
    
    private let logger = Logger(subsystem: "com.enow.dailyschedule", category: "SoundSelection")
    
    var body: some View {
        NavigationStack {
            VStack {
                // 调试信息显示
                Text("🔧 调试信息: 最后点击的声音 - \(lastClickedSound)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
                
                List {
                    Section("系统铃声") {
                        ForEach(ReminderSound.allCases.filter { $0 != .custom }, id: \.id) { sound in
                            SoundRow(
                                sound: sound,
                                isSelected: selectedSound == sound,
                                onSelect: {
                                    lastClickedSound = sound.displayName
                                    selectedSound = sound
                                    playSound(sound)
                                },
                                onPlay: {
                                    lastClickedSound = "\(sound.displayName) (播放按钮)"
                                    playSound(sound)
                                }
                            )
                        }
                    }
                    
                    Section("自定义音乐") {
                        SoundRow(
                            sound: .custom,
                            isSelected: selectedSound == .custom,
                            customSoundName: customSoundURL?.lastPathComponent,
                            onSelect: {
                                lastClickedSound = "自定义音乐"
                                selectedSound = .custom
                                isShowingDocumentPicker = true
                            },
                            onPlay: customSoundURL != nil ? {
                                lastClickedSound = "自定义音乐 (播放按钮)"
                                playCustomSound()
                            } : nil
                        )
                        
                        if selectedSound == .custom && customSoundURL != nil {
                            Button("播放自定义音乐") {
                                lastClickedSound = "自定义音乐 (按钮)"
                                playCustomSound()
                            }
                            .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("选择提醒音")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .sheet(isPresented: $isShowingDocumentPicker) {
            #if os(iOS)
            DocumentPicker(selectedURL: $customSoundURL)
            #else
            // macOS上使用NSOpenPanel
            Text("macOS上暂不支持自定义音乐文件选择")
                .padding()
            #endif
        }
    }
    
    private func configureAudioSession() {
        logger.info("🔊 开始配置音频会话...")
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)
            logger.info("✅ 音频会话配置成功")
        } catch {
            logger.error("❌ 音频会话配置失败: \(error.localizedDescription)")
        }
    }
    
    private func playSound(_ sound: ReminderSound) {
        print("=== AUDIO DEBUG START ===")
        print("🎵 开始播放声音: \(sound.displayName)")
        print("🎵 声音类型: \(sound.rawValue)")
        logger.info("🎵 开始播放声音: \(sound.displayName)")
        
        // 首先测试系统声音是否工作
        print("🔔 测试系统声音...")
        AudioServicesPlaySystemSound(1007) // 系统默认声音
        
        guard sound != .custom else { 
            print("⚠️ 跳过自定义音乐播放")
            logger.info("⚠️ 跳过自定义音乐播放")
            return 
        }
        
        // 配置音频会话
        configureAudioSession()
        
        // 停止当前播放的音效
        audioPlayer?.stop()
        
        if sound == .defaultSound {
            logger.info("🔔 播放系统默认通知声音")
            AudioServicesPlaySystemSound(1007) // 系统默认通知声音
            return
        }
        
        guard let soundName = sound.systemSoundName else { 
            logger.error("❌ 无法获取音频文件名")
            return 
        }
        
        logger.info("🔍 查找音频文件: \(soundName).caf")
        
        // 首先列出Bundle中的所有资源
        if let bundlePath = Bundle.main.resourcePath {
            logger.info("📁 Bundle资源路径: \(bundlePath)")
            
            // 检查Sounds目录
            let soundsPath = bundlePath + "/Sounds"
            if FileManager.default.fileExists(atPath: soundsPath) {
                logger.info("✅ Sounds目录存在")
                do {
                    let files = try FileManager.default.contentsOfDirectory(atPath: soundsPath)
                    logger.info("📂 Sounds目录内容: \(files)")
                } catch {
                    logger.error("❌ 无法读取Sounds目录: \(error)")
                }
            } else {
                logger.error("❌ Sounds目录不存在")
            }
        }
        
        // 尝试从Sounds目录中加载音效文件
        if let soundPath = Bundle.main.path(forResource: soundName, ofType: "caf", inDirectory: "Sounds") {
            logger.info("✅ 在Sounds目录中找到音频文件: \(soundPath)")
            let soundURL = URL(fileURLWithPath: soundPath)
            playAudioFile(at: soundURL)
        } else if let soundPath = Bundle.main.path(forResource: soundName, ofType: "caf") {
            logger.info("✅ 在根目录中找到音频文件: \(soundPath)")
            let soundURL = URL(fileURLWithPath: soundPath)
            playAudioFile(at: soundURL)
        } else {
            logger.error("❌ 找不到音频文件: \(soundName).caf")
            logger.info("🔄 尝试播放系统声音作为备选")
            AudioServicesPlaySystemSound(1007)
        }
    }
    
    private func playAudioFile(at url: URL) {
        print("🎶 尝试播放音频文件: \(url.path)")
        logger.info("🎶 尝试播放音频文件: \(url.path)")
        
        // 配置音频会话
        configureAudioSession()
        
        // 检查文件是否存在
        if !FileManager.default.fileExists(atPath: url.path) {
            print("❌ 音频文件不存在: \(url.path)")
            logger.error("❌ 音频文件不存在: \(url.path)")
            AudioServicesPlaySystemSound(1007)
            return
        }
        
        // 检查文件大小，如果太小可能是占位符文件
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            print("📏 音频文件大小: \(fileSize) 字节")
            logger.info("📏 音频文件大小: \(fileSize) 字节")
            
            if fileSize < 1000 {
                print("⚠️ 文件太小，可能是占位符文件，使用系统声音")
                logger.info("⚠️ 文件太小，可能是占位符文件，使用系统声音")
                AudioServicesPlaySystemSound(1007)
                return
            }
        } catch {
            print("❌ 无法获取文件属性: \(error)")
            logger.error("❌ 无法获取文件属性: \(error)")
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            print("✅ AVAudioPlayer创建成功")
            logger.info("✅ AVAudioPlayer创建成功")
            
            audioPlayer?.prepareToPlay()
            print("✅ 音频预加载完成")
            logger.info("✅ 音频预加载完成")
            
            audioPlayer?.volume = 1.0
            print("🔊 音量设置为: \(audioPlayer?.volume ?? 0)")
            logger.info("🔊 音量设置为: \(audioPlayer?.volume ?? 0)")
            
            let success = audioPlayer?.play() ?? false
            if success {
                print("✅ 音频开始播放")
                print("⏱️ 音频时长: \(audioPlayer?.duration ?? 0)秒")
                logger.info("✅ 音频开始播放")
                logger.info("⏱️ 音频时长: \(audioPlayer?.duration ?? 0)秒")
            } else {
                print("❌ 音频播放失败")
                logger.error("❌ 音频播放失败")
                AudioServicesPlaySystemSound(1007)
            }
        } catch {
            print("❌ 音频播放错误: \(error.localizedDescription)")
            logger.error("❌ 音频播放错误: \(error.localizedDescription)")
            AudioServicesPlaySystemSound(1007)
        }
        print("=== AUDIO DEBUG END ===")
    }
    
    private func playCustomSound() {
        logger.info("🎵 开始播放自定义音乐")
        guard let url = customSoundURL else { 
            logger.error("❌ 自定义音频URL为空")
            return 
        }
        
        logger.info("🔍 自定义音频路径: \(url.path)")
        
        // 配置音频会话
        configureAudioSession()
        
        // 停止当前播放的音效
        audioPlayer?.stop()
        
        // 检查文件是否存在
        if !FileManager.default.fileExists(atPath: url.path) {
            logger.error("❌ 自定义音频文件不存在: \(url.path)")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            logger.info("✅ 自定义音频AVAudioPlayer创建成功")
            
            audioPlayer?.prepareToPlay()
            logger.info("✅ 自定义音频预加载完成")
            
            audioPlayer?.volume = 1.0
            logger.info("🔊 自定义音频音量设置为: \(audioPlayer?.volume ?? 0)")
            
            let success = audioPlayer?.play() ?? false
            if success {
                logger.info("✅ 自定义音频开始播放")
                logger.info("⏱️ 自定义音频时长: \(audioPlayer?.duration ?? 0)秒")
            } else {
                logger.error("❌ 自定义音频播放失败")
            }
        } catch {
            logger.error("❌ 自定义音频播放错误: \(error.localizedDescription)")
        }
    }
}

struct SoundRow: View {
    let sound: ReminderSound
    let isSelected: Bool
    let customSoundName: String?
    let onSelect: () -> Void
    let onPlay: (() -> Void)?
    
    init(sound: ReminderSound, isSelected: Bool, customSoundName: String? = nil, onSelect: @escaping () -> Void, onPlay: (() -> Void)? = nil) {
        self.sound = sound
        self.isSelected = isSelected
        self.customSoundName = customSoundName
        self.onSelect = onSelect
        self.onPlay = onPlay
    }
    
    var body: some View {
        HStack {
            Image(systemName: sound.icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(sound.displayName)
                    .font(.body)
                
                if sound == .custom, let fileName = customSoundName {
                    Text(fileName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 添加播放按钮
            if let onPlay = onPlay {
                Button(action: onPlay) {
                    Image(systemName: "play.circle")
                        .foregroundColor(.blue)
                        .font(.title2)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
}

#if os(iOS)
struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedURL: URL?
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.audio])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            // 复制文件到应用的Documents目录
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let destinationURL = documentsPath.appendingPathComponent(url.lastPathComponent)
            
            do {
                // 如果文件已存在，先删除
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                
                // 复制文件
                try FileManager.default.copyItem(at: url, to: destinationURL)
                parent.selectedURL = destinationURL
                print("自定义音频文件已保存到: \(destinationURL.path)")
            } catch {
                print("复制音频文件失败: \(error.localizedDescription)")
            }
        }
    }
}
#endif

#Preview {
    SoundSelectionView(
        selectedSound: .constant(.defaultSound),
        customSoundURL: .constant(nil)
    )
}