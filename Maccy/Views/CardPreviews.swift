import AppKit
import PDFKit
import SwiftUI

// Content previews used by CardItemView for the richer kinds.
enum CardPreviews {
  static let maxListedFiles = 4
  static let richTextFontRange: ClosedRange<CGFloat> = 11...18

  // A PDF's first page as an image, from copied PDF data or a readable PDF file.
  static func pdfThumbnail(for item: HistoryItem, width: CGFloat) -> NSImage? {
    let document: PDFDocument?
    if let data = item.contents.first(where: { $0.type == NSPasteboard.PasteboardType.pdf.rawValue })?.value {
      document = PDFDocument(data: data)
    } else if let url = item.fileURLs.first {
      document = PDFDocument(url: url)
    } else {
      document = nil
    }
    guard let page = document?.page(at: 0) else { return nil }
    let bounds = page.bounds(for: .mediaBox)
    let height = width * bounds.height / max(bounds.width, 1)
    return page.thumbnail(of: NSSize(width: width, height: height), for: .mediaBox)
  }

  // Rich text keeps its bold, italic and sizes, but its colors and backgrounds are dropped so it
  // stays readable on a dark card.
  static func readableRichText(_ source: NSAttributedString?) -> AttributedString? {
    guard let source, source.length > 0 else { return nil }
    let text = NSMutableAttributedString(attributedString: source)
    let whole = NSRange(location: 0, length: text.length)
    text.removeAttribute(.foregroundColor, range: whole)
    text.removeAttribute(.backgroundColor, range: whole)
    text.enumerateAttribute(.font, in: whole) { value, range, _ in
      guard let font = value as? NSFont else { return }
      let size = min(max(font.pointSize, richTextFontRange.lowerBound), richTextFontRange.upperBound)
      text.addAttribute(.font, value: NSFontManager.shared.convert(font, toSize: size), range: range)
    }
    return try? AttributedString(text, including: \.appKit)
  }
}

// Plays an animated GIF.
struct AnimatedImageView: NSViewRepresentable {
  let data: Data

  func makeNSView(context: Context) -> NSImageView {
    let view = NSImageView()
    view.animates = true
    view.imageScaling = .scaleProportionallyUpOrDown
    view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
    view.image = NSImage(data: data)
    return view
  }

  func updateNSView(_ view: NSImageView, context: Context) {}
}

// Names and icons of several copied files.
struct FileListView: View {
  let urls: [URL]

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      ForEach(urls.prefix(CardPreviews.maxListedFiles), id: \.self) { url in
        HStack(spacing: 6) {
          Image(nsImage: NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false)))
            .resizable()
            .frame(width: 16, height: 16)
            .accessibilityHidden(true)
          Text(verbatim: url.lastPathComponent)
            .font(.system(size: 12))
            .foregroundStyle(DockTheme.text)
            .lineLimit(1)
            .truncationMode(.middle)
        }
      }
      if urls.count > CardPreviews.maxListedFiles {
        let hidden = urls.count - CardPreviews.maxListedFiles
        Text(String(format: NSLocalizedString("card_more_files", comment: ""), hidden))
          .font(.system(size: 11))
          .foregroundStyle(DockTheme.mutedText)
      }
    }
  }
}
