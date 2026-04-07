import ApxyCore

enum ApxyDebugConsoleScope: Equatable {
    case all
    case activeSession
    case session(String)

    var allowsSessionSelection: Bool {
        if case .all = self {
            return true
        }
        return false
    }

    func resolvedSessionID(in snapshot: ApxyDebugSnapshot) -> String? {
        switch self {
        case .all:
            return nil
        case .activeSession:
            let sessionIDsWithRecords = Set(snapshot.records.compactMap(\.sessionID))
            return snapshot.sessions.first(where: { sessionIDsWithRecords.contains($0.id) })?.id
                ?? snapshot.sessions.first?.id
        case let .session(sessionID):
            return sessionID
        }
    }

    func scopedRecords(in snapshot: ApxyDebugSnapshot) -> [ApxyDebugRecord] {
        guard let sessionID = resolvedSessionID(in: snapshot) else {
            if case .all = self {
                return snapshot.records
            }
            return []
        }

        return snapshot.records.filter { $0.sessionID == sessionID }
    }
}
