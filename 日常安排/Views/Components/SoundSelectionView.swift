import SwiftUI
import AVFoundation
import AudioToolbox
import Foundation
#if canImport(UIKit)
import UIKit
#endif

struct SoundSelectionView: View {
    @Binding var selectedSound: ReminderSound
    @Binding var customSoundURL: URL?
    @State private var isShowingDocumentPicker = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var avPlayer: AVPlayer?
    
    
    var body: some View {
        NavigationStack {
            VStack {
                // 调试信息移除
                
                List {
                    Section("系统铃声") {
                        ForEach(ReminderSound.allCases.filter { $0 != .custom }, id: \.id) { sound in
                            SoundRow(
                                sound: sound,
                                isSelected: selectedSound == sound,
                                onSelect: {
                                    selectedSound = sound
                                    playSound(sound)
                                },
                                onPlay: {
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
                                selectedSound = .custom
                                isShowingDocumentPicker = true
                            },
                            onPlay: customSoundURL != nil ? {
                                playCustomSound()
                            } : nil
                        )
                        
                        if selectedSound == .custom && customSoundURL != nil {
                            Button("播放自定义音乐") {
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
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)
        } catch {
            // 音频会话失败时保持静默，避免干扰用户
        }
    }
    
    private func playSound(_ sound: ReminderSound) {
        guard sound != .custom else { return }
        
        // 配置音频会话
        configureAudioSession()
        
        // 停止当前播放的音效
        audioPlayer?.stop()
        
        if sound == .defaultSound {
            // 优先播放内置短音作为默认（更可靠），找不到再回退系统声音
            if let url = Bundle.main.url(forResource: "note", withExtension: "caf")
                ?? Bundle.main.url(forResource: "bell", withExtension: "caf") {
                playAudioFile(at: url)
            } else {
                AudioServicesPlaySystemSound(1007)
            }
            return
        }
        
        guard let soundName = sound.systemSoundName else { return }
        
        // 统一使用 URL 方式，优先根目录，再次尝试 Sounds 子目录，并兼容 wav
        let url = Bundle.main.url(forResource: soundName, withExtension: "caf")
            ?? Bundle.main.url(forResource: soundName, withExtension: "caf", subdirectory: "Sounds")
            ?? Bundle.main.url(forResource: soundName, withExtension: "wav")
            ?? Bundle.main.url(forResource: soundName, withExtension: "wav", subdirectory: "Sounds")

        if let url = url {
            playAudioFile(at: url)
        } else {
            AudioServicesPlaySystemSound(1007)
        }
    }
    
    private func playAudioFile(at url: URL) {
        
        // 配置音频会话
        configureAudioSession()
        
        // 检查文件是否存在
        if !FileManager.default.fileExists(atPath: url.path) {
            AudioServicesPlaySystemSound(1007)
            return
        }
        
        // 读取音频时长，长音频使用 AVPlayer 播放更稳（避免 AVAudioPlayer 载入大文件失败）
        let asset = AVURLAsset(url: url)
        let durationSeconds = CMTimeGetSeconds(asset.duration)
        if durationSeconds.isFinite && durationSeconds > 30 {
            avPlayer?.pause()
            avPlayer = AVPlayer(url: url)
            avPlayer?.play()
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            
            audioPlayer?.prepareToPlay()
            
            audioPlayer?.volume = 1.0
            
            let success = audioPlayer?.play() ?? false
            if !success {
                avPlayer?.pause()
                avPlayer = AVPlayer(url: url)
                avPlayer?.play()
            }
        } catch {
            avPlayer?.pause()
            avPlayer = AVPlayer(url: url)
            avPlayer?.play()
        }
    }
    
    private func playCustomSound() {
        guard let url = customSoundURL else { return }
        
        // 配置音频会话
        configureAudioSession()
        
        // 停止当前播放的音效
        audioPlayer?.stop()
        
        // 检查文件是否存在
        if !FileManager.default.fileExists(atPath: url.path) { return }
        
        // 根据时长选择播放器，并在 AVAudioPlayer 失败时回退到 AVPlayer
        let asset = AVURLAsset(url: url)
        let durationSeconds = CMTimeGetSeconds(asset.duration)
        if durationSeconds.isFinite && durationSeconds > 30 {
            avPlayer?.pause()
            avPlayer = AVPlayer(url: url)
            avPlayer?.play()
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            
            audioPlayer?.prepareToPlay()
            
            audioPlayer?.volume = 1.0
            
            let success = audioPlayer?.play() ?? false
            if !success {
                avPlayer?.pause()
                avPlayer = AVPlayer(url: url)
                avPlayer?.play()
            }
        } catch {
            avPlayer?.pause()
            avPlayer = AVPlayer(url: url)
            avPlayer?.play()
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
            } catch {
                // 复制失败时保持静默，避免调试信息污染输出
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