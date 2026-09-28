import SwiftUI
import Defaults

struct IgnoreSecretsSettingsView: View {
  @Default(.secretHandling) private var secretHandling
  @Default(.secretExpiryMinutes) private var secretExpiryMinutes

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

#Preview {
  IgnoreSecretsSettingsView()
    .environment(\.locale, .init(identifier: "en"))
}
