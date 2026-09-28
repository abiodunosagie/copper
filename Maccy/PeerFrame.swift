import Foundation

// One item sent between Copper apps: a 4-byte big-endian length, then a JSON body.
struct PeerFrame: Codable, Equatable {
  enum Kind: String, Codable {
    case text
    case image
  }

  static let headerLength = 4
  static let maxBodyLength = 10 * 1_024 * 1_024

  var kind: Kind
  var from: String
  var text: String?
  var imagePNG: Data?

  enum FrameError: Error {
    case tooLarge
    case malformed
  }

  func encoded() throws -> Data {
    let body = try JSONEncoder().encode(self)
    guard body.count <= Self.maxBodyLength else { throw FrameError.tooLarge }
    var length = UInt32(body.count).bigEndian
    return Data(bytes: &length, count: Self.headerLength) + body
  }

  // Body length from a header, rejecting anything over the cap before the body is read.
  static func bodyLength(fromHeader header: Data) throws -> Int {
    guard header.count == headerLength else { throw FrameError.malformed }
    let length = header.reduce(0) { ($0 << 8) | Int($1) }
    guard length > 0, length <= maxBodyLength else { throw FrameError.tooLarge }
    return length
  }

  static func decode(body: Data) throws -> PeerFrame {
    guard let frame = try? JSONDecoder().decode(PeerFrame.self, from: body),
          frame.text != nil || frame.imagePNG != nil else { throw FrameError.malformed }
    return frame
  }
}
