import SwiftUI
import ApxyCore

@available(iOS 16.0, macOS 13.0, *)
struct ApxyDebugRecordDetailView: View {
    let record: ApxyDebugRecord

    @State private var toastMessage: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = ApxyDebugTheme.palette(for: colorScheme)

        List {
            Section {
                headerCard
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
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
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

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

                    NavigationLink(value: ApxyDebugInspectorRoute.requestHeaders(requestSection.kind)) {
                        ApxyDebugInspectorRow(
                            icon: "list.bullet.rectangle.portrait.fill",
                            tint: theme.textSecondary,
                            title: requestSection.headersTitle,
                            detail: "\(requestSection.headers.count)",
                            isEnabled: !requestSection.headers.isEmpty
                        )
                    }
                    .disabled(requestSection.headers.isEmpty)

                    NavigationLink(value: ApxyDebugInspectorRoute.requestBody(requestSection.kind)) {
                        ApxyDebugInspectorRow(
                            icon: "arrow.up.circle.fill",
                            tint: theme.accent,
                            title: requestSection.bodyTitle,
                            detail: requestBodySummary,
                            isEnabled: true
                        )
                    }
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }

            Section("Cookies") {
                ForEach(requestSections) { requestSection in
                    NavigationLink(value: ApxyDebugInspectorRoute.requestCookies(requestSection.kind)) {
                        ApxyDebugInspectorRow(
                            icon: "lock.square.stack.fill",
                            tint: theme.textSecondary,
                            title: requestSection.cookiesTitle,
                            detail: "\(requestSection.cookies.count)",
                            isEnabled: !requestSection.cookies.isEmpty
                        )
                    }
                    .disabled(requestSection.cookies.isEmpty)
                }

                NavigationLink(value: ApxyDebugInspectorRoute.responseCookies) {
                    ApxyDebugInspectorRow(
                        icon: "lock.square.stack.fill",
                        tint: theme.textSecondary,
                        title: "Response Cookies",
                        detail: "\(responseCookies.count)",
                        isEnabled: !responseCookies.isEmpty
                    )
                }
                .disabled(responseCookies.isEmpty)
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

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

                    NavigationLink(value: ApxyDebugInspectorRoute.responseHeaders) {
                        ApxyDebugInspectorRow(
                            icon: "text.append",
                            tint: theme.textSecondary,
                            title: "Response Headers",
                            detail: "\(response.headers.count)",
                            isEnabled: !response.headers.isEmpty
                        )
                    }
                    .disabled(response.headers.isEmpty)

                    NavigationLink(value: ApxyDebugInspectorRoute.responseBody) {
                        ApxyDebugInspectorRow(
                            icon: "arrow.down.circle.fill",
                            tint: theme.accentHover,
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
                                tint: theme.accentHover,
                                title: "Copy JSON",
                                detail: "",
                                isEnabled: true
                            )
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Text("No response captured")
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

            Section("Actions") {
                Button {
                    copyToClipboard(defaultCurlText, message: "cURL copied")
                } label: {
                    ApxyDebugInspectorRow(
                        icon: "terminal.fill",
                        tint: theme.textSecondary,
                        title: "Copy cURL",
                        detail: ""
                    )
                }
                .buttonStyle(.plain)

                if record.metrics != nil {
                    NavigationLink(value: ApxyDebugInspectorRoute.metrics) {
                        ApxyDebugInspectorRow(
                            icon: "chart.xyaxis.line",
                            tint: theme.warning,
                            title: "Metrics Timeline",
                            detail: "\(record.metrics?.transactions.count ?? 0)"
                        )
                    }
                }

                if record.error != nil {
                    NavigationLink(value: ApxyDebugInspectorRoute.error) {
                        ApxyDebugInspectorRow(
                            icon: "exclamationmark.octagon.fill",
                            tint: theme.error,
                            title: "Error Details",
                            detail: ""
                        )
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        }
        .modifier(ApxyDebugDetailListStyleModifier())
        .navigationTitle("Request Details")
        .tint(theme.accent)
        .apxyNavigationChrome(theme: theme, colorScheme: colorScheme)
        .overlay {
            VStack {
                Spacer()
                if let toastMessage {
                    ApxyDebugToastView(message: toastMessage)
                        .padding(.bottom, 12)
                        .transition(toastTransition)
                }
            }
        }
        .animation(toastAnimation, value: toastMessage)
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

    private var toastTransition: AnyTransition {
        reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity)
    }

    private var toastAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.3, bounce: 0.2)
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

    private var theme: ApxyDebugThemePalette {
        ApxyDebugTheme.palette(for: colorScheme)
    }

    private var statusColor: Color { statusPresentation.color(in: theme) }
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
#Preview("Record Detail Light iOS") {
    NavigationStack {
        ApxyDebugRecordDetailView(record: ApxyDebugPreviewFixtures.failedRecord)
    }
    .apxyPreviewDetail(.iOS)
    .preferredColorScheme(.light)
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Record Detail Dark macOS") {
    NavigationStack {
        ApxyDebugRecordDetailView(record: ApxyDebugPreviewFixtures.failedRecord)
    }
    .apxyPreviewDetail(.macOS)
    .preferredColorScheme(.dark)
}
#endif

struct ApxyDebugRequestSection: Identifiable {
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
