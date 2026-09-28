import Defaults
import SwiftUI

// Settings > Ignore > Folders: files copied from these folders are not recorded.
struct IgnoreFoldersSettingsView: View {
  @Default(.ignoredFolders) private var folders
  @State private var selection: String?

  var body: some View {
    VStack(alignment: .leading) {
      List(selection: $selection) {
        ForEach(folders, id: \.self) { folder in
          Label(folder, systemImage: "folder").tag(folder)
        }
      }
      .onDeleteCommand {
        folders.removeAll { $0 == selection }
      }

      ControlGroup {
        Button("", systemImage: "plus") {
          addFolders()
        }
        Button("", systemImage: "minus") {
          folders.removeAll { $0 == selection }
          selection = nil
        }
        .disabled(selection == nil)
      }
      .frame(width: 50)

      Text("IgnoredFoldersDescription", tableName: "IgnoreSettings")
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(.gray)
        .controlSize(.small)
    }
    .padding()
  }

  private func addFolders() {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = true
    panel.prompt = NSLocalizedString("IgnoredFoldersAdd", tableName: "IgnoreSettings", comment: "")
    guard panel.runModal() == .OK else { return }
    for url in panel.urls where !folders.contains(url.path(percentEncoded: false)) {
      folders.append(url.path(percentEncoded: false))
    }
  }
}
