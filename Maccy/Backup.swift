import CommonCrypto
import CryptoKit
import Foundation
import Security

// Password-protected export and import of clipboard history.
// File layout: "COPPERBK" magic, 1 byte format version, 16 byte salt, AES-GCM sealed box (nonce + ciphertext + tag).
// The key is derived from the password with PBKDF2-HMAC-SHA256.
enum Backup {
  enum BackupError: LocalizedError {
    case notABackup
    case unsupportedVersion
    case wrongPassword
    case keyDerivationFailed

    var errorDescription: String? {
      switch self {
      case .notABackup: return NSLocalizedString("BackupErrorNotABackup", tableName: "StorageSettings", comment: "")
      case .unsupportedVersion: return NSLocalizedString("BackupErrorVersion", tableName: "StorageSettings", comment: "")
      case .wrongPassword: return NSLocalizedString("BackupErrorPassword", tableName: "StorageSettings", comment: "")
      case .keyDerivationFailed: return NSLocalizedString("BackupErrorKey", tableName: "StorageSettings", comment: "")
      }
    }
  }

  struct Content: Codable, Equatable {
    let type: String
    let value: Data?
  }

  struct Item: Codable, Equatable {
    let title: String
    let application: String?
    let firstCopiedAt: Date
    let lastCopiedAt: Date
    let numberOfCopies: Int
    let isPinned: Bool
    let contents: [Content]
  }

  struct Archive: Codable, Equatable {
    var version = 1
    var exportedAt = Date.now
    let items: [Item]
  }

  static let fileExtension = "copperbackup"
  private static let magic = Data("COPPERBK".utf8)
  private static let formatVersion: UInt8 = 1
  private static let saltLength = 16
  private static let keyDerivationRounds: UInt32 = 200_000

  // Items that are set to expire (detected secrets) are never exported.
  static func archive(of items: [HistoryItem]) -> Archive {
    Archive(items: items.filter { $0.expiresAt == nil }.map(backupItem))
  }

  private static func backupItem(_ item: HistoryItem) -> Item {
    let contents: [Content] = item.contents.map { Content(type: $0.type, value: $0.value) }
    return Item(
      title: item.title,
      application: item.application,
      firstCopiedAt: item.firstCopiedAt,
      lastCopiedAt: item.lastCopiedAt,
      numberOfCopies: item.numberOfCopies,
      isPinned: item.pin != nil,
      contents: contents
    )
  }

  static func encrypt(_ archive: Archive, password: String) throws -> Data {
    // Default date encoding keeps full precision, so copy order survives a round trip.
    let plaintext = try JSONEncoder().encode(archive)

    var salt = Data(count: saltLength)
    let status = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, saltLength, $0.baseAddress!) }
    guard status == errSecSuccess else { throw BackupError.keyDerivationFailed }

    let key = try deriveKey(password: password, salt: salt)
    guard let sealed = try AES.GCM.seal(plaintext, using: key).combined else {
      throw BackupError.keyDerivationFailed
    }

    return magic + Data([formatVersion]) + salt + sealed
  }

  static func decrypt(_ data: Data, password: String) throws -> Archive {
    let headerLength = magic.count + 1 + saltLength
    guard data.count > headerLength, data.prefix(magic.count) == magic else { throw BackupError.notABackup }
    guard data[data.startIndex + magic.count] == formatVersion else { throw BackupError.unsupportedVersion }

    let saltStart = data.startIndex + magic.count + 1
    let salt = data[saltStart..<(saltStart + saltLength)]
    let sealed = data[(saltStart + saltLength)...]

    let key = try deriveKey(password: password, salt: Data(salt))
    let plaintext: Data
    do {
      plaintext = try AES.GCM.open(AES.GCM.SealedBox(combined: sealed), using: key)
    } catch {
      throw BackupError.wrongPassword
    }

    return try JSONDecoder().decode(Archive.self, from: plaintext)
  }

  private static func deriveKey(password: String, salt: Data) throws -> SymmetricKey {
    let passwordBytes = Array(password.utf8)
    var derived = [UInt8](repeating: 0, count: 32)
    let status = salt.withUnsafeBytes { saltBuffer in
      CCKeyDerivationPBKDF(
        CCPBKDFAlgorithm(kCCPBKDF2),
        passwordBytes.map { Int8(bitPattern: $0) }, passwordBytes.count,
        saltBuffer.bindMemory(to: UInt8.self).baseAddress, salt.count,
        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
        keyDerivationRounds,
        &derived, derived.count
      )
    }
    guard status == kCCSuccess else { throw BackupError.keyDerivationFailed }
    return SymmetricKey(data: derived)
  }
}
