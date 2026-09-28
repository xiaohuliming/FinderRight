import XCTest
import Darwin
@testable import FinderRightKit

final class SecureRequestStoreTests: XCTestCase {
    var root: URL!
    var store: SecureRequestStore!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("FinderRight-security-" + UUID().uuidString)
        store = SecureRequestStore(directory: root.appendingPathComponent("ipc"))
        try store.prepare()
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }
    private func request(_ action: String = "duplicate", payload: [String: AnyJSON]? = nil) -> IPCRequest {
        IPCRequest(id: UUID().uuidString, action: action, payload: payload ?? ["paths": .stringArray(["/tmp/fixture.txt"])])
    }
    private func file(_ id: String) -> URL { store.directory.appendingPathComponent(id + ".req.json") }
    func testRoundTripIsPrivateAndConsumedOnlyOnce() throws {
        let req = request(), digest = try store.write(req)
        let permissions = try FileManager.default.attributesOfItem(atPath: file(req.id).path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(permissions?.intValue, 0o600)
        let received = try store.consume(id: req.id, digest: digest)
        XCTAssertEqual(received.action, "duplicate")
        XCTAssertFalse(FileManager.default.fileExists(atPath: file(req.id).path))
        XCTAssertThrowsError(try store.consume(id: req.id, digest: digest))
    }
    func testTamperingFailsBeforeRequestExecution() throws {
        let req = request(), digest = try store.write(req)
        let changed = IPCRequest(id: req.id, action: "cutFiles", payload: ["paths": .stringArray(["/tmp/other.txt"])])
        try JSONEncoder().encode(changed).write(to: file(req.id))
        XCTAssertThrowsError(try store.consume(id: req.id, digest: digest))
        XCTAssertTrue(FileManager.default.fileExists(atPath: file(req.id).path))
    }
    func testSymlinkAndHardlinkRequestsAreRejected() throws {
        let req = request(), data = try JSONEncoder().encode(req)
        let target = root.appendingPathComponent("target.json")
        try data.write(to: target)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: target.path)
        try FileManager.default.createSymbolicLink(at: file(req.id), withDestinationURL: target)
        XCTAssertThrowsError(try store.consume(id: req.id, digest: SecureRequestStore.digest(data)))
        try FileManager.default.removeItem(at: file(req.id))
        try FileManager.default.linkItem(at: target, to: file(req.id))
        XCTAssertThrowsError(try store.consume(id: req.id, digest: SecureRequestStore.digest(data)))
        XCTAssertEqual(try Data(contentsOf: target), data)
    }
    func testFIFOIsRejectedWithoutBlocking() throws {
        let req = request()
        XCTAssertEqual(mkfifo(file(req.id).path, 0o600), 0)
        XCTAssertThrowsError(try store.consume(id: req.id, digest: String(repeating: "0", count: 64)))
    }
    func testOversizedAndSharedRequestsAreRejected() throws {
        let req = request(), digest = try store.write(req)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: file(req.id).path)
        XCTAssertThrowsError(try store.consume(id: req.id, digest: digest))
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file(req.id).path)
        try Data(repeating: 65, count: SecureRequestStore.maximumBytes + 1).write(to: file(req.id))
        XCTAssertThrowsError(try store.consume(id: req.id, digest: digest))
    }
    func testDirectorySymlinkIsRejected() throws {
        let link = root.appendingPathComponent("alias")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: store.directory)
        XCTAssertThrowsError(try SecureRequestStore(directory: link).prepare())
    }
    func testMalformedIdentifiersAndMismatchedIDsAreRejected() throws {
        XCTAssertThrowsError(try store.consume(id: "../outside", digest: String(repeating: "0", count: 64)))
        let req = request(), digest = try store.write(req), other = UUID().uuidString
        try FileManager.default.moveItem(at: file(req.id), to: file(other))
        XCTAssertThrowsError(try store.consume(id: other, digest: digest))
    }
    func testOperationPolicyRejectsUnexpectedCommandsAndApplications() throws {
        XCTAssertThrowsError(try RequestPolicy.validate(request("runShell")))
        XCTAssertThrowsError(try RequestPolicy.validate(request(payload: ["paths": .stringArray(["/tmp/a"]), "command": .string("unexpected")])))
        XCTAssertThrowsError(try RequestPolicy.validate(request("openWithApp", payload: ["paths": .stringArray(["/tmp/a"]), "bundleId": .string("unknown.app")])))
        XCTAssertThrowsError(try RequestPolicy.validate(request(payload: ["paths": .stringArray(["relative/path"])])))
        XCTAssertThrowsError(try RequestPolicy.validate(request(payload: ["paths": .stringArray(["/tmp/a\nmisleading"])])))
        XCTAssertThrowsError(try RequestPolicy.validate(request(payload: [:])))
        XCTAssertNoThrow(try RequestPolicy.validate(request("openTerminal", payload: ["directory": .string("/tmp"), "bundleId": .string("com.apple.Terminal")])))
    }
    func testServicesCannotBypassAggregatePayloadLimit() throws {
        let paths = (0..<1000).map { "/tmp/\($0)/" + String(repeating: "a", count: 1500) }
        XCTAssertThrowsError(try RequestPolicy.validate(request(payload: ["paths": .stringArray(paths)])))
    }
}
