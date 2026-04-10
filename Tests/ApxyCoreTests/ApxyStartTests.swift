import Testing
@testable import ApxyCore

@Suite(.serialized)
struct ApxyStartTests {
    @Test func optionsDefaultToBufferedHTTPTransport() {
        let options = ApxyOptions()

        let usesHTTPByDefault: Bool
        switch options.transport {
        case .http:
            usesHTTPByDefault = true
        case .webSocket, .auto:
            usesHTTPByDefault = false
        }

        #expect(usesHTTPByDefault)
        #expect(options.debugConsole == .enabled)
    }

    @Test func localOnlyStartEnablesDebugStoreByDefault() {
        Apxy.stop()

        Apxy.start()

        #expect(Apxy.activeDebugStore != nil)

        Apxy.stop()
        #expect(Apxy.activeDebugStore == nil)
    }

    @Test func explicitOptionsStartKeepsDebugStoreEnabledByDefault() {
        Apxy.stop()

        Apxy.start(options: ApxyOptions(flushInterval: 2.0))

        #expect(Apxy.activeDebugStore != nil)

        Apxy.stop()
    }

    @Test func reconfigureUpdatesActiveRuntimeConfiguration() {
        Apxy.stop()
        Apxy.start(options: ApxyOptions(flushInterval: 2.0, capturedDomains: ["api.initial.dev"]))
        let credentials = ApxyIngestCredentials(keyID: "sdki_test", clientSecret: "secret")

        #expect(
            Apxy.reconfigure(
                ApxyRuntimeConfiguration(
                    remote: ApxyRemoteConfiguration(
                        serverURL: "http://127.0.0.1:8083",
                        ingestCredentials: credentials
                    ),
                    flushInterval: 5.0,
                    capturedDomains: ["api.example.com", "*.example.com"]
                )
            )
        )

        #expect(
            Apxy.activeRuntimeConfiguration == ApxyRuntimeConfiguration(
                remote: ApxyRemoteConfiguration(
                    serverURL: "http://127.0.0.1:8083",
                    ingestCredentials: credentials
                ),
                flushInterval: 5.0,
                capturedDomains: ["api.example.com", "*.example.com"]
            )
        )

        Apxy.stop()
    }

    @Test func remoteStartRequiresIngestCredentials() {
        Apxy.stop()

        #expect(
            Apxy.start(options: ApxyOptions(
                remote: ApxyRemoteConfiguration(
                    serverURL: "http://127.0.0.1:8083",
                    ingestCredentials: ApxyIngestCredentials(keyID: "", clientSecret: "")
                )
            )) == false
        )

        #expect(Apxy.activeRuntimeConfiguration == nil)
        #expect(Apxy.activeDebugStore == nil)
    }

    @Test func reconfigureRejectsInvalidRemoteURLAndKeepsActiveConfiguration() {
        Apxy.stop()
        Apxy.start(options: ApxyOptions(
            remote: ApxyRemoteConfiguration(
                serverURL: "http://127.0.0.1:8083",
                ingestCredentials: ApxyIngestCredentials(keyID: "sdki_test", clientSecret: "secret")
            )
        ))

        let initialConfiguration = Apxy.activeRuntimeConfiguration

        #expect(
            Apxy.reconfigure(
                ApxyRuntimeConfiguration(
                    remote: ApxyRemoteConfiguration(
                        serverURL: "not a url",
                        ingestCredentials: ApxyIngestCredentials(keyID: "sdki_test", clientSecret: "secret")
                    ),
                    flushInterval: 3.0,
                    capturedDomains: ["api.example.com"]
                )
            ) == false
        )

        #expect(Apxy.activeRuntimeConfiguration == initialConfiguration)

        Apxy.stop()
    }

    @Test func runtimeConfigurationDoesNotPersistAcrossRestart() {
        Apxy.stop()
        Apxy.start()
        #expect(
            Apxy.reconfigure(
                ApxyRuntimeConfiguration(
                    remote: ApxyRemoteConfiguration(
                        serverURL: "http://127.0.0.1:8083",
                        ingestCredentials: ApxyIngestCredentials(keyID: "sdki_test", clientSecret: "secret")
                    ),
                    flushInterval: 4.0,
                    capturedDomains: ["api.example.com"]
                )
            )
        )

        Apxy.stop()
        Apxy.start()

        #expect(
            Apxy.activeRuntimeConfiguration == ApxyRuntimeConfiguration(
                remote: nil,
                flushInterval: 2.0,
                capturedDomains: nil
            )
        )

        Apxy.stop()
    }
}
