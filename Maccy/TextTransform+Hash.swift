import CryptoKit
import Foundation

extension TextTransform {
  static let hashTransforms: [TextTransform] = [
    TextTransform(id: "md5", name: "MD5", category: .hashing) { hex(Insecure.MD5.hash(data: Data($0.utf8))) },
    TextTransform(id: "sha1", name: "SHA-1", category: .hashing) { hex(Insecure.SHA1.hash(data: Data($0.utf8))) },
    TextTransform(id: "sha256", name: "SHA-256", category: .hashing) { hex(SHA256.hash(data: Data($0.utf8))) },
    TextTransform(id: "sha384", name: "SHA-384", category: .hashing) { hex(SHA384.hash(data: Data($0.utf8))) },
    TextTransform(id: "sha512", name: "SHA-512", category: .hashing) { hex(SHA512.hash(data: Data($0.utf8))) }
  ]
}
