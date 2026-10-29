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
                    Text("マナーモード中は音が鳴らず、バイブレーションのみになります。通知をオフにしている場合は、音もバイブレーションも鳴りません。")
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
