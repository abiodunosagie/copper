import AppKit
import ImageIO

extension NSImage {
  // PNG bytes for this image, used for previews, link thumbnails and sending to other Macs.
  var pngData: Data? {
    guard let tiff = tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
    return bitmap.representation(using: .png, properties: [:])
  }

  // Pixel size read from the image header without decoding it, so oversized images can be
  // refused before they take memory.
  static func pixelSize(of data: Data) -> CGSize? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = properties[kCGImagePropertyPixelWidth] as? Int,
          let height = properties[kCGImagePropertyPixelHeight] as? Int else { return nil }
    return CGSize(width: width, height: height)
  }
}
