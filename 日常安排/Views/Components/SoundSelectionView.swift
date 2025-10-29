import SwiftUI
import AVFoundation
import MediaPlayer
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
    
    var body: some View {
        NavigationView {
            List {
                Section("系统铃声") {
                    ForEach(ReminderSound.allCases.filter { $0 != .custom }, id: \.id) { sound in
                        SoundRow(
                            sound: sound,
                            isSelected: selectedSound == sound,
                            onSelect: {
                                selectedSound = sound
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
                        }
                    )
                    
                    if selectedSound == .custom && customSoundURL != nil {
                        Button("播放自定义音乐") {
                            playCustomSound()
                        }
                        .foregroundColor(.blue)
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
    
    private func playSound(_ sound: ReminderSound) {
        guard sound != .custom else { return }
        
        // 停止当前播放的音效
        audioPlayer?.stop()
        
        if sound == .defaultSound {
            // 播放系统默认通知声音
            AudioServicesPlaySystemSound(1007) // 系统默认通知声音
            return
        }
        
        guard let soundName = sound.systemSoundName else { return }
        
        // 尝试从Sounds目录中加载音效文件
        if let soundPath = Bundle.main.path(forResource: soundName, ofType: "caf", inDirectory: "Sounds") {
            let soundURL = URL(fileURLWithPath: soundPath)
            playAudioFile(at: soundURL)
        } else if let soundPath = Bundle.main.path(forResource: soundName, ofType: "caf") {
            // 如果不在Sounds目录中，尝试从根目录加载
            let soundURL = URL(fileURLWithPath: soundPath)
            playAudioFile(at: soundURL)
        } else {
            // 如果找不到文件，播放系统声音作为备选
            // 使用系统声音
            AudioServicesPlaySystemSound(1007)
        }
    }
    
    private func playAudioFile(at url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            // 播放失败，使用系统声音
            AudioServicesPlaySystemSound(1007)
        }
    }
    
    private func playCustomSound() {
        guard let url = customSoundURL else { return }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
                // 播放失败
            }
    }
}

struct SoundRow: View {
    let sound: ReminderSound
    let isSelected: Bool
    let customSoundName: String?
    let onSelect: () -> Void
    
    init(sound: ReminderSound, isSelected: Bool, customSoundName: String? = nil, onSelect: @escaping () -> Void) {
        self.sound = sound
        self.isSelected = isSelected
        self.customSoundName = customSoundName
        self.onSelect = onSelect
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
            } catch {
                    // 复制失败
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