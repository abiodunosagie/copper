import Defaults
import SwiftUI

// Settings for sending items to Copper on other Macs.
struct PeerShareSettingsView: View {
  @Default(.peerShareEnabled) private var enabled
  @Default(.peerShareName) private var name

  @State private var code = ""
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
        TextField(Host.current().localizedName ?? "Mac", text: $name)
          .frame(width: 180)
      }

      HStack {
        Text("PeerShareCode", tableName: "GeneralSettings")
        SecureField("", text: $code)
          .frame(width: 180)
          .accessibilityLabel(Text("PeerShareCode", tableName: "GeneralSettings"))
        Button {
          saveCode()
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

  private func saveCode() {
    guard PeerPairing.isValid(code) else {
      message = "PeerShareCodeTooShort"
      return
    }
    PeerPairing.code = code
    code = ""
    hasSavedCode = true
    message = "PeerShareCodeSaved"
    PeerShareService.shared.update()
  }
}
