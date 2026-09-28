import Defaults
import SwiftUI
import UniformTypeIdentifiers

// Apps that always receive plain text when Copper pastes into them.
struct PlainTextAppsSettingsView: View {
  @Default(.plainTextApps) private var apps

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      ForEach(apps, id: \.self) { bundle in
        HStack {
          Text(verbatim: Self.displayName(for: bundle))
          Spacer()
          Button {
            apps.removeAll { $0 == bundle }
          } label: {
            Image(systemName: "minus.circle")
          }
          .buttonStyle(.borderless)
          .accessibilityLabel(Text("PlainTextAppsRemove", tableName: "GeneralSettings"))
        }
        .frame(width: 260)
      }
      Button {
        addApp()
      } label: {
        Text("PlainTextAppsAdd", tableName: "GeneralSettings")
      }
      Text("PlainTextAppsDescription", tableName: "GeneralSettings")
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(.gray)
        .controlSize(.small)
    }
  }

  static func displayName(for bundle: String) -> String {
    NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle)?
      .deletingPathExtension().lastPathComponent ?? bundle
  }

  private func addApp() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.application]
    panel.directoryURL = URL(filePath: "/Applications")
    panel.allowsMultipleSelection = true
    guard panel.runModal() == .OK else { return }
    for url in panel.urls {
      if let bundle = Bundle(url: url)?.bundleIdentifier, !apps.contains(bundle) {
        apps.append(bundle)
      }
    }
  }
}
