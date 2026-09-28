import CryptoKit
import Foundation
import Network
import Security

// The pairing code both Macs share. Copper generates it (about 150 random bits), the owner copies it
// to the other Mac, and it is kept in the Keychain. It becomes a TLS pre-shared key, so only Macs with
// the same code can connect, and a captured connection cannot realistically be brute-forced.
enum PeerPairing {
  static let serviceType = "_copper._tcp"
  static let codeGroups = 6
  static let groupLength = 5
  private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
  private static let keychainService = "com.abiodunosagie.Copper.peer-share"
  private static let keychainAccount = "pairing-code"
  private static let pskIdentity = "Copper"

  private static var baseQuery: [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: keychainService,
      kSecAttrAccount as String: keychainAccount,
      kSecUseDataProtectionKeychain as String: true
    ]
  }

  static var code: String? {
    var query = baseQuery
    query[kSecReturnData as String] = true
    var result: AnyObject?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
          let data = result as? Data else { return nil }
    return String(data: data, encoding: .utf8)
  }

  // Stores a valid code; returns false (and stores nothing) when the code or the Keychain write is rejected.
  @discardableResult
  static func save(_ code: String) -> Bool {
    guard let normalized = normalize(code) else { return false }
    SecItemDelete(baseQuery as CFDictionary)
    var item = baseQuery
    item[kSecValueData as String] = Data(normalized.utf8)
    item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
  }

  static func generateCode() -> String {
    var generator = SystemRandomNumberGenerator()
    let characters = (0..<(codeGroups * groupLength)).map { _ in alphabet.randomElement(using: &generator)! }
    return stride(from: 0, to: characters.count, by: groupLength)
      .map { String(characters[$0..<($0 + groupLength)]) }
      .joined(separator: "-")
  }

  // Uppercase, without spaces or dashes; nil unless it is a full generated code.
  static func normalize(_ code: String) -> String? {
    let cleaned = code.uppercased().filter { !$0.isWhitespace && $0 != "-" }
    guard cleaned.count == codeGroups * groupLength, cleaned.allSatisfy(alphabet.contains) else { return nil }
    return cleaned
  }

  static func isValid(_ code: String) -> Bool {
    normalize(code) != nil
  }

  // TCP with TLS 1.2 using a key derived from the pairing code. A wrong code fails the handshake.
  static func parameters(code: String) -> NWParameters {
    let tls = NWProtocolTLS.Options()
    let key = SymmetricKey(data: Data((normalize(code) ?? code).utf8))
    let psk = Data(HMAC<SHA256>.authenticationCode(for: Data(serviceType.utf8), using: key))
    let options = tls.securityProtocolOptions
    sec_protocol_options_add_pre_shared_key(options, dispatchData(psk), dispatchData(Data(pskIdentity.utf8)))
    let cipherSuite = tls_ciphersuite_t(rawValue: UInt16(TLS_PSK_WITH_AES_128_GCM_SHA256))!
    sec_protocol_options_append_tls_ciphersuite(options, cipherSuite)
    sec_protocol_options_set_min_tls_protocol_version(options, .TLSv12)
    sec_protocol_options_set_max_tls_protocol_version(options, .TLSv12)

    let parameters = NWParameters(tls: tls)
    parameters.includePeerToPeer = true
    return parameters
  }

  private static func dispatchData(_ data: Data) -> __DispatchData {
    data.withUnsafeBytes { DispatchData(bytes: $0) } as __DispatchData
  }
}
