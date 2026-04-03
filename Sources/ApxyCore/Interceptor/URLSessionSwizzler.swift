import Foundation
import ObjectiveC

/// Registers `ApxyURLProtocol` with the URL loading system so shared/default
/// and ephemeral URLSession configurations are intercepted automatically.
///
/// Custom sessions with bespoke `URLSessionConfiguration` instances should opt in
/// explicitly by adding `ApxyURLProtocol.self` to `protocolClasses`.
enum URLSessionSwizzler {
    private static let stateLock = NSLock()
    nonisolated(unsafe) private static var installed = false

    private static let configClass: AnyClass = URLSessionConfiguration.self
    private static let sessionClass: AnyClass = URLSession.self

    private static let defaultConfigSelector = NSSelectorFromString("defaultSessionConfiguration")
    private static let ephemeralConfigSelector = NSSelectorFromString("ephemeralSessionConfiguration")
    private static let uploadTaskWithRequestFromDataSelector = NSSelectorFromString("uploadTaskWithRequest:fromData:")
    private static let uploadTaskWithRequestFromDataCompletionSelector = NSSelectorFromString("uploadTaskWithRequest:fromData:completionHandler:")
    private static let uploadTaskWithRequestFromFileSelector = NSSelectorFromString("uploadTaskWithRequest:fromFile:")
    private static let uploadTaskWithRequestFromFileCompletionSelector = NSSelectorFromString("uploadTaskWithRequest:fromFile:completionHandler:")

    nonisolated(unsafe) private static var originalDefaultIMP: IMP?
    nonisolated(unsafe) private static var originalEphemeralIMP: IMP?
    nonisolated(unsafe) private static var originalUploadTaskWithRequestFromDataIMP: IMP?
    nonisolated(unsafe) private static var originalUploadTaskWithRequestFromDataCompletionIMP: IMP?
    nonisolated(unsafe) private static var originalUploadTaskWithRequestFromFileIMP: IMP?
    nonisolated(unsafe) private static var originalUploadTaskWithRequestFromFileCompletionIMP: IMP?

