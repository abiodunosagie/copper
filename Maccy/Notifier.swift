import AppKit
import Defaults
import UserNotifications

class Notifier {
  private static var center: UNUserNotificationCenter { UNUserNotificationCenter.current() }

  static func authorize() {
    center.requestAuthorization(options: [.alert, .sound]) { _, error in
      if error != nil {
        NSLog("Failed to authorize notifications: \(String(describing: error))")
      }
    }
  }

  // Plays Copper's copy sound. It does not depend on notification permission: Copper is a
  // different app from Maccy to macOS, so tying the sound to notifications silenced it.
  static func playSound(_ sound: NSSound?) {
    guard Defaults[.playSounds], let sound else { return }
    DispatchQueue.main.async {
      // Restart instead of skipping when copies come in quick succession.
      sound.stop()
      sound.play()
    }
  }

  static func notify(body: String?, sound: NSSound?) {
    guard let body else { return }

    playSound(sound)
    authorize()

    center.getNotificationSettings { settings in
      guard (settings.authorizationStatus == .authorized) ||
            (settings.authorizationStatus == .provisional) else { return }

      let content = UNMutableNotificationContent()
      if settings.alertSetting == .enabled {
        content.body = body
      }

      let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
      center.add(request) { error in
        if error != nil {
          NSLog("Failed to deliver notification: \(String(describing: error))")
        }
      }
    }
  }
}
