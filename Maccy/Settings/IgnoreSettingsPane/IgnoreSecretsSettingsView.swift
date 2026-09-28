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
        Stepper("", value: $secretExpiryMinutes, in: 1...1_440)
          .labelsHidden()
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
      secretExpiryMinutes = min(max(newValue, 1), 1_440)
    }
  }
}

#Preview {
  IgnoreSecretsSettingsView()
    .environment(\.locale, .init(identifier: "en"))
}