    static var isInstalled: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return installed
    }

    static func install() {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard !installed else { return }
        installed = true

        URLProtocol.registerClass(ApxyURLProtocol.self)

        swizzleClassMethod(selector: defaultConfigSelector, original: &originalDefaultIMP)
        swizzleClassMethod(selector: ephemeralConfigSelector, original: &originalEphemeralIMP)
        swizzleUploadTaskFactoryMethods()

        SDKLogger.debug(
            "URLSessionSwizzler installed (automatic shared/default/ephemeral interception)"
        )
    }

    static func uninstall() {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard installed else { return }
        installed = false

        URLProtocol.unregisterClass(ApxyURLProtocol.self)

        restoreClassMethod(selector: defaultConfigSelector, original: &originalDefaultIMP)
        restoreClassMethod(selector: ephemeralConfigSelector, original: &originalEphemeralIMP)
        restoreUploadTaskFactoryMethods()

        SDKLogger.debug("URLSessionSwizzler uninstalled")
    }

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
        guard let original else { return }

        let block: @convention(block) () -> URLSessionConfiguration = {
            let callOriginal = unsafeBitCast(original, to: Factory.self)
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

    private static func swizzleUploadTaskFactoryMethods() {
        swizzleUploadTaskFromDataMethod(
            selector: uploadTaskWithRequestFromDataSelector,
            original: &originalUploadTaskWithRequestFromDataIMP
        )
        swizzleUploadTaskFromDataCompletionMethod(
            selector: uploadTaskWithRequestFromDataCompletionSelector,
            original: &originalUploadTaskWithRequestFromDataCompletionIMP
        )
        swizzleUploadTaskFromFileMethod(
            selector: uploadTaskWithRequestFromFileSelector,
            original: &originalUploadTaskWithRequestFromFileIMP
        )
        swizzleUploadTaskFromFileCompletionMethod(
            selector: uploadTaskWithRequestFromFileCompletionSelector,
            original: &originalUploadTaskWithRequestFromFileCompletionIMP
        )
    }

    private static func restoreUploadTaskFactoryMethods() {
        restoreUploadTaskFactoryMethod(
            selector: uploadTaskWithRequestFromDataSelector,
            original: &originalUploadTaskWithRequestFromDataIMP
        )
        restoreUploadTaskFactoryMethod(
            selector: uploadTaskWithRequestFromDataCompletionSelector,
            original: &originalUploadTaskWithRequestFromDataCompletionIMP
        )
        restoreUploadTaskFactoryMethod(
            selector: uploadTaskWithRequestFromFileSelector,
            original: &originalUploadTaskWithRequestFromFileIMP
        )
        restoreUploadTaskFactoryMethod(
            selector: uploadTaskWithRequestFromFileCompletionSelector,
            original: &originalUploadTaskWithRequestFromFileCompletionIMP
        )
    }

    private static func swizzleUploadTaskFromDataMethod(selector: Selector, original: inout IMP?) {
        guard let method = class_getInstanceMethod(sessionClass, selector) else {
            SDKLogger.warn("URLSessionSwizzler: missing upload task method for \(NSStringFromSelector(selector))")
            return
        }

        original = method_getImplementation(method)

        typealias Factory = @convention(c) (AnyObject, Selector, NSURLRequest, NSData?) -> URLSessionUploadTask
        guard let original else { return }

        let block: @convention(block) (AnyObject, NSURLRequest, NSData?) -> URLSessionUploadTask = {
            receiver, request, bodyData in
            let policy = ApxyURLProtocol.capturePolicy
            let annotatedRequest = ApxyURLProtocol.annotateUploadRequest(
                request,
                bodyData: ApxyURLProtocol.truncatedBody(from: bodyData as Data?, maxBytes: policy.maxRequestBodyBytes),
                source: .uploadTaskData
            )
            let callOriginal = unsafeBitCast(original, to: Factory.self)
            return callOriginal(receiver, selector, annotatedRequest as NSURLRequest, bodyData)
        }

        method_setImplementation(method, imp_implementationWithBlock(block))
    }

    private static func swizzleUploadTaskFromDataCompletionMethod(selector: Selector, original: inout IMP?) {
        guard let method = class_getInstanceMethod(sessionClass, selector) else {
            SDKLogger.warn("URLSessionSwizzler: missing upload task method for \(NSStringFromSelector(selector))")
            return
        }

        original = method_getImplementation(method)

        typealias Factory = @convention(c) (AnyObject, Selector, NSURLRequest, NSData?, AnyObject) -> URLSessionUploadTask
        guard let original else { return }

        let block: @convention(block) (AnyObject, NSURLRequest, NSData?, AnyObject) -> URLSessionUploadTask = {
            receiver, request, bodyData, completion in
            let policy = ApxyURLProtocol.capturePolicy
            let annotatedRequest = ApxyURLProtocol.annotateUploadRequest(
                request,
                bodyData: ApxyURLProtocol.truncatedBody(from: bodyData as Data?, maxBytes: policy.maxRequestBodyBytes),
                source: .uploadTaskData
            )
            let callOriginal = unsafeBitCast(original, to: Factory.self)
            return callOriginal(receiver, selector, annotatedRequest as NSURLRequest, bodyData, completion)
        }

        method_setImplementation(method, imp_implementationWithBlock(block))
    }

    private static func swizzleUploadTaskFromFileMethod(selector: Selector, original: inout IMP?) {
        guard let method = class_getInstanceMethod(sessionClass, selector) else {
            SDKLogger.warn("URLSessionSwizzler: missing upload task method for \(NSStringFromSelector(selector))")
            return
        }

        original = method_getImplementation(method)

        typealias Factory = @convention(c) (AnyObject, Selector, NSURLRequest, NSURL?) -> URLSessionUploadTask
        guard let original else { return }

        let block: @convention(block) (AnyObject, NSURLRequest, NSURL?) -> URLSessionUploadTask = {
            receiver, request, fileURL in
            let policy = ApxyURLProtocol.capturePolicy
            let source: RequestBodyCaptureSource
            let bodyData: Data?
            if policy.captureUploadFileBodies {
                source = .uploadTaskFile
                bodyData = (fileURL as URL?).flatMap {
                    readPrefix(fromUploadFile: $0, maxBytes: policy.maxRequestBodyBytes)
                }
                if fileURL != nil, bodyData == nil, policy.maxRequestBodyBytes > 0 {
                    SDKLogger.warn("URLSessionSwizzler: failed reading upload file body for capture")
                }
            } else {
                source = .uploadTaskFileSkipped
                bodyData = nil
            }

            let annotatedRequest = ApxyURLProtocol.annotateUploadRequest(
                request,
                bodyData: bodyData,
                source: source
            )
            let callOriginal = unsafeBitCast(original, to: Factory.self)
            return callOriginal(receiver, selector, annotatedRequest as NSURLRequest, fileURL)
        }

        method_setImplementation(method, imp_implementationWithBlock(block))
    }

    private static func swizzleUploadTaskFromFileCompletionMethod(selector: Selector, original: inout IMP?) {
        guard let method = class_getInstanceMethod(sessionClass, selector) else {
            SDKLogger.warn("URLSessionSwizzler: missing upload task method for \(NSStringFromSelector(selector))")
            return
        }

        original = method_getImplementation(method)

        typealias Factory = @convention(c) (AnyObject, Selector, NSURLRequest, NSURL?, AnyObject) -> URLSessionUploadTask
        guard let original else { return }

        let block: @convention(block) (AnyObject, NSURLRequest, NSURL?, AnyObject) -> URLSessionUploadTask = {
            receiver, request, fileURL, completion in
            let policy = ApxyURLProtocol.capturePolicy
            let source: RequestBodyCaptureSource
            let bodyData: Data?
            if policy.captureUploadFileBodies {
                source = .uploadTaskFile
                bodyData = (fileURL as URL?).flatMap {
                    readPrefix(fromUploadFile: $0, maxBytes: policy.maxRequestBodyBytes)
                }
                if fileURL != nil, bodyData == nil, policy.maxRequestBodyBytes > 0 {
                    SDKLogger.warn("URLSessionSwizzler: failed reading upload file body for capture")
                }
            } else {
                source = .uploadTaskFileSkipped
                bodyData = nil
            }

            let annotatedRequest = ApxyURLProtocol.annotateUploadRequest(
                request,
                bodyData: bodyData,
                source: source
            )
            let callOriginal = unsafeBitCast(original, to: Factory.self)
            return callOriginal(receiver, selector, annotatedRequest as NSURLRequest, fileURL, completion)
        }

        method_setImplementation(method, imp_implementationWithBlock(block))
    }

    private static func restoreUploadTaskFactoryMethod(selector: Selector, original: inout IMP?) {
        guard let imp = original else { return }
        guard let method = class_getInstanceMethod(sessionClass, selector) else {
            original = nil
            return
        }

        method_setImplementation(method, imp)
        original = nil
    }

    private static func readPrefix(fromUploadFile fileURL: URL, maxBytes: Int) -> Data? {
        guard maxBytes > 0 else { return nil }
        guard let stream = InputStream(url: fileURL) else { return nil }
        return ApxyURLProtocol.readPrefix(from: stream, maxBytes: maxBytes)
    }
}
