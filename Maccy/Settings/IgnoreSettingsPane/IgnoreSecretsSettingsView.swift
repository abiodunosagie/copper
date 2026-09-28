import SwiftUI
import Defaults

struct IgnoreSecretsSettingsView: View {
  @Default(.secretHandling) private var secretHandling
  @Default(.secretExpiryMinutes) private var secretExpiryMinutes
  @Default(.clearSecretFromClipboardSeconds) private var clearSeconds
  @Default(.pauseInSensitiveApps) private var pauseInSensitiveApps

  private let clearChoices = [0, 30, 60, 120, 300]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Picker(selection: $secretHandling) {
        ForEach(SecretHandling.allCases) { handling in
          Text(handling.description)
        }
      } label: {
        Text("SecretHandlingLabel", tableName: "IgnoreSettings")
      }
      .pickerStyle(.radioGroup)

      HStack {
        Text("SecretExpiryLabel", tableName: "IgnoreSettings")
        TextField("", value: $secretExpiryMinutes, format: .number)
          .frame(width: 50)
          .multilineTextAlignment(.trailing)
          .accessibilityLabel(Text("SecretExpiryLabel", tableName: "IgnoreSettings"))
        Stepper("", value: $secretExpiryMinutes, in: SecretDetector.expiryMinutesRange)
          .labelsHidden()
          .accessibilityLabel(Text("SecretExpiryLabel", tableName: "IgnoreSettings"))
        Text("SecretExpiryUnit", tableName: "IgnoreSettings")
      }
      .disabled(secretHandling != .expire)

      Picker(selection: $clearSeconds) {
        ForEach(clearChoices, id: \.self) { seconds in
          Text(clearLabel(seconds))
        }
      } label: {
        Text("SecretClearLabel", tableName: "IgnoreSettings")
      }
      .frame(width: 320)

      Toggle(isOn: $pauseInSensitiveApps) {
        Text("PauseInSensitiveApps", tableName: "IgnoreSettings")
      }

      Text("SecretsDescription", tableName: "IgnoreSettings")
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(.gray)
        .controlSize(.small)

      Spacer()
    }
    .padding()
    .onChange(of: secretExpiryMinutes) { _, newValue in
      let range = SecretDetector.expiryMinutesRange
      secretExpiryMinutes = min(max(newValue, range.lowerBound), range.upperBound)
    }
  }
}

extension IgnoreSecretsSettingsView {
  func clearLabel(_ seconds: Int) -> String {
    switch seconds {
    case 0: return NSLocalizedString("SecretClearNever", tableName: "IgnoreSettings", comment: "")
    case ..<60:
      return String(format: NSLocalizedString("SecretClearSeconds", tableName: "IgnoreSettings", comment: ""), seconds)
    default:
      return String(format: NSLocalizedString("SecretClearMinutes", tableName: "IgnoreSettings", comment: ""), seconds / 60)
    }
  }
}

#Preview {
  IgnoreSecretsSettingsView()
    .environment(\.locale, .init(identifier: "en"))
}
