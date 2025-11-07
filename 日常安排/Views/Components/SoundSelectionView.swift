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
    @State private var avPlayer: AVPlayer?
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
            // 优先播放内置短音作为默认（更可靠），找不到再回退系统声音
            if let url = Bundle.main.url(forResource: "note", withExtension: "caf")
                ?? Bundle.main.url(forResource: "bell", withExtension: "caf") {
                logger.info("🔔 播放应用内默认音频(note/bell)")
                playAudioFile(at: url)
            } else {
                logger.info("🔔 回退为系统默认通知声音")
                AudioServicesPlaySystemSound(1007)
            }
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
                logger.info("ℹ️ Sounds目录不存在，资源可能已被打包到根目录")
            }
        }
        
        // 统一使用 URL 方式，优先根目录，再次尝试 Sounds 子目录，并兼容 wav
        let url = Bundle.main.url(forResource: soundName, withExtension: "caf")
            ?? Bundle.main.url(forResource: soundName, withExtension: "caf", subdirectory: "Sounds")
            ?? Bundle.main.url(forResource: soundName, withExtension: "wav")
            ?? Bundle.main.url(forResource: soundName, withExtension: "wav", subdirectory: "Sounds")

        if let url = url {
            logger.info("✅ 找到音频文件: \(url.path)")
            playAudioFile(at: url)
        } else {
            logger.error("❌ 找不到音频文件: \(soundName).(caf/wav)")
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
        
        // 检查文件大小，如果太小可能是占位符文件；若是占位符，尝试同名的另一种扩展作为回退
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            print("📏 音频文件大小: \(fileSize) 字节")
            logger.info("📏 音频文件大小: \(fileSize) 字节")
            
            if fileSize < 1000 {
                print("⚠️ 文件太小，可能是占位符文件，尝试扩展名回退")
                logger.info("⚠️ 文件太小，可能是占位符文件，尝试扩展名回退")
                let base = url.deletingPathExtension().lastPathComponent
                let altExt = (url.pathExtension.lowercased() == "caf") ? "wav" : "caf"
                if let altURL = Bundle.main.url(forResource: base, withExtension: altExt) {
                    print("🔄 发现同名回退资源: \(altURL.lastPathComponent)")
                    logger.info("🔄 发现同名回退资源: \(altURL.lastPathComponent)")
                    playAudioFile(at: altURL)
                    return
                }
                print("⚠️ 未找到同名回退资源，使用系统声音")
                logger.info("⚠️ 未找到同名回退资源，使用系统声音")
                AudioServicesPlaySystemSound(1007)
                return
            }
        } catch {
            print("❌ 无法获取文件属性: \(error)")
            logger.error("❌ 无法获取文件属性: \(error)")
        }

        // 读取音频时长，长音频使用 AVPlayer 播放更稳（避免 AVAudioPlayer 载入大文件失败）
        let asset = AVURLAsset(url: url)
        let durationSeconds = CMTimeGetSeconds(asset.duration)
        if durationSeconds.isFinite {
            print("⏱️ 资产时长: \(durationSeconds)秒")
            logger.info("⏱️ 资产时长: \(durationSeconds)秒")
        }
        if durationSeconds.isFinite && durationSeconds > 30 {
            print("🎧 使用 AVPlayer 播放长音频")
            logger.info("🎧 使用 AVPlayer 播放长音频")
            avPlayer?.pause()
            avPlayer = AVPlayer(url: url)
            avPlayer?.play()
            print("✅ AVPlayer开始播放")
            logger.info("✅ AVPlayer开始播放")
            print("=== AUDIO DEBUG END ===")
            return
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
                print("❌ AVAudioPlayer播放失败，尝试使用AVPlayer")
                logger.error("❌ AVAudioPlayer播放失败，尝试使用AVPlayer")
                avPlayer?.pause()
                avPlayer = AVPlayer(url: url)
                avPlayer?.play()
                print("✅ AVPlayer开始播放(AVAudioPlayer失败回退)")
                logger.info("✅ AVPlayer开始播放(AVAudioPlayer失败回退)")
            }
        } catch {
            // 记录更详细错误码并尝试 AVPlayer 回退
            let nsError = error as NSError
            print("❌ AVAudioPlayer错误: code=\(nsError.code), desc=\(nsError.localizedDescription)")
            logger.error("❌ AVAudioPlayer错误: code=\(nsError.code), desc=\(nsError.localizedDescription)")
            print("🔄 尝试使用AVPlayer回退播放")
            logger.info("🔄 尝试使用AVPlayer回退播放")
            avPlayer?.pause()
            avPlayer = AVPlayer(url: url)
            avPlayer?.play()
            print("✅ AVPlayer开始播放(异常回退)")
            logger.info("✅ AVPlayer开始播放(异常回退)")
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
        
        // 根据时长选择播放器，并在 AVAudioPlayer 失败时回退到 AVPlayer
        let asset = AVURLAsset(url: url)
        let durationSeconds = CMTimeGetSeconds(asset.duration)
        if durationSeconds.isFinite && durationSeconds > 30 {
            logger.info("🎧 使用 AVPlayer 播放长自定义音频")
            avPlayer?.pause()
            avPlayer = AVPlayer(url: url)
            avPlayer?.play()
            logger.info("✅ AVPlayer开始播放(自定义)")
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
                logger.error("❌ 自定义音频AVAudioPlayer播放失败，回退AVPlayer")
                avPlayer?.pause()
                avPlayer = AVPlayer(url: url)
                avPlayer?.play()
                logger.info("✅ AVPlayer开始播放(自定义回退)")
            }
        } catch {
            let nsError = error as NSError
            logger.error("❌ 自定义音频AVAudioPlayer错误: code=\(nsError.code), desc=\(nsError.localizedDescription)")
            logger.info("🔄 尝试使用AVPlayer回退播放(自定义)")
            avPlayer?.pause()
            avPlayer = AVPlayer(url: url)
            avPlayer?.play()
            logger.info("✅ AVPlayer开始播放(自定义异常回退)")
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

            // 复制文件到应用的 Library/Sounds 目录（通知支持从此目录加载）
            let libraryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            let soundsDir = libraryURL.appendingPathComponent("Sounds", isDirectory: true)

            do {
                // 创建 Sounds 目录（如不存在）
                if !FileManager.default.fileExists(atPath: soundsDir.path) {
                    try FileManager.default.createDirectory(at: soundsDir, withIntermediateDirectories: true)
                }

                let destURL = soundsDir.appendingPathComponent(url.lastPathComponent)

                // 如果文件已存在，先删除
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.removeItem(at: destURL)
                }

                // 复制文件
                try FileManager.default.copyItem(at: url, to: destURL)
                parent.selectedURL = destURL
                print("自定义音频文件已保存到: \(destURL.path)")

                // 读取时长用于提示通知限制（约30秒）
                if let player = try? AVAudioPlayer(contentsOf: destURL) {
                    let duration = player.duration
                    print("⏱️ 自定义音频时长: \(duration) 秒")
                    if duration > 30.0 {
                        print("⚠️ 提示：通知声音需小于约30秒，超出可能回退为默认音")
                    }
                }
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