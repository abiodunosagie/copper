import CryptoKit
import Foundation
import Network
import Security

// The pairing code both Macs share. It is kept in the Keychain and turned into a TLS pre-shared key,
// so only Macs with the same code can connect, and everything they send is encrypted.
enum PeerPairing {
  static let serviceType = "_copper._tcp"
  static let minimumCodeLength = 8
  private static let keychainService = "com.abiodunosagie.Copper.peer-share"
  private static let keychainAccount = "pairing-code"
  private static let pskIdentity = "Copper"

  static var code: String? {
    get {
      let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: keychainService,
        kSecAttrAccount as String: keychainAccount,
        kSecReturnData as String: true
      ]
      var result: AnyObject?
      guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
            let data = result as? Data else { return nil }
      return String(data: data, encoding: .utf8)
    }
    set {
      let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: keychainService,
        kSecAttrAccount as String: keychainAccount
      ]
      SecItemDelete(query as CFDictionary)
      guard let newValue, !newValue.isEmpty else { return }
      var item = query
      item[kSecValueData as String] = Data(newValue.utf8)
      item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
      SecItemAdd(item as CFDictionary, nil)
    }
  }

  static func isValid(_ code: String) -> Bool {
    code.count >= minimumCodeLength
  }

  // TCP with TLS 1.2 using a key derived from the pairing code. A wrong code fails the handshake.
  static func parameters(code: String) -> NWParameters {
    let tls = NWProtocolTLS.Options()
    let key = SymmetricKey(data: Data(code.utf8))
    let psk = Data(HMAC<SHA256>.authenticationCode(for: Data(serviceType.utf8), using: key))
    let options = tls.securityProtocolOptions
    sec_protocol_options_add_pre_shared_key(options, dispatchData(psk), dispatchData(Data(pskIdentity.utf8)))
    sec_protocol_options_append_tls_ciphersuite(options, tls_ciphersuite_t(rawValue: UInt16(TLS_PSK_WITH_AES_128_GCM_SHA256))!)
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
