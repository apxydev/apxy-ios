import SwiftUI
import ApxyCore

@available(iOS 16.0, macOS 13.0, *)
struct ApxyDebugRecordDetailView: View {
    let record: ApxyDebugRecord

    @State private var selectedTab: ApxyDebugInspectorTab = .overview
    @State private var selectedRequestVariant: ApxyDebugRequestVariant = .original

    var body: some View {
        List {
            Section {
                headerCard
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)

            Section {
                Picker("Inspector Section", selection: $selectedTab) {
                    ForEach(ApxyDebugInspectorTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
            }
            .textCase(nil)

            tabContent
        }
        .modifier(ApxyDebugDetailListStyleModifier())
        .navigationTitle(record.request.host)
        .onAppear {
            if showsCurrentRequest {
                selectedRequestVariant = .current
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        capsuleLabel(record.request.method, tint: .accentColor)
                        if record.isMocked {
                            capsuleLabel("Mock", tint: .secondary)
                        }
                        if record.isTLS {
                            capsuleLabel("TLS", tint: .green)
                        }
                    }

                    Text(headerTitle)
                        .font(.title3.weight(.semibold))
                        .lineLimit(2)

                    Text(headerSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 8) {
                    Text(statusHeaderText)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(statusColor)
                        .multilineTextAlignment(.trailing)

                    Text(ApxyDebugValueFormatters.duration(record.duration))
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            Text(record.request.url)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            ViewThatFits {
                HStack(spacing: 16) {
                    summaryValue(title: "Captured", value: ApxyDebugValueFormatters.timestamp(record.capturedAt))
                    summaryValue(title: "Transferred", value: transferSummary)
                    if let sessionID = record.sessionID, !sessionID.isEmpty {
                        summaryValue(title: "Session", value: String(sessionID.prefix(8)))
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    summaryValue(title: "Captured", value: ApxyDebugValueFormatters.timestamp(record.capturedAt))
                    summaryValue(title: "Transferred", value: transferSummary)
                    if let sessionID = record.sessionID, !sessionID.isEmpty {
                        summaryValue(title: "Session", value: String(sessionID.prefix(8)))
                    }
                }
            }
        }
        .padding(16)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.08))
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .overview:
            overviewContent
        case .request:
            requestContent
        case .response:
            responseContent
        case .metrics:
            metricsContent
        }
    }

    private var overviewContent: some View {
        Group {
            Section("Overview") {
                LabeledContent("Status") {
                    Text(statusHeaderText)
                        .foregroundStyle(statusColor)
                }
                LabeledContent("Duration") {
                    Text(ApxyDebugValueFormatters.duration(record.duration))
                        .monospacedDigit()
                }
                LabeledContent("Captured At") {
                    Text(ApxyDebugValueFormatters.timestamp(record.capturedAt))
                }
                LabeledContent("Redirects") {
                    Text("\(record.redirectCount)")
                }
                LabeledContent("TLS") {
                    Text(record.isTLS ? "Enabled" : "Disabled")
                }
                LabeledContent("Mocked") {
                    Text(record.isMocked ? "Yes" : "No")
                }
            }

            Section("Transfer") {
                LabeledContent("Request Headers") {
                    Text(ApxyDebugValueFormatters.bytes(record.transfer.requestHeaderBytesSent))
                }
                LabeledContent("Request Body") {
                    Text(ApxyDebugValueFormatters.bytes(record.transfer.requestBodyBytesSent ?? record.request.bodySize))
                }
                LabeledContent("Response Headers") {
                    Text(ApxyDebugValueFormatters.bytes(record.transfer.responseHeaderBytesReceived))
                }
                LabeledContent("Response Body") {
                    Text(ApxyDebugValueFormatters.bytes(record.transfer.responseBodyBytesAfterDecoding ?? record.response?.bodySize))
                }
            }

            Section("Locations") {
                selectableValue(title: "Original URL", value: record.request.url)
                if let currentURL = record.request.currentURL,
                   currentURL != record.request.url {
                    selectableValue(title: "Current URL", value: currentURL)
                }
            }

            if let error = record.error {
                Section("Error") {
                    selectableMonospaceText(
                        """
                        Domain: \(error.domain)
                        Code: \(error.code)
                        Message: \(error.message)
                        """
                    )
                }
            }
        }
    }

    private var requestContent: some View {
        Group {
            if showsCurrentRequest {
                Section {
                    Picker("Request Version", selection: $selectedRequestVariant) {
                        ForEach(ApxyDebugRequestVariant.allCases) { variant in
                            Text(variant.title).tag(variant)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .textCase(nil)
            }

            Section("Request") {
                LabeledContent("Method") {
                    Text(record.request.method)
                }
                LabeledContent("Host") {
                    Text(selectedRequestHost)
                }
                LabeledContent("Path") {
                    Text(selectedRequestPath)
                }
                selectableValue(title: "URL", value: selectedRequestURL)
            }

            Section("Headers") {
                LabeledContent("Count") {
                    Text("\(selectedRequestHeaders.count)")
                }
                disclosure("Show Headers", content: ApxyDebugValueFormatters.headers(selectedRequestHeaders))
            }

            payloadSection(
                title: "Body",
                data: record.request.body,
                contentType: record.request.contentType,
                size: record.request.bodySize,
                emptyMessage: "No request body captured"
            )
        }
    }

    @ViewBuilder
    private var responseContent: some View {
        if let response = record.response {
            Section("Response") {
                LabeledContent("Status Code") {
                    Text("\(response.statusCode)")
                        .foregroundStyle(statusColor)
                }
                LabeledContent("Content Type") {
                    Text(response.contentType ?? "Unknown")
                }
                LabeledContent("Body Size") {
                    Text(ApxyDebugValueFormatters.bytes(response.bodySize))
                }
            }

            Section("Headers") {
                LabeledContent("Count") {
                    Text("\(response.headers.count)")
                }
                disclosure("Show Headers", content: ApxyDebugValueFormatters.headers(response.headers))
            }

            payloadSection(
                title: "Body",
                data: response.body,
                contentType: response.contentType,
                size: response.bodySize,
                emptyMessage: "No response body captured"
            )
        } else {
            Section {
                Text("No response captured")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var metricsContent: some View {
        if let metrics = record.metrics {
            Section("Task") {
                LabeledContent("Started") {
                    Text(ApxyDebugValueFormatters.timestamp(metrics.taskInterval.start))
                }
                LabeledContent("Ended") {
                    Text(ApxyDebugValueFormatters.timestamp(metrics.taskInterval.end))
                }
                LabeledContent("Redirects") {
                    Text("\(metrics.redirectCount)")
                }
                LabeledContent("Transactions") {
                    Text("\(metrics.transactions.count)")
                }
            }

            ForEach(metrics.transactions) { transaction in
                Section(transaction.fetchType.capitalized) {
                    if let requestURL = transaction.requestURL {
                        selectableValue(title: "Request URL", value: requestURL)
                    }
                    if let responseStatusCode = transaction.responseStatusCode {
                        LabeledContent("Status") {
                            Text("\(responseStatusCode)")
                        }
                    }
                    if let networkProtocolName = transaction.networkProtocolName {
                        LabeledContent("Protocol") {
                            Text(networkProtocolName)
                        }
                    }
                    if let localEndpoint = endpointText(address: transaction.localAddress, port: transaction.localPort) {
                        LabeledContent("Local Endpoint") {
                            Text(localEndpoint)
                        }
                    }
                    if let remoteEndpoint = endpointText(address: transaction.remoteAddress, port: transaction.remotePort) {
                        LabeledContent("Remote Endpoint") {
                            Text(remoteEndpoint)
                        }
                    }
                    LabeledContent("Reused Connection") {
                        Text(transaction.reusedConnection ? "Yes" : "No")
                    }
                    LabeledContent("Proxy Connection") {
                        Text(transaction.proxyConnection ? "Yes" : "No")
                    }

                    ForEach(timingRows(for: transaction), id: \.title) { row in
                        LabeledContent(row.title) {
                            Text(row.value)
                        }
                    }

                    LabeledContent("Request Bytes") {
                        Text(ApxyDebugValueFormatters.bytes(transaction.transfer.requestBodyBytesSent))
                    }
                    LabeledContent("Response Bytes") {
                        Text(ApxyDebugValueFormatters.bytes(transaction.transfer.responseBodyBytesReceived))
                    }
                }
            }
        } else {
            Section {
                Text("No task metrics captured")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func payloadSection(
        title: String,
        data: Data?,
        contentType: String?,
        size: Int64?,
        emptyMessage: String
    ) -> some View {
        Section(title) {
            LabeledContent("Content Type") {
                Text(contentType ?? "Unknown")
            }
            LabeledContent("Size") {
                Text(ApxyDebugValueFormatters.bytes(size ?? data.map { Int64($0.count) }))
            }

            if let displayText = ApxyDebugBodyFormatter.displayText(data: data, contentType: contentType) {
                disclosure("Show \(title)", content: displayText)
            } else {
                Text(emptyMessage)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func capsuleLabel(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(tint.opacity(0.14))
            .foregroundStyle(tint)
            .clipShape(Capsule())
    }

    private func summaryValue(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func selectableValue(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.enabled)
        }
    }

    private func selectableMonospaceText(_ value: String) -> some View {
        ScrollView(.horizontal) {
            Text(value)
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
        }
    }

    private func disclosure(_ title: String, content: String) -> some View {
        DisclosureGroup(title) {
            selectableMonospaceText(content)
        }
    }

    private func timingRows(
        for transaction: ApxyDebugRecord.Metrics.Transaction
    ) -> [(title: String, value: String)] {
        var rows: [(String, String)] = []

        func append(_ title: String, _ date: Date?) {
            guard let date else { return }
            rows.append((title, ApxyDebugValueFormatters.timestamp(date)))
        }

        append("Fetch Started", transaction.resourceFetchStart)
        append("DNS Started", transaction.domainLookupStart)
        append("DNS Ended", transaction.domainLookupEnd)
        append("Connect Started", transaction.connectStart)
        append("TLS Started", transaction.secureConnectionStart)
        append("TLS Ended", transaction.secureConnectionEnd)
        append("Connect Ended", transaction.connectEnd)
        append("Request Started", transaction.requestStart)
        append("Request Ended", transaction.requestEnd)
        append("Response Started", transaction.responseStart)
        append("Response Ended", transaction.responseEnd)

        return rows
    }

    private func endpointText(address: String?, port: Int?) -> String? {
        switch (address, port) {
        case let (.some(address), .some(port)):
            return "\(address):\(port)"
        case let (.some(address), .none):
            return address
        case let (.none, .some(port)):
            return "Port \(port)"
        case (.none, .none):
            return nil
        }
    }

    private var headerTitle: String {
        selectedRequestPath
    }

    private var headerSubtitle: String {
        if let currentHost = record.request.currentHost,
           currentHost != record.request.host {
            return "\(record.request.host) -> \(currentHost)"
        }
        return record.request.host
    }

    private var selectedRequestURL: String {
        if selectedRequestVariant == .current {
            return record.request.currentURL ?? record.request.url
        }
        return record.request.url
    }

    private var selectedRequestHost: String {
        if selectedRequestVariant == .current {
            return record.request.currentHost ?? record.request.host
        }
        return record.request.host
    }

    private var selectedRequestPath: String {
        if selectedRequestVariant == .current {
            return record.request.currentPath ?? record.request.path
        }
        return record.request.path
    }

    private var selectedRequestHeaders: [String: String] {
        if selectedRequestVariant == .current,
           !record.request.currentHeaders.isEmpty {
            return record.request.currentHeaders
        }
        return record.request.headers
    }

    private var showsCurrentRequest: Bool {
        if let currentURL = record.request.currentURL, currentURL != record.request.url {
            return true
        }
        if let currentHost = record.request.currentHost, currentHost != record.request.host {
            return true
        }
        if let currentPath = record.request.currentPath, currentPath != record.request.path {
            return true
        }
        return !record.request.currentHeaders.isEmpty
    }

    private var transferSummary: String {
        ApxyDebugValueFormatters.bytes(
            record.transfer.responseBodyBytesAfterDecoding
                ?? record.response?.bodySize
                ?? record.transfer.requestBodyBytesSent
                ?? record.request.bodySize
        )
    }

    private var statusHeaderText: String {
        if let error = record.error, record.response == nil {
            return error.message
        }
        if let response = record.response {
            return "HTTP \(response.statusCode)"
        }
        return "Pending"
    }

    private var statusColor: Color {
        if record.error != nil {
            return .red
        }
        if let statusCode = record.response?.statusCode {
            switch statusCode {
            case 200..<400:
                return .green
            case 400...:
                return .red
            default:
                return .orange
            }
        }
        return .orange
    }
}

private enum ApxyDebugInspectorTab: String, CaseIterable, Identifiable {
    case overview
    case request
    case response
    case metrics

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }
}

private enum ApxyDebugRequestVariant: String, CaseIterable, Identifiable {
    case original
    case current

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }
}

private struct ApxyDebugDetailListStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
#if os(macOS)
        content.listStyle(.automatic)
#else
        content
            .listStyle(.insetGrouped)
            .navigationBarTitleDisplayMode(.inline)
#endif
    }
}
