#if canImport(UIKit)
import UIKit
#endif
import Foundation

/// Manages the SDK session lifecycle:
///
/// - On `start()`: registers the `SDKClient`; creates the first session once registration succeeds.
/// - On `didBecomeActive`: resumes the current session if the app was backgrounded for less than
///   `sessionIdleTimeout`; otherwise starts a new session.
/// - On `didEnterBackground`: records the background timestamp (session ID is preserved so that
///   resumed traffic can be correlated to the same session row on the server).
/// - On `setUser/setTag/setContext`: updates session context in-place via PATCH.
final class SessionManager: @unchecked Sendable {
    private let transport: SessionTransport
    private let buffer: RecordBuffer
    private let connectionMonitor: ConnectionMonitor
    private let connectionStateTracker: ConnectionStateTracker
    private let sessionIdleTimeout: TimeInterval
    let context = SessionContext()

    private(set) var currentSessionID: String?
    private var sdkClient: SDKClient?

    /// Set to `true` once `registerClient` completes successfully at least once.
    /// Prevents `didBecomeActive` from creating a session before registration finishes.
    private var hasRegisteredClient = false

    /// Timestamp of the most recent background transition. `nil` on first launch.
    private var backgroundedAt: Date?

    private let queue = DispatchQueue(label: "dev.apxy.sdk.session-manager", qos: .utility)

    init(
        transport: SessionTransport,
        buffer: RecordBuffer,
        connectionMonitor: ConnectionMonitor,
        connectionStateTracker: ConnectionStateTracker,
        sessionIdleTimeout: TimeInterval
    ) {
        self.transport = transport
        self.buffer = buffer
        self.connectionMonitor = connectionMonitor
        self.connectionStateTracker = connectionStateTracker
        self.sessionIdleTimeout = sessionIdleTimeout
    }

    // MARK: Lifecycle

    func start() {
        queue.async { [weak self] in
            self?.doStart()
        }
    }

    private func doStart() {
        let client = ClientIdentity.build()
        sdkClient = client

        let shortId = String(client.id.prefix(8))
        SDKLogger.debug("registerClient starting clientId=\(shortId)…")

        transport.registerClient(client) { [weak self] error in
            guard let self else { return }
            if let error {
                let reason = error.localizedDescription
                SDKLogger.warn("cannot reach server (registerClient): \(reason)")
                self.connectionStateTracker.reportServerEndpointFailure(reason: reason)
            } else {
                self.connectionStateTracker.reportServerEndpointSuccess()
            }
            // Dispatch back onto the serial queue so this always executes after any
            // handleForeground() calls already enqueued from didBecomeActive notifications.
            // This prevents a duplicate session when the notification fires during start().
            self.queue.async {
                self.hasRegisteredClient = true
                self.handleForeground()
            }
        }

#if canImport(UIKit)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            // If registration hasn't completed yet, handleForeground() is a no-op;
            // the registerClient completion will call it once ready.
            self?.queue.async { self?.handleForeground() }
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.queue.async { self?.handleBackground() }
        }
#endif
    }

    // MARK: Session create / resume

    /// Called on every foreground transition (and once after registration completes).
    /// Creates a new session only when:
    ///   - this is the first foreground after registration (currentSessionID == nil), or
    ///   - the app was backgrounded longer than `sessionIdleTimeout`.
    /// Otherwise the existing session is silently resumed (no server call).
    private func handleForeground() {
        guard hasRegisteredClient else { return }

        if let bg = backgroundedAt {
            let elapsed = Date().timeIntervalSince(bg)
            backgroundedAt = nil
            if elapsed < sessionIdleTimeout {
                SDKLogger.debug("resumeSession elapsed=\(Int(elapsed))s (timeout=\(Int(sessionIdleTimeout))s)")
                return
            }
            // elapsed >= sessionIdleTimeout: fall through to start a new session.
        } else if currentSessionID != nil {
            // No background transition was recorded and a session is already active.
            // This is a duplicate handleForeground() call from the same app-open cycle
            // (e.g. didBecomeActive firing while registerClient completion is in-flight).
            SDKLogger.debug("handleForeground: session \(currentSessionID!.prefix(8)) already active, skipping duplicate")
            return
        }

        startNewSession()
    }

    private func startNewSession() {
        guard let client = sdkClient else { return }
        let sessionID = UUID().uuidString
        currentSessionID = sessionID

        let shortSession = String(sessionID.prefix(8))
        SDKLogger.debug("createSession sessionId=\(shortSession)…")

        let ctx = context.toClientContext(networkType: connectionMonitor.networkType)
        transport.createSession(
            id: sessionID,
            clientID: client.id,
            context: ctx
        ) { [weak self] error in
            guard let self else { return }
            if let error {
                let reason = error.localizedDescription
                SDKLogger.warn("cannot reach server (createSession): \(reason)")
                self.connectionStateTracker.reportServerEndpointFailure(reason: reason)
            } else {
                self.connectionStateTracker.reportServerEndpointSuccess()
            }
        }
    }

    private func handleBackground() {
        backgroundedAt = Date()
    }

    // MARK: Context updates

    func updateContext(file: String = #file, line: Int = #line) {
        guard let sessionID = currentSessionID else { return }
        queue.async { [weak self] in
            guard let self else { return }
            let ctx = self.context.toClientContext(networkType: self.connectionMonitor.networkType)
            self.transport.updateSessionContext(id: sessionID, context: ctx) { [weak self] error in
                guard let self else { return }
                if let error {
                    let reason = error.localizedDescription
                    SDKLogger.warn("cannot reach server (updateSessionContext): \(reason)")
                    self.connectionStateTracker.reportServerEndpointFailure(reason: reason)
                } else {
                    self.connectionStateTracker.reportServerEndpointSuccess()
                }
            }
        }
    }
}
