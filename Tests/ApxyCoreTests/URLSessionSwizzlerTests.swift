import Foundation
import Testing
@testable import ApxyCore

struct URLSessionSwizzlerTests {
    @Test func swizzlerIsPassiveUntilInstallation() {
        URLSessionSwizzler.uninstall()
        #expect(URLSessionSwizzler.isInstalled == false)
        #expect(Apxy.activeDebugStore == nil)
    }

    @Test func installInjectsProtocolIntoEphemeralSession() async {
        #expect(await SwizzlerHarness.shared.ephemeralSessionContainsProtocol())
    }

    @Test func customConfigurationRequiresExplicitProtocolOptIn() async {
        #expect(await SwizzlerHarness.shared.prebuiltConfigurationRemainsUntouched())
    }
}

private actor SwizzlerHarness {
    static let shared = SwizzlerHarness()

    func ephemeralSessionContainsProtocol() -> Bool {
        URLSessionSwizzler.uninstall()
        URLSessionSwizzler.install()
        defer { URLSessionSwizzler.uninstall() }

        let session = URLSession(configuration: .ephemeral)
        return session.configuration.protocolClasses?.contains(where: { $0 == ApxyURLProtocol.self }) == true
    }

    func prebuiltConfigurationRemainsUntouched() -> Bool {
        URLSessionSwizzler.uninstall()

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = []

        URLSessionSwizzler.install()
        defer { URLSessionSwizzler.uninstall() }

        let session = URLSession(configuration: configuration)
        return session.configuration.protocolClasses?.contains(where: { $0 == ApxyURLProtocol.self }) == false
    }
}
