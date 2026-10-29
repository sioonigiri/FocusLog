import AudioToolbox
import Foundation
import UserNotifications

/// タイマー終了時に鳴らす音。設定画面で選ぶ。
enum AlarmSound: String, CaseIterable, Identifiable {
    case standard, chime, bell, digital, marimba

    var id: String { rawValue }

    var name: String {
        switch self {
        case .standard: "標準"
        case .chime: "チャイム"
        case .bell: "ベル"
        case .digital: "電子音"
        case .marimba: "マリンバ"
        }
    }

    /// アプリに入れている音のファイル名。標準はiOSの音を使うのでなし。
    private var fileName: String? {
        self == .standard ? nil : "\(rawValue).wav"
    }

    /// アプリを開いているときに鳴らす音。
    /// システムサウンドとして鳴らすので、マナーモード中は鳴らずバイブだけになる。
    @MainActor
    var systemSoundID: SystemSoundID {
        if let cached = Self.soundIDs[self] { return cached }
        var soundID: SystemSoundID = 1005
        if let fileName, let url = Bundle.main.url(forResource: fileName, withExtension: nil) {
            AudioServicesCreateSystemSoundID(url as CFURL, &soundID)
        }
        Self.soundIDs[self] = soundID
        return soundID
    }

    @MainActor private static var soundIDs: [AlarmSound: SystemSoundID] = [:]

    /// アプリを閉じているときの通知の音。
    var notificationSound: UNNotificationSound {
        fileName.map { UNNotificationSound(named: UNNotificationSoundName($0)) } ?? .default
    }
}

enum AppSettings {
    static let soundKey = "soundEnabled"
    static let vibrationKey = "vibrationEnabled"
    static let alarmSoundKey = "alarmSound"

    static var alarmSound: AlarmSound {
        AlarmSound(rawValue: UserDefaults.standard.string(forKey: alarmSoundKey) ?? "") ?? .standard
    }

    static var soundEnabled: Bool {
        UserDefaults.standard.object(forKey: soundKey) as? Bool ?? true
    }

    static var vibrationEnabled: Bool {
        UserDefaults.standard.object(forKey: vibrationKey) as? Bool ?? true
    }
}

/// タイマー終了時のアラーム。完了画面でチェックマークをスライドするまで、サウンドとバイブを繰り返す。
@MainActor
enum Feedback {
    /// 鳴らす間隔（秒）。一番長い音（約2秒）が重ならない長さにしている。
    private static let interval: TimeInterval = 2.5
    /// 止め忘れても鳴り続けないように、この時間で自動的に止める（秒）。
    static let maxDuration: TimeInterval = 60

    private static var repeater: Timer?

    /// アラームが鳴り続けている間はtrue。
    static var isRinging: Bool { repeater != nil }

    /// アプリを開いている間にタイマーが終わったときに鳴らし始める。
    static func startAlarm() {
        stopAlarm()
        guard AppSettings.soundEnabled || AppSettings.vibrationEnabled else { return }
        let startedAt = Date()
        ring()
        repeater = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            MainActor.assumeIsolated {
                if Date().timeIntervalSince(startedAt) >= maxDuration {
                    stopAlarm()
                } else {
                    ring()
                }
            }
        }
    }

    static func stopAlarm() {
        repeater?.invalidate()
        repeater = nil
    }

    /// 設定画面で音を選んだときの試し聞き。
    static func preview(_ sound: AlarmSound) {
        AudioServicesPlaySystemSound(sound.systemSoundID)
    }

    private static func ring() {
        if AppSettings.soundEnabled {
            AudioServicesPlaySystemSound(AppSettings.alarmSound.systemSoundID)
        }
        if AppSettings.vibrationEnabled {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
    }
}
