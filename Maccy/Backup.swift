import CommonCrypto
import CryptoKit
import Foundation
import Security

// Password-protected export and import of clipboard history.
// File layout: "COPPERBK" magic, 1 byte format version, 16 byte salt, AES-GCM sealed box (nonce + ciphertext + tag).
// The key is derived from the password with PBKDF2-HMAC-SHA256; the round count depends on the format version.
enum Backup {
  enum BackupError: LocalizedError {
    case notABackup
    case unsupportedVersion
    case wrongPassword
    case keyDerivationFailed
    case encryptionFailed
    case damaged

    var errorDescription: String? {
      switch self {
      case .notABackup: return NSLocalizedString("BackupErrorNotABackup", tableName: "StorageSettings", comment: "")
      case .unsupportedVersion:
        return NSLocalizedString("BackupErrorVersion", tableName: "StorageSettings", comment: "")
      case .wrongPassword: return NSLocalizedString("BackupErrorPassword", tableName: "StorageSettings", comment: "")
      case .keyDerivationFailed: return NSLocalizedString("BackupErrorKey", tableName: "StorageSettings", comment: "")
      case .encryptionFailed: return NSLocalizedString("BackupErrorEncrypt", tableName: "StorageSettings", comment: "")
      case .damaged: return NSLocalizedString("BackupErrorDamaged", tableName: "StorageSettings", comment: "")
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
    // Optional so backups made before collections still decode.
    var collection: String?
  }

  struct Archive: Codable, Equatable {
    var version = 1
    var exportedAt = Date.now
    let items: [Item]
  }

  static let fileExtension = "copperbackup"
  private static let magic = Data("COPPERBK".utf8)
  private static let formatVersion: UInt8 = 2
  private static let saltLength = 16
  // Version 1 files used 200k rounds; version 2 follows current OWASP guidance for PBKDF2-HMAC-SHA256.
  private static let keyDerivationRounds: [UInt8: UInt32] = [1: 200_000, 2: 600_000]

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
      contents: contents,
      collection: item.collection
    )
  }

  static func encrypt(_ archive: Archive, password: String) throws -> Data {
    // Default date encoding keeps full precision, so copy order survives a round trip.
    let plaintext = try JSONEncoder().encode(archive)

    var salt = Data(count: saltLength)
    let status = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, saltLength, $0.baseAddress!) }
    guard status == errSecSuccess else { throw BackupError.encryptionFailed }

    let key = try deriveKey(password: password, salt: salt, version: formatVersion)
    guard let sealed = try AES.GCM.seal(plaintext, using: key).combined else {
      throw BackupError.encryptionFailed
    }

    return magic + Data([formatVersion]) + salt + sealed
  }

  static func decrypt(_ data: Data, password: String) throws -> Archive {
    let headerLength = magic.count + 1 + saltLength
    guard data.count > headerLength, data.prefix(magic.count) == magic else { throw BackupError.notABackup }
    let version = data[data.startIndex + magic.count]
    guard keyDerivationRounds[version] != nil else { throw BackupError.unsupportedVersion }

    let saltStart = data.startIndex + magic.count + 1
    let salt = data[saltStart..<(saltStart + saltLength)]
    let sealed = data[(saltStart + saltLength)...]

    let key = try deriveKey(password: password, salt: Data(salt), version: version)
    let plaintext: Data
    do {
      plaintext = try AES.GCM.open(AES.GCM.SealedBox(combined: sealed), using: key)
    } catch {
      throw BackupError.wrongPassword
    }

    do {
      return try JSONDecoder().decode(Archive.self, from: plaintext)
    } catch {
      throw BackupError.damaged
    }
  }

  private static func deriveKey(password: String, salt: Data, version: UInt8) throws -> SymmetricKey {
    guard let rounds = keyDerivationRounds[version] else { throw BackupError.unsupportedVersion }
    let passwordBytes = Array(password.utf8)
    var derived = [UInt8](repeating: 0, count: 32)
    let status = salt.withUnsafeBytes { saltBuffer in
      CCKeyDerivationPBKDF(
        CCPBKDFAlgorithm(kCCPBKDF2),
        passwordBytes.map { Int8(bitPattern: $0) }, passwordBytes.count,
        saltBuffer.bindMemory(to: UInt8.self).baseAddress, salt.count,
        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
        rounds,
        &derived, derived.count
      )
    }
    guard status == kCCSuccess else { throw BackupError.keyDerivationFailed }
    return SymmetricKey(data: derived)
  }
}
