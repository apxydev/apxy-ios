import SwiftUI
import ApxyCore

@available(iOS 16.0, macOS 13.0, *)
struct ApxyDebugInspectorRouteView: View {
    let destination: ApxyDebugInspectorRoute
    let record: ApxyDebugRecord

    @State private var toastMessage: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
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
            .overlay(toastOverlay)
            .animation(toastAnimation, value: toastMessage)
            .task(id: toastMessage) { await dismissToast() }
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
            .overlay(toastOverlay)
            .animation(toastAnimation, value: toastMessage)
            .task(id: toastMessage) { await dismissToast() }
        case .metrics:
            metricsView
        case .error:
            ApxyDebugTextDetailView(
                title: "Error Details",
                text: errorText,
                emptyMessage: "No error details"
            )
        }
    }

    // MARK: - Metrics

    @ViewBuilder
    private var metricsView: some View {
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
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

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
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
            }
            .modifier(ApxyDebugDetailListStyleModifier())
            .navigationTitle("Metrics Timeline")
        } else {
            ApxyDebugTextDetailView(title: "Metrics Timeline", text: "", emptyMessage: "No task metrics captured")
        }
    }

    // MARK: - Toast

    private var toastOverlay: some View {
        VStack {
            Spacer()
            if let toastMessage {
                ApxyDebugToastView(message: toastMessage)
                    .padding(.bottom, 12)
                    .transition(toastTransition)
            }
        }
    }

    private var toastTransition: AnyTransition {
        reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity)
    }

    private var toastAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.3, bounce: 0.2)
    }

    private func dismissToast() async {
        guard toastMessage != nil else { return }
        try? await Task.sleep(for: .seconds(1.5))
        if !Task.isCancelled { toastMessage = nil }
    }

    // MARK: - Request data

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
        requestSections.first(where: { $0.kind == kind }) ?? requestSections[0]
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

    private var defaultRequestSection: ApxyDebugRequestSection { requestSections[0] }

    // MARK: - Body

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

    private var requestBodyText: String { bodyText(from: requestBodyPresentation) }
    private var responseBodyText: String { bodyText(from: responseBodyPresentation) }

    private func bodyText(from presentation: ApxyDebugBodyFormatter.Presentation) -> String {
        switch presentation {
        case let .text(text): return text
        case .empty: return "Empty body"
        case .unavailable: return ""
        case let .binary(summary): return "Binary body (\(summary))"
        }
    }

    private var responseCookies: [HTTPCookie] {
        guard let response = record.response else { return [] }
        return ApxyDebugCookiesFormatter.cookies(headers: response.headers, urlString: defaultRequestSection.url)
    }

    private var canCopyRequestBody: Bool {
        if case .text = requestBodyPresentation { return true }
        return false
    }

    private var canCopyResponseBody: Bool {
        if case .text = responseBodyPresentation { return true }
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
        if canCopyResponseJSON { return "Copy JSON" }
        if canCopyResponseBody { return "Copy Body" }
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

    private var errorText: String {
        guard let error = record.error else { return "" }
        return """
        Domain: \(error.domain)
        Code: \(error.code)
        Message: \(error.message)
        """
    }

    // MARK: - Helpers

    private func copyToClipboard(_ value: String, message: String) {
        guard !value.isEmpty else { return }
        ApxyDebugClipboard.copy(value)
        toastMessage = message
    }

    private func selectableValue(title: String, value: String) -> some View {
        let theme = ApxyDebugTheme.palette(for: colorScheme)
        return VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .bold()
                .foregroundStyle(theme.textSecondary)
            Text(value)
                .foregroundStyle(theme.textPrimary)
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
        case let (.some(address), .some(port)): return "\(address):\(port)"
        case let (.some(address), .none): return address
        case let (.none, .some(port)): return "Port \(port)"
        case (.none, .none): return nil
        }
    }
}
