import Foundation
import Security
import FinderRightKit

enum IPCSourceAuthenticator {
    /// Token comes exclusively from the current Apple Event, never from JSON or URL parameters.
    static func validate(_ auditToken: Data?) throws {
        guard let token = auditToken, token.count == 32,
              let extensionURL = Bundle.main.builtInPlugInsURL?.appendingPathComponent("FinderRightSync.appex") else {
            throw FileOperationError("无法验证请求来源，请从 FinderRight 右键菜单重试。")
        }
        var guest: SecCode?
        guard SecCodeCopyGuestWithAttributes(nil, [kSecGuestAttributeAudit: token] as CFDictionary, [], &guest) == errSecSuccess,
              let guest else { throw FileOperationError("调用方身份无效。") }
        var hashes: [String] = []
        for architecture in ["arm64", "x86_64"] {
            var expected: SecStaticCode?
            let attributes = [kSecCodeAttributeArchitecture: architecture] as CFDictionary
            guard SecStaticCodeCreateWithPathAndAttributes(extensionURL as CFURL, [], attributes, &expected) == errSecSuccess,
                  let expected else { continue }
            guard SecStaticCodeCheckValidity(expected, SecCSFlags(rawValue: kSecCSStrictValidate), nil) == errSecSuccess else {
                throw FileOperationError("已安装扩展的签名无效，请重新安装。")
            }
            var information: CFDictionary?
            guard SecCodeCopySigningInformation(expected, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
                  let hash = (information as? [String: Any])?[kSecCodeInfoUnique as String] as? Data else { continue }
            hashes.append("cdhash H\"" + hash.map { String(format: "%02x", $0) }.joined() + "\"")
        }
        guard !hashes.isEmpty else { throw FileOperationError("无法读取扩展签名。") }
        let expression = "identifier \"com.finderright.app.sync\" and (" + hashes.joined(separator: " or ") + ")"
        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(expression as CFString, [], &requirement) == errSecSuccess,
              SecCodeCheckValidity(guest, SecCSFlags(rawValue: kSecCSStrictValidate), requirement) == errSecSuccess else {
            throw FileOperationError("已拒绝非 FinderRight 扩展发出的请求。")
        }
    }
}
