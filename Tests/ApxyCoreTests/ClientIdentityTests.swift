import Testing
@testable import ApxyCore

struct ClientIdentityTests {
    @Test func buildReturnsNonEmptyIdentity() {
        let client = ClientIdentity.build()
        #expect(client.id.isEmpty == false)
        #expect(client.platform.isEmpty == false)
        #expect(client.osName.isEmpty == false)
    }

    @Test func buildIsDeterministic() {
        let lhs = ClientIdentity.build()
        let rhs = ClientIdentity.build()
        #expect(lhs.id == rhs.id)
    }

    @Test func idUsesSHA256HexLength() {
        #expect(ClientIdentity.build().id.count == 64)
    }
}
