import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppSettings.soundKey) private var soundEnabled = true
    @AppStorage(AppSettings.vibrationKey) private var vibrationEnabled = true
    @AppStorage(AppSettings.alarmSoundKey) private var alarmSound = AlarmSound.standard

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("FocusLog") {
                    // Proの内容と価格は調整中。決まるまでは押せないようにしておく。
                    LabeledContent("Proにアップグレード") {
                        Text("調整中")
                    }
                }
                Section {
                    Toggle("サウンド", isOn: $soundEnabled)
                    if soundEnabled {
                        Picker("アラーム音", selection: $alarmSound) {
                            ForEach(AlarmSound.allCases) { Text($0.name).tag($0) }
                        }
                        .onChange(of: alarmSound) { _, sound in Feedback.preview(sound) }
                    }
                    Toggle("バイブレーション", isOn: $vibrationEnabled)
                } header: {
                    Text("タイマー終了時")
                } footer: {
                    Text("マナーモード中は音が鳴らず、バイブレーションのみになります。")
                }
                Section("このアプリについて") {
                    LabeledContent("バージョン", value: version)
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}
