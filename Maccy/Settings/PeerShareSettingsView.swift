import Defaults
import SwiftUI

// Settings for sending items to Copper on other Macs.
struct PeerShareSettingsView: View {
  @Default(.peerShareEnabled) private var enabled

  @State private var name = Defaults[.peerShareName]
  @State private var enteredCode = ""
  @State private var generatedCode: String?
  @State private var hasSavedCode = PeerPairing.code != nil
  @State private var message: LocalizedStringKey?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Toggle(isOn: $enabled) {
        Text("PeerShareEnable", tableName: "GeneralSettings")
      }
      .disabled(!hasSavedCode)

      HStack {
        Text("PeerShareName", tableName: "GeneralSettings")
        TextField(PeerShareService.deviceName, text: $name)
          .frame(width: 180)
          .onSubmit(applyName)
      }

      HStack {
        Button {
          generatedCode = PeerPairing.generateCode()
          if let generatedCode { save(generatedCode) }
        } label: {
          Text("PeerShareGenerate", tableName: "GeneralSettings")
        }
        if let generatedCode {
          Text(verbatim: generatedCode)
            .font(.system(.body, design: .monospaced))
            .textSelection(.enabled)
          Button {
            // Marked concealed so Copper (and other clipboard managers) do not save the code in history.
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(generatedCode, forType: .string)
            NSPasteboard.general.setString("", forType: .concealed)
          } label: {
            Text("PeerShareCopy", tableName: "GeneralSettings")
          }
        }
      }

      HStack {
        Text("PeerShareCode", tableName: "GeneralSettings")
        SecureField("", text: $enteredCode)
          .frame(width: 240)
          .accessibilityLabel(Text("PeerShareCode", tableName: "GeneralSettings"))
        Button {
          save(enteredCode)
        } label: {
          Text("PeerShareSaveCode", tableName: "GeneralSettings")
        }
      }

      if let message {
        Text(message, tableName: "GeneralSettings")
          .controlSize(.small)
      }

      Text("PeerShareDescription", tableName: "GeneralSettings")
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(.gray)
        .controlSize(.small)
    }
  }

  private func applyName() {
    Defaults[.peerShareName] = name.trimmingCharacters(in: .whitespaces)
    PeerShareService.shared.update()
  }

  private func save(_ code: String) {
    guard PeerPairing.isValid(code) else {
      message = "PeerShareCodeInvalid"
      return
    }
    guard PeerPairing.save(code) else {
      message = "PeerShareCodeKeychainFailed"
      return
    }
    enteredCode = ""
    hasSavedCode = true
    message = "PeerShareCodeSaved"
    PeerShareService.shared.update()
  }
}
