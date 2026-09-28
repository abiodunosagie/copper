import AppKit
import SwiftUI

// One history item as a card in the docked panel, in the approved Copper design:
// app icon, type and age on top; the content in the middle; details and the shortcut badge below.
struct CardItemView: View {
  static let spacing: CGFloat = 10
  static let secretPreviewLength = 8
  static let maxMaskedDots = 12
  static let imageMaxHeight: CGFloat = 140

  @Bindable var item: HistoryItemDecorator
  var isSelected: Bool
  var selectionIndex: Int?

  @Environment(ModifierFlags.self) private var modifierFlags

  private var contentText: String { item.item.previewableText }

  var body: some View {
    // Classify once per render; header, content and footer all depend on it.
    let kind = ContentKind.of(item.item)
    VStack(alignment: .leading, spacing: 10) {
      header(kind)
      content(kind)
      footer(kind)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      isSelected ? DockTheme.cardSelected : DockTheme.card,
      in: RoundedRectangle(cornerRadius: DockTheme.cardCornerRadius, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: DockTheme.cardCornerRadius, style: .continuous)
        .strokeBorder(isSelected ? DockTheme.accent : DockTheme.border, lineWidth: isSelected ? 2 : 1)
    }
    .contentShape(RoundedRectangle(cornerRadius: DockTheme.cardCornerRadius, style: .continuous))
  }

  private func header(_ kind: ContentKind) -> some View {
    HStack(spacing: 7) {
      AppImageView(appImage: item.applicationImage, size: NSSize(width: 20, height: 20))
      Text(kind.title)
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(DockTheme.secondaryText)

      if let selectionIndex {
        Text("\(selectionIndex + 1)")
          .font(.system(size: 11, weight: .semibold))
          .padding(.horizontal, 6)
          .padding(.vertical, 1)
          .background(DockTheme.accent, in: Capsule())
          .foregroundStyle(DockTheme.onAccent)
      }

      Spacer(minLength: 4)

      if item.isPinned {
        Image(systemName: "pin.fill")
          .font(.system(size: 10))
          .foregroundStyle(DockTheme.accent)
          .accessibilityHidden(true)
      }
      Text(Self.age(of: item.item.lastCopiedAt))
        .font(.system(size: 11))
        .foregroundStyle(DockTheme.mutedText)
    }
  }

  @ViewBuilder
  private func content(_ kind: ContentKind) -> some View {
    switch kind {
    case .image:
      imageContent
    case .color(let color):
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(Color(nsColor: color))
        .frame(height: 72)
        .overlay(alignment: .bottomLeading) {
          Text(contentText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())
            .font(.system(size: 14, weight: .medium, design: .monospaced))
            .foregroundStyle(color.brightnessComponent > 0.6 ? Color.black : Color.white)
            .padding(10)
        }
    case .link(let url):
      VStack(alignment: .leading, spacing: 4) {
        Text(url.host(percentEncoded: false) ?? url.absoluteString)
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(DockTheme.text)
          .lineLimit(1)
        Text(url.absoluteString)
          .font(.system(size: 12))
          .foregroundStyle(DockTheme.mutedText)
          .lineLimit(2)
          .truncationMode(.middle)
      }
    case .code:
      Text(contentText)
        .font(.system(size: 12, design: .monospaced))
        .foregroundStyle(DockTheme.codeText)
        .lineLimit(6)
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DockTheme.codeBackground, in: RoundedRectangle(cornerRadius: 8))
    case .secret:
      Text(Self.masked(contentText))
        .font(.system(size: 14, design: .monospaced))
        .foregroundStyle(DockTheme.text)
        .lineLimit(1)
    case .text, .file:
      Text(item.title.isEmpty ? contentText : item.title)
        .font(.system(size: 13))
        .foregroundStyle(DockTheme.text)
        .lineLimit(4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  @ViewBuilder
  private var imageContent: some View {
    VStack(alignment: .leading, spacing: 6) {
      if let image = item.item.image {
        Image(nsImage: image)
          .resizable()
          .scaledToFit()
          .frame(maxWidth: .infinity, maxHeight: Self.imageMaxHeight)
          .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
      }
      // For images the title holds the text recognized in them.
      if !item.title.isEmpty {
        Text(String(format: NSLocalizedString("card_text_found", comment: ""), item.title))
          .font(.system(size: 12))
          .foregroundStyle(DockTheme.secondaryText)
          .lineLimit(2)
      }
    }
  }

  private func footer(_ kind: ContentKind) -> some View {
    let isSecret = kind == .secret
    return HStack(spacing: 6) {
      if isSecret, let expiresAt = item.item.expiresAt {
        Image(systemName: "timer")
          .accessibilityHidden(true)
        Text(String(format: NSLocalizedString("card_secret_expires", comment: ""), Self.remaining(until: expiresAt)))
      } else {
        Text(detail(kind))
      }

      Spacer(minLength: 4)

      if let shortcut = visibleShortcut {
        KeyboardShortcutView(shortcut: shortcut)
          .font(.system(size: 11, design: .monospaced))
          .padding(.horizontal, 6)
          .padding(.vertical, 1)
          .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(DockTheme.controlBorder))
      }
    }
    .font(.system(size: 11))
    .foregroundStyle(isSecret ? DockTheme.accent : DockTheme.mutedText)
  }

  private var visibleShortcut: KeyShortcut? {
    item.shortcuts.first { $0.isVisible(item.shortcuts, modifierFlags.flags) } ?? item.shortcuts.first
  }

  private func detail(_ kind: ContentKind) -> String {
    switch kind {
    case .image:
      guard let size = item.item.image?.pixelSize else { return "" }
      return "\(Int(size.width)) × \(Int(size.height))"
    case .color(let color):
      let rgb = color.usingColorSpace(.sRGB) ?? color
      return "rgb(\(Int(rgb.redComponent * 255)), \(Int(rgb.greenComponent * 255)), \(Int(rgb.blueComponent * 255)))"
    case .link:
      return item.application ?? ""
    default:
      let text = contentText
      let lines = text.split(separator: "\n", omittingEmptySubsequences: false).count
      let characters = String(format: NSLocalizedString("card_characters", comment: ""), text.count)
      guard lines > 1 else { return characters }
      return characters + " · " + String(format: NSLocalizedString("card_lines", comment: ""), lines)
    }
  }

  // "now", "5m", "3h", "2d": the compact age shown on each card.
  static func age(of date: Date, until now: Date = .now) -> String {
    let seconds = max(0, Int(now.timeIntervalSince(date)))
    switch seconds {
    case ..<60: return NSLocalizedString("card_age_now", comment: "")
    case ..<3_600: return String(format: NSLocalizedString("card_minutes", comment: ""), seconds / 60)
    case ..<86_400: return String(format: NSLocalizedString("card_hours", comment: ""), seconds / 3_600)
    default: return String(format: NSLocalizedString("card_days", comment: ""), seconds / 86_400)
    }
  }

  // Time left before a secret is deleted, rounded up so it never shows 0.
  static func remaining(until date: Date, now: Date = .now) -> String {
    let minutes = max(1, Int((date.timeIntervalSince(now) / 60).rounded(.up)))
    return minutes < 60
      ? String(format: NSLocalizedString("card_minutes", comment: ""), minutes)
      : String(format: NSLocalizedString("card_hours", comment: ""), minutes / 60)
  }

  // Shows the start of a secret, the rest as dots.
  static func masked(_ text: String) -> String {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let dots = min(maxMaskedDots, max(0, trimmed.count - secretPreviewLength))
    return String(trimmed.prefix(secretPreviewLength)) + String(repeating: "•", count: dots)
  }
}
