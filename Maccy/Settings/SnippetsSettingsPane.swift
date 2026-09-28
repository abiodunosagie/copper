import Defaults
import SwiftUI

// Settings > Snippets: add, edit and delete saved text.
struct SnippetsSettingsPane: View {
  @Default(.snippets) private var snippets
  @State private var selection: Snippet.ID?

  private var selectedIndex: Int? {
    snippets.firstIndex { $0.id == selection }
  }

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading) {
        List(selection: $selection) {
          ForEach(snippets) { snippet in
            Text(snippet.name.isEmpty ? NSLocalizedString("snippet_untitled", comment: "") : snippet.name)
              .tag(snippet.id)
          }
        }
        .frame(width: 180, height: 260)

        ControlGroup {
          Button("", systemImage: "plus") {
            let snippet = Snippet(name: NSLocalizedString("snippet_new", comment: ""), body: "")
            snippets.append(snippet)
            selection = snippet.id
          }
          Button("", systemImage: "minus") {
            snippets.removeAll { $0.id == selection }
            selection = nil
          }
          .disabled(selection == nil)
        }
        .frame(width: 50)
      }

      if let index = selectedIndex {
        VStack(alignment: .leading, spacing: 8) {
          TextField(text: $snippets[index].name) {
            Text("snippet_name")
          }
          TextEditor(text: $snippets[index].body)
            .font(.system(.body, design: .monospaced))
            .frame(height: 200)
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.secondary.opacity(0.3)))
          Text(String(
            format: NSLocalizedString("snippet_placeholders", comment: ""),
            Snippet.placeholders.joined(separator: " ")
          ))
            .foregroundStyle(.gray)
            .controlSize(.small)
        }
        .frame(width: 320)
      } else {
        Text("snippet_empty")
          .foregroundStyle(.gray)
          .frame(width: 320, height: 260)
      }
    }
    .padding()
  }
}
