import Testing
@testable import ApxyCore

@Suite(.serialized)
struct ApxyStartTests {
    @Test func localOnlyStartEnablesDebugStoreByDefault() {
        Apxy.stop()

        Apxy.start()

        #expect(Apxy.activeDebugStore != nil)

        Apxy.stop()
        #expect(Apxy.activeDebugStore == nil)
    }
}
