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

    @Test func reconfigureUpdatesActiveRuntimeConfiguration() {
        Apxy.stop()
        Apxy.start(options: ApxyOptions(flushInterval: 2.0, capturedDomains: ["api.initial.dev"]))

        Apxy.reconfigure(
            ApxyRuntimeConfiguration(
                serverURL: "http://127.0.0.1:8083",
                flushInterval: 5.0,
                capturedDomains: ["api.example.com", "*.example.com"]
            )
        )

        #expect(
            Apxy.activeRuntimeConfiguration == ApxyRuntimeConfiguration(
                serverURL: "http://127.0.0.1:8083",
                flushInterval: 5.0,
                capturedDomains: ["api.example.com", "*.example.com"]
            )
        )

        Apxy.stop()
    }

    @Test func reconfigureFallsBackToLocalOnlyForInvalidURL() {
        Apxy.stop()
        Apxy.start(serverURL: "http://127.0.0.1:8083")

        Apxy.reconfigure(
            ApxyRuntimeConfiguration(
                serverURL: "not a url",
                flushInterval: 3.0,
                capturedDomains: ["api.example.com"]
            )
        )

        #expect(
            Apxy.activeRuntimeConfiguration == ApxyRuntimeConfiguration(
                serverURL: nil,
                flushInterval: 3.0,
                capturedDomains: ["api.example.com"]
            )
        )

        Apxy.stop()
    }

    @Test func runtimeConfigurationDoesNotPersistAcrossRestart() {
        Apxy.stop()
        Apxy.start()
        Apxy.reconfigure(
            ApxyRuntimeConfiguration(
                serverURL: "http://127.0.0.1:8083",
                flushInterval: 4.0,
                capturedDomains: ["api.example.com"]
            )
        )

        Apxy.stop()
        Apxy.start()

        #expect(
            Apxy.activeRuntimeConfiguration == ApxyRuntimeConfiguration(
                serverURL: nil,
                flushInterval: 2.0,
                capturedDomains: nil
            )
        )

        Apxy.stop()
    }
}
