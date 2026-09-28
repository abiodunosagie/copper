import AppKit
import UniformTypeIdentifiers

// Save and open panels plus the password prompt for history backups.
@MainActor
enum BackupActions {
  private static var backupType: UTType {
    UTType(filenameExtension: Backup.fileExtension) ?? .data
  }

  static func exportHistory() {
    let panel = NSSavePanel()
    panel.allowedContentTypes = [backupType]
    panel.nameFieldStringValue = "Copper \(Date.now.formatted(.iso8601.year().month().day())).\(Backup.fileExtension)"
    guard panel.runModal() == .OK, let url = panel.url else { return }

    guard let password = askPassword(
      title: NSLocalizedString("BackupExportPasswordTitle", tableName: "StorageSettings", comment: ""),
      confirm: true
    ) else { return }

    do {
      let archive = Backup.archive(of: History.shared.all.map(\.item))
      try Backup.encrypt(archive, password: password).write(to: url, options: .atomic)
      inform(String(
        format: NSLocalizedString("BackupExportDone", tableName: "StorageSettings", comment: ""),
        archive.items.count
      ))
    } catch {
      inform(error.localizedDescription, style: .warning)
    }
  }

  static func importHistory() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [backupType]
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let url = panel.url else { return }

    guard let password = askPassword(
      title: NSLocalizedString("BackupImportPasswordTitle", tableName: "StorageSettings", comment: ""),
      confirm: false
    ) else { return }

    do {
      let archive = try Backup.decrypt(Data(contentsOf: url), password: password)
      let count = History.shared.restore(archive)
      inform(String(format: NSLocalizedString("BackupImportDone", tableName: "StorageSettings", comment: ""), count))
    } catch {
      inform(error.localizedDescription, style: .warning)
    }
  }

  // Returns nil when cancelled. With `confirm`, the password must be typed twice and match.
  private static func askPassword(title: String, confirm: Bool) -> String? {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = NSLocalizedString("BackupPasswordInfo", tableName: "StorageSettings", comment: "")
    alert.addButton(withTitle: NSLocalizedString("BackupContinue", tableName: "StorageSettings", comment: ""))
    alert.addButton(withTitle: NSLocalizedString("BackupCancel", tableName: "StorageSettings", comment: ""))

    let password = NSSecureTextField(frame: NSRect(x: 0, y: confirm ? 30 : 0, width: 260, height: 24))
    password.placeholderString = NSLocalizedString(
      "BackupPasswordPlaceholder", tableName: "StorageSettings", comment: ""
    )
    let repeated = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
    repeated.placeholderString = NSLocalizedString("BackupRepeatPlaceholder", tableName: "StorageSettings", comment: "")

    let container = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: confirm ? 54 : 24))
    container.addSubview(password)
    if confirm { container.addSubview(repeated) }
    alert.accessoryView = container
    alert.window.initialFirstResponder = password

    while alert.runModal() == .alertFirstButtonReturn {
      let value = password.stringValue
      if value.isEmpty {
        NSSound.beep()
      } else if confirm && value != repeated.stringValue {
        NSSound.beep()
        repeated.stringValue = ""
      } else {
        return value
      }
    }
    return nil
  }

  private static func inform(_ message: String, style: NSAlert.Style = .informational) {
    let alert = NSAlert()
    alert.alertStyle = style
    alert.messageText = message
    alert.runModal()
  }
}
