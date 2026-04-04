import SwiftUI
import ApxyCore

@available(iOS 16.0, macOS 13.0, *)
struct ApxyDebugRecordDetailView: View {
    let record: ApxyDebugRecord

    @State private var toastMessage: String?

    var body: some View {
        List {
            Section {
                headerCard
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)

            Section("Summary") {
                LabeledContent("Status") {
                    Text(statusHeaderText)
                        .foregroundStyle(statusColor)
                }
                LabeledContent("Captured") {
                    Text(ApxyDebugValueFormatters.timestamp(record.capturedAt))
                }
                LabeledContent("Duration") {
                    Text(ApxyDebugValueFormatters.duration(record.duration))
                        .monospacedDigit()
                }
                LabeledContent("Transferred") {
                    Text(transferSummary)
                }
                if let sessionID = record.sessionID, !sessionID.isEmpty {
                    LabeledContent("Session") {
                        Text(String(sessionID.prefix(8)))
                    }
                }
            }

            ForEach(requestSections) { requestSection in
                Section(requestSection.sectionTitle) {
                    LabeledContent("Method") {
                        Text(record.request.method)
                    }
                    LabeledContent("Host") {
                        Text(requestSection.host)
                    }
                    LabeledContent("Path") {
                        Text(requestSection.path)
                    }
                    selectableValue(title: "URL", value: requestSection.url)

                    NavigationLink {
                        makeDestination(for: .requestHeaders(requestSection.kind))
                    } label: {
                        ApxyDebugInspectorRow(
                            icon: "list.bullet.rectangle.portrait.fill",
                            tint: .secondary,
                            title: requestSection.headersTitle,
                            detail: "\(requestSection.headers.count)",
                            isEnabled: !requestSection.headers.isEmpty
                        )
                    }
                    .disabled(requestSection.headers.isEmpty)

                    NavigationLink {
                        makeDestination(for: .requestBody(requestSection.kind))
                    } label: {
                        ApxyDebugInspectorRow(
                            icon: "arrow.up.circle.fill",
                            tint: .blue,
                            title: requestSection.bodyTitle,
                            detail: requestBodySummary,
                            isEnabled: true
                        )
                    }
                }
            }

            Section("Cookies") {
                ForEach(requestSections) { requestSection in
                    NavigationLink {
                        makeDestination(for: .requestCookies(requestSection.kind))
                    } label: {
                        ApxyDebugInspectorRow(
                            icon: "lock.square.stack.fill",
                            tint: .secondary,
                            title: requestSection.cookiesTitle,
                            detail: "\(requestSection.cookies.count)",
                            isEnabled: !requestSection.cookies.isEmpty
                        )
                    }
                    .disabled(requestSection.cookies.isEmpty)
                }

                NavigationLink {
                    makeDestination(for: .responseCookies)
                } label: {
                    ApxyDebugInspectorRow(
                        icon: "lock.square.stack.fill",
                        tint: .secondary,
                        title: "Response Cookies",
                        detail: "\(responseCookies.count)",
                        isEnabled: !responseCookies.isEmpty
                    )
                }
                .disabled(responseCookies.isEmpty)
            }

            Section("Response") {
                if let response = record.response {
                    LabeledContent("Status Code") {
                        Text("\(response.statusCode)")
                            .foregroundStyle(statusColor)
                    }
                    LabeledContent("Content Type") {
                        Text(response.contentType ?? "Unknown")
                    }
                    LabeledContent("Body Size") {
                        Text(responseBodySummary)
                    }

                    NavigationLink {
                        makeDestination(for: .responseHeaders)
                    } label: {
                        ApxyDebugInspectorRow(
                            icon: "text.append",
                            tint: .secondary,
                            title: "Response Headers",
                            detail: "\(response.headers.count)",
                            isEnabled: !response.headers.isEmpty
                        )
                    }
                    .disabled(response.headers.isEmpty)

                    NavigationLink {
                        makeDestination(for: .responseBody)
                    } label: {
                        ApxyDebugInspectorRow(
                            icon: "arrow.down.circle.fill",
                            tint: .indigo,
                            title: "Response Body",
                            detail: responseBodySummary,
                            isEnabled: true
                        )
                    }

                    if canCopyResponseJSON {
                        Button {
                            copyToClipboard(responseBodyText, message: "JSON copied")
                        } label: {
                            ApxyDebugInspectorRow(
                                icon: "curlybraces",
                                tint: .indigo,
                                title: "Copy JSON",
                                detail: "",
                                isEnabled: true
                            )
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Text("No response captured")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Actions") {
                Button {
                    copyToClipboard(defaultCurlText, message: "cURL copied")
                } label: {
                    ApxyDebugInspectorRow(
                        icon: "terminal.fill",
                        tint: .secondary,
                        title: "Copy cURL",
                        detail: ""
                    )
                }
                .buttonStyle(.plain)

                if record.metrics != nil {
                    NavigationLink {
                        makeDestination(for: .metrics)
                    } label: {
                        ApxyDebugInspectorRow(
                            icon: "chart.xyaxis.line",
                            tint: .orange,
                            title: "Metrics Timeline",
                            detail: "\(record.metrics?.transactions.count ?? 0)"
                        )
                    }
                }

                if record.error != nil {
                    NavigationLink {
                        makeDestination(for: .error)
                    } label: {
                        ApxyDebugInspectorRow(
                            icon: "exclamationmark.octagon.fill",
                            tint: .red,
                            title: "Error Details",
                            detail: ""
                        )
                    }
                }
            }
        }
        .modifier(ApxyDebugDetailListStyleModifier())
        .navigationTitle("Request Details")
        .overlay(alignment: .bottom) {
            if let toastMessage {
                ApxyDebugToastView(message: toastMessage)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3, bounce: 0.2), value: toastMessage)
        .task(id: toastMessage) {
            guard toastMessage != nil else { return }
            try? await Task.sleep(for: .seconds(1.5))
            if !Task.isCancelled { toastMessage = nil }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu("Actions", systemImage: "ellipsis.circle") {
                    Button("Copy URL") {
                        copyToClipboard(defaultRequestSection.url, message: "URL copied")
                    }
                    Button("Copy Headers") {
                        copyToClipboard(
                            ApxyDebugValueFormatters.headers(defaultRequestSection.headers),
                            message: "Headers copied"
                        )
                    }
                    if canCopyRequestBody {
                        Button("Copy Request Body") {
                            copyToClipboard(requestBodyText, message: "Request body copied")
                        }
                    }
                    if canCopyResponseBody {
                        Button("Copy Response Body") {
                            copyToClipboard(responseBodyText, message: "Response body copied")
                        }
                    }
                    if canCopyResponseJSON {
                        Button("Copy JSON") {
                            copyToClipboard(responseBodyText, message: "JSON copied")
                        }
                    }
                    Button("Copy cURL") {
                        copyToClipboard(defaultCurlText, message: "cURL copied")
                    }
                    if let jsonText = recordJSONText {
                        ShareLink(item: jsonText) {
                            Label("Share Record JSON", systemImage: "square.and.arrow.up")
                        }
                    }
                    ShareLink(item: defaultCurlText) {
                        Label("Share cURL", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func makeDestination(for destination: ApxyDebugInspectorDestination) -> some View {
        switch destination {
        case let .requestHeaders(kind):
            let section = requestSection(for: kind)
            ApxyDebugTextDetailView(
                title: section.headersTitle,
                text: ApxyDebugValueFormatters.headers(section.headers),
                emptyMessage: "No headers"
            )
        case let .requestCookies(kind):
            let section = requestSection(for: kind)
            ApxyDebugTextDetailView(
                title: section.cookiesTitle,
                text: ApxyDebugCookiesFormatter.detailsText(for: section.cookies),
                emptyMessage: "No cookies"
            )
        case let .requestBody(kind):
            let section = requestSection(for: kind)
            ApxyDebugBodyDetailView(
                title: section.bodyTitle,
                contentType: record.request.contentType,
                size: requestBodySize,
                presentation: requestBodyPresentation,
                quickCopyTitle: canCopyRequestBody ? "Copy Body" : nil,
                onQuickCopy: canCopyRequestBody ? {
                    copyToClipboard(requestBodyText, message: "Request body copied")
                } : nil
            )
        case .responseHeaders:
            ApxyDebugTextDetailView(
                title: "Response Headers",
                text: ApxyDebugValueFormatters.headers(record.response?.headers ?? [:]),
                emptyMessage: "No headers"
            )
        case .responseCookies:
            ApxyDebugTextDetailView(
                title: "Response Cookies",
                text: ApxyDebugCookiesFormatter.detailsText(for: responseCookies),
                emptyMessage: "No cookies"
            )
        case .responseBody:
            ApxyDebugBodyDetailView(
                title: "Response Body",
                contentType: record.response?.contentType,
                size: responseBodySize,
                presentation: responseBodyPresentation,
                quickCopyTitle: responseQuickCopyTitle,
                onQuickCopy: responseQuickCopyAction
            )
        case .metrics:
            metricsDetailView
        case .error:
            ApxyDebugTextDetailView(
                title: "Error Details",
                text: errorText,
                emptyMessage: "No error details"
            )
        }
    }

    private var headerCard: some View {
        ApxyDebugRecordHeaderCard(
            method: record.request.method,
            isMocked: record.isMocked,
            isTLS: record.isTLS,
            host: defaultRequestSection.host,
            path: defaultRequestSection.path,
            statusText: statusHeaderText,
            statusSymbol: statusSymbol,
            statusColor: statusColor,
            durationText: ApxyDebugValueFormatters.duration(record.duration),
            url: defaultRequestSection.url
        )
    }

    @ViewBuilder
    private var metricsDetailView: some View {
        if let metrics = record.metrics {
            List {
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
            }
            .navigationTitle("Metrics Timeline")
        } else {
            ApxyDebugTextDetailView(title: "Metrics Timeline", text: "", emptyMessage: "No task metrics captured")
        }
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

    private var requestSections: [ApxyDebugRequestSection] {
        if hasFinalRequest {
            return [
                .init(
                    kind: .final,
                    sectionTitle: "Final Request",
                    headersTitle: "Final Request Headers",
                    cookiesTitle: "Final Request Cookies",
                    bodyTitle: "Request Body",
                    url: record.request.currentURL ?? record.request.url,
                    host: record.request.currentHost ?? record.request.host,
                    path: record.request.currentPath ?? record.request.path,
                    headers: record.request.currentHeaders.isEmpty ? record.request.headers : record.request.currentHeaders
                ),
                .init(
                    kind: .original,
                    sectionTitle: "Original Request",
                    headersTitle: "Original Request Headers",
                    cookiesTitle: "Original Request Cookies",
                    bodyTitle: "Request Body",
                    url: record.request.url,
                    host: record.request.host,
                    path: record.request.path,
                    headers: record.request.headers
                )
            ]
        }

        return [
            .init(
                kind: .single,
                sectionTitle: "Request",
                headersTitle: "Request Headers",
                cookiesTitle: "Request Cookies",
                bodyTitle: "Request Body",
                url: record.request.url,
                host: record.request.host,
                path: record.request.path,
                headers: record.request.headers
            )
        ]
    }

    private func requestSection(for kind: ApxyDebugRequestKind) -> ApxyDebugRequestSection {
        requestSections.first(where: { $0.kind == kind }) ?? defaultRequestSection
    }

    private var defaultRequestSection: ApxyDebugRequestSection {
        requestSections[0]
    }

    private var hasFinalRequest: Bool {
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

    private var statusHeaderText: String {
        if let error = record.error, record.response == nil {
            return error.message
        }
        if let response = record.response {
            return "HTTP \(response.statusCode)"
        }
        return "Pending"
    }

    private var statusPresentation: ApxyDebugStatusPresentation {
        .from(record: record)
    }

    private var statusColor: Color { statusPresentation.color }
    private var statusSymbol: String { statusPresentation.iconName }

    private var requestBodySize: Int64? {
        record.request.bodySize ?? record.request.body.map { Int64($0.count) }
    }

    private var responseBodySize: Int64? {
        record.response?.bodySize ?? record.response?.body.map { Int64($0.count) }
    }

    private var requestBodyPresentation: ApxyDebugBodyFormatter.Presentation {
        ApxyDebugBodyFormatter.presentation(
            data: record.request.body,
            contentType: record.request.contentType,
            bodySize: requestBodySize
        )
    }

    private var responseBodyPresentation: ApxyDebugBodyFormatter.Presentation {
        ApxyDebugBodyFormatter.presentation(
            data: record.response?.body,
            contentType: record.response?.contentType,
            bodySize: responseBodySize
        )
    }

    private var requestBodyText: String {
        bodyText(from: requestBodyPresentation)
    }

    private var responseBodyText: String {
        bodyText(from: responseBodyPresentation)
    }

    private func bodyText(from presentation: ApxyDebugBodyFormatter.Presentation) -> String {
        switch presentation {
        case let .text(text):
            return text
        case .empty:
            return "Empty body"
        case .unavailable:
            return ""
        case let .binary(summary):
            return "Binary body (\(summary))"
        }
    }

    private var requestBodySummary: String {
        bodySummary(for: requestBodyPresentation, size: requestBodySize)
    }

    private var responseBodySummary: String {
        bodySummary(for: responseBodyPresentation, size: responseBodySize)
    }

    private func bodySummary(for presentation: ApxyDebugBodyFormatter.Presentation, size: Int64?) -> String {
        switch presentation {
        case .empty:
            return "Empty"
        case .unavailable:
            return "Unavailable"
        case .text, .binary:
            return ApxyDebugValueFormatters.bytes(size)
        }
    }

    private var responseCookies: [HTTPCookie] {
        guard let response = record.response else { return [] }
        return ApxyDebugCookiesFormatter.cookies(headers: response.headers, urlString: defaultRequestSection.url)
    }

    private var canCopyRequestBody: Bool {
        if case .text = requestBodyPresentation {
            return true
        }
        return false
    }

    private var canCopyResponseBody: Bool {
        if case .text = responseBodyPresentation {
            return true
        }
        return false
    }

    private var canCopyResponseJSON: Bool {
        guard case .text = responseBodyPresentation,
              let contentType = record.response?.contentType?.lowercased() else {
            return false
        }
        return contentType.contains("json") || contentType.contains("+json")
    }

    private var responseQuickCopyTitle: String? {
        if canCopyResponseJSON {
            return "Copy JSON"
        }
        if canCopyResponseBody {
            return "Copy Body"
        }
        return nil
    }

    private var responseQuickCopyAction: (() -> Void)? {
        if canCopyResponseJSON {
            return { copyToClipboard(responseBodyText, message: "JSON copied") }
        }
        if canCopyResponseBody {
            return { copyToClipboard(responseBodyText, message: "Response body copied") }
        }
        return nil
    }

    private var defaultCurlText: String {
        ApxyDebugCurlFormatter.makeCurl(for: record, useCurrentRequest: hasFinalRequest)
    }

    private var transferSummary: String {
        ApxyDebugValueFormatters.bytes(
            record.transfer.responseBodyBytesAfterDecoding
                ?? record.response?.bodySize
                ?? record.transfer.requestBodyBytesSent
                ?? record.request.bodySize
        )
    }

    private var errorText: String {
        guard let error = record.error else { return "" }
        return """
        Domain: \(error.domain)
        Code: \(error.code)
        Message: \(error.message)
        """
    }

    private var recordJSONText: String? {
        ApxyDebugRecordExportFormatter.jsonString(for: record)
    }

    private func copyToClipboard(_ value: String, message: String) {
        guard !value.isEmpty else { return }
        ApxyDebugClipboard.copy(value)
        toastMessage = message
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Record Detail") {
    NavigationStack {
        ApxyDebugRecordDetailView(record: ApxyDebugPreviewFixtures.failedRecord)
    }
}
#endif

private struct ApxyDebugRequestSection: Identifiable {
    let kind: ApxyDebugRequestKind
    let sectionTitle: String
    let headersTitle: String
    let cookiesTitle: String
    let bodyTitle: String
    let url: String
    let host: String
    let path: String
    let headers: [String: String]

    var id: ApxyDebugRequestKind { kind }

    var cookies: [HTTPCookie] {
        ApxyDebugCookiesFormatter.cookies(headers: headers, urlString: url)
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
