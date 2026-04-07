enum ApxyDebugRoute: Hashable {
    case record(String)

    var recordID: String {
        switch self {
        case let .record(recordID):
            recordID
        }
    }
}
