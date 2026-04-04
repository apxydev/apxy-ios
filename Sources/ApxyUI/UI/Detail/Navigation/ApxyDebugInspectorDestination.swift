enum ApxyDebugInspectorDestination: Hashable {
    case requestHeaders(ApxyDebugRequestKind)
    case requestCookies(ApxyDebugRequestKind)
    case requestBody(ApxyDebugRequestKind)
    case responseHeaders
    case responseCookies
    case responseBody
    case metrics
    case error
}

enum ApxyDebugRequestKind: Hashable {
    case single
    case final
    case original
}
