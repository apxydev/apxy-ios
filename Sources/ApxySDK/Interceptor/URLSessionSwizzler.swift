import Foundation
import ObjectiveC

/// Registers `ApxyURLProtocol` with the URL loading system so **all** `URLSession`
/// traffic is observed — including Combine (`dataTaskPublisher`), async/await
/// (`data(for:)`), and custom `URLSession(configuration:)` instances.
///
/// `URLProtocol.registerClass` alone only affects `URLSession.shared`. Custom
/// sessions copy `protocolClasses` from `URLSessionConfiguration` at creation
/// time, so we swizzle `+[NSURLSessionConfiguration defaultSessionConfiguration]`
/// and `ephemeralSessionConfiguration` to prepend `ApxyURLProtocol`.
///
/// SDK-internal requests are excluded via `X-Apxy-SDK-Internal` in
/// `ApxyURLProtocol.canInit(with:)`. The internal `URLSession` used by
/// `ApxyURLProtocol` sets `protocolClasses = []` after obtaining the default
/// config, overriding any injection (no infinite recursion).
enum URLSessionSwizzler {
    private static var installed = false

    private static let configClass: AnyClass = URLSessionConfiguration.self

    private static let defaultConfigSelector = NSSelectorFromString("defaultSessionConfiguration")
    private static let ephemeralConfigSelector = NSSelectorFromString("ephemeralSessionConfiguration")

    private static var originalDefaultIMP: IMP?
    private static var originalEphemeralIMP: IMP?

    static func install() {
        guard !installed else { return }
        installed = true

        URLProtocol.registerClass(ApxyURLProtocol.self)

        swizzleClassMethod(selector: defaultConfigSelector, original: &originalDefaultIMP)
        swizzleClassMethod(selector: ephemeralConfigSelector, original: &originalEphemeralIMP)

        SDKLogger.debug(
            "URLSessionSwizzler installed (ApxyURLProtocol + URLSessionConfiguration factory swizzle)"
        )
    }

    static func uninstall() {
        guard installed else { return }
        installed = false

        URLProtocol.unregisterClass(ApxyURLProtocol.self)

        restoreClassMethod(selector: defaultConfigSelector, original: &originalDefaultIMP)
        restoreClassMethod(selector: ephemeralConfigSelector, original: &originalEphemeralIMP)

        SDKLogger.debug("URLSessionSwizzler uninstalled")
    }

    // MARK: - Private

    private static func injectApxyProtocol(into configuration: URLSessionConfiguration) {
        var classes = configuration.protocolClasses ?? []
        guard !classes.contains(where: { $0 == ApxyURLProtocol.self }) else { return }
        classes.insert(ApxyURLProtocol.self, at: 0)
        configuration.protocolClasses = classes
    }

    private static func swizzleClassMethod(selector: Selector, original: inout IMP?) {
        guard let method = class_getClassMethod(configClass, selector) else {
            SDKLogger.warn("URLSessionSwizzler: missing class method for \(NSStringFromSelector(selector))")
            return
        }
        original = method_getImplementation(method)

        typealias Factory = @convention(c) (AnyClass?, Selector) -> URLSessionConfiguration
        guard let origIMP = original else { return }

        let block: @convention(block) () -> URLSessionConfiguration = {
            let callOriginal = unsafeBitCast(origIMP, to: Factory.self)
            let configuration = callOriginal(configClass as AnyClass?, selector)
            injectApxyProtocol(into: configuration)
            return configuration
        }

        method_setImplementation(method, imp_implementationWithBlock(block))
    }

    private static func restoreClassMethod(selector: Selector, original: inout IMP?) {
        guard let imp = original else { return }
        guard let method = class_getClassMethod(configClass, selector) else {
            original = nil
            return
        }
        method_setImplementation(method, imp)
        original = nil
    }
}
