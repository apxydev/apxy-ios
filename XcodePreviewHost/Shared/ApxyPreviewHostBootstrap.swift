import ApxyCore

@MainActor
enum ApxyPreviewHostBootstrap {
    private static var didStart = false
    private static var didLoadMockData = false

    static func startIfNeeded() async {
        if !didStart {
            didStart = true
            Apxy.start()
        }

        await loadMockDataIfNeeded()
    }

    private static func loadMockDataIfNeeded() async {
#if DEBUG
        guard !didLoadMockData, let store = Apxy.activeDebugStore else { return }
        didLoadMockData = true
        await ApxyDebugPreviewFixtures.populate(store)
#endif
    }
}
