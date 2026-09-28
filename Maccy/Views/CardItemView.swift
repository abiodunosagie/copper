import AppKit
import Defaults
import SwiftHEXColors
import SwiftUI

extension Color {
  // Copper's accent, used for the selected card, shortcuts and pins.
  static let copper = Color(red: 0.816, green: 0.541, blue: 0.333)
}

// One history item drawn as a card in the docked panel: app icon, shortcut and age on top,
// the content in the middle (text, image, link or color) and details at the bottom.
struct CardItemView: View {
  static let cornerRadius: CGFloat = 14
  static let spacing: CGFloat = 8

  @Bindable var item: HistoryItemDecorator
  var isSelected: Bool
  var selectionIndex: Int?

  @Environment(ModifierFlags.self) private var modifierFlags
  @Environment(\.colorScheme) private var colorScheme

  private var contentText: String { item.item.previewableText }

  private var linkURL: URL? { Self.linkURL(in: contentText) }

  // A single web address, with or without "https://" ("www.example.com" counts too).
  static func linkURL(in text: String) -> URL? {
    var candidate = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !candidate.isEmpty, !candidate.contains(where: \.isWhitespace) else { return nil }
    if candidate.lowercased().hasPrefix("www.") {
      candidate = "https://" + candidate
    }
    guard let url = URL(string: candidate), let scheme = url.scheme?.lowercased(),
          ["http", "https"].contains(scheme), let host = url.host, host.contains(".") else { return nil }
    return url
  }

  private var swatchColor: NSColor? {
    let text = contentText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard text.hasPrefix("#"), text.count == 7 || text.count == 4 else { return nil }
    return NSColor(hexString: text)
  }

  private var detail: String {
    if item.item.expiresAt != nil {
      return NSLocalizedString("card_secret_detail", comment: "")
    }
    if let image = item.item.image {
      let size = image.pixelSize
      return "\(Int(size.width)) × \(Int(size.height))"
    }
    let text = contentText
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false).count
    let characters = String(format: NSLocalizedString("card_characters", comment: ""), text.count)
    return lines > 1 ? characters + " · " + String(format: NSLocalizedString("card_lines", comment: ""), lines) : characters
  }

  private var cardBackground: Color {
    colorScheme == .dark ? Color.white.opacity(isSelected ? 0.11 : 0.06) : Color.black.opacity(isSelected ? 0.07 : 0.04)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      header
      content
      footer
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(cardBackground, in: RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
        .strokeBorder(isSelected ? Color.copper : Color.primary.opacity(0.08), lineWidth: isSelected ? 2 : 1)
    }
    .contentShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
  }

  private var header: some View {
    HStack(spacing: 8) {
      AppImageView(appImage: item.applicationImage, size: NSSize(width: 24, height: 24))

      if let shortcut = item.shortcuts.first(where: { $0.isVisible(item.shortcuts, modifierFlags.flags) })
          ?? item.shortcuts.first {
        KeyboardShortcutView(shortcut: shortcut)
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(Color.copper)
      }

      if let selectionIndex {
        Text("\(selectionIndex + 1)")
          .font(.caption.weight(.semibold))
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(Color.copper, in: Capsule())
          .foregroundStyle(.white)
      }

      Spacer(minLength: 4)

      if item.isPinned {
        Image(systemName: "pin.fill")
          .font(.system(size: 11))
          .foregroundStyle(Color.copper)
          .accessibilityHidden(true)
      }

      Text(Self.age(of: item.item.lastCopiedAt))
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }
  }

  @ViewBuilder
  private var content: some View {
    if let image = item.item.image {
      Image(nsImage: image)
        .resizable()
        .scaledToFit()
        .frame(maxWidth: .infinity, maxHeight: 150)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    } else if let color = swatchColor {
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(Color(nsColor: color))
        .frame(height: 64)
        .overlay(alignment: .bottomLeading) {
          Text(contentText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .foregroundStyle(color.brightnessComponent > 0.6 ? .black : .white)
            .padding(8)
        }
    } else if let url = linkURL {
      VStack(alignment: .leading, spacing: 4) {
        Text(url.host(percentEncoded: false) ?? url.absoluteString)
          .font(.system(size: 14, weight: .semibold))
          .lineLimit(1)
        Text(url.absoluteString)
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
          .lineLimit(2)
          .truncationMode(.middle)
      }
    } else if item.item.expiresAt != nil {
      Text(Self.masked(contentText))
        .font(.system(size: 14, design: .monospaced))
        .lineLimit(1)
    } else {
      Text(item.title.isEmpty ? contentText : item.title)
        .font(.system(size: 14))
        .lineLimit(4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var footer: some View {
    HStack(spacing: 6) {
      if let expiresAt = item.item.expiresAt {
        Image(systemName: "timer")
          .accessibilityHidden(true)
        Text(String(format: NSLocalizedString("card_secret_expires", comment: ""), Self.remaining(until: expiresAt)))
      } else {
        Text(detail)
      }
      Spacer(minLength: 0)
    }
    .font(.system(size: 11))
    .foregroundStyle(item.item.expiresAt != nil ? Color.copper : .secondary)
  }

  // "now", "5m", "3h", "2d": the compact age shown on each card.
  static func age(of date: Date, until now: Date = .now) -> String {
    let seconds = max(0, Int(now.timeIntervalSince(date)))
    switch seconds {
    case ..<60: return NSLocalizedString("card_age_now", comment: "")
    case ..<3_600: return "\(seconds / 60)m"
    case ..<86_400: return "\(seconds / 3_600)h"
    default: return "\(seconds / 86_400)d"
    }
  }

  // "1m", "45m", "2h": time left before a secret is deleted, rounded up so it never shows 0.
  static func remaining(until date: Date, now: Date = .now) -> String {
    let minutes = max(1, Int((date.timeIntervalSince(now) / 60).rounded(.up)))
    return minutes < 60 ? "\(minutes)m" : "\(minutes / 60)h"
  }

  // Shows the first 8 characters of a secret, the rest as dots.
  static func masked(_ text: String) -> String {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return String(trimmed.prefix(8)) + String(repeating: "•", count: min(12, max(0, trimmed.count - 8)))
  }
}
