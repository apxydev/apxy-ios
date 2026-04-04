import Foundation

struct DebugCaptureContext: Sendable {
    let metrics: ApxyDebugRecord.Metrics?
    let error: ApxyDebugRecord.ErrorInfo?
}
