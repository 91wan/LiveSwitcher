import Foundation
import SwiftUI
import WebKit

// MARK: - HTML WebView 桥接（供翻页拦截器注入 JS）

final class HTMLWebViewBridge {
    static let shared = HTMLWebViewBridge()
    private init() {}

    private let stateLock = NSLock()
    private var activeWebViewID: ObjectIdentifier?
    @MainActor private weak var currentWebView: WKWebView?

    var hasActiveWebView: Bool {
        stateLock.lock()
        let hasWebView = activeWebViewID != nil
        stateLock.unlock()
        return hasWebView
    }

    @MainActor
    func register(_ webView: WKWebView) {
        currentWebView = webView
        updateActiveWebViewID(ObjectIdentifier(webView))
    }

    @MainActor
    func clearIfCurrent(_ candidate: WKWebView) {
        if currentWebView === candidate {
            currentWebView = nil
            updateActiveWebViewID(nil)
        }
    }

    @MainActor
    func isCurrent(_ candidate: WKWebView) -> Bool {
        currentWebView === candidate
    }

    /// 注入翻页事件（ArrowRight=下一页，ArrowLeft=上一页）
    func dispatchArrowKey(isNext: Bool) {
        let key = isNext ? "ArrowRight" : "ArrowLeft"
        let js = """
        (function() {
            var e = new KeyboardEvent('keydown', {
                key: '\(key)',
                code: '\(isNext ? "ArrowRight" : "ArrowLeft")',
                keyCode: \(isNext ? 39 : 37),
                bubbles: true,
                cancelable: true
            });
            document.dispatchEvent(e);
            window.dispatchEvent(e);
        })();
        """
        Task { @MainActor [weak self] in
            guard let webView = self?.currentWebView else { return }
            _ = try? await webView.evaluateJavaScript(js)
        }
    }

    private func updateActiveWebViewID(_ id: ObjectIdentifier?) {
        stateLock.lock()
        activeWebViewID = id
        stateLock.unlock()
    }
}

// MARK: - HTML 大屏展示视图（WKWebView 封装，防御版）

/// 将本地 HTML 文件渲染到副屏，支持读取同目录资源（CSS/JS/图片）
/// 防御版：独立进程池 + Coordinator 强引用 + dismantleNSView 清场，防内存泄漏与双实例
struct OutputWebView: NSViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        #if DEBUG
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        #endif
        // 注：WKProcessPool 在 macOS 12+ 已废弃且无效，进程隔离由系统管理
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        context.coordinator.configure(for: url)
        HTMLWebViewBridge.shared.register(webView)   // 注册到 bridge，供翻页拦截器注入 JS
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        context.coordinator.configure(for: url)
        // 仅在 URL 真正变化时重载，防止 SwiftUI diff 触发无效重载
        guard WebNavigationPolicy.shouldReloadFileURL(current: nsView.url, target: url) else { return }
        nsView.stopLoading()
        nsView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        // SwiftUI 销毁 View 时强制清空 WebView，防离屏内存泄漏
        nsView.stopLoading()
        nsView.loadHTMLString("", baseURL: nil)
        coordinator.webView = nil
        HTMLWebViewBridge.shared.clearIfCurrent(nsView)
    }

    class Coordinator: NSObject {
        // 强引用持有，防止 ARC 在 SwiftUI diff 过程中提前释放
        var webView: WKWebView?
        private(set) var allowedRootDirectory: URL?

        func configure(for url: URL) {
            allowedRootDirectory = url.deletingLastPathComponent()
        }
    }
}

extension OutputWebView.Coordinator: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        WebNavigationPolicy.shouldAllowNavigation(
            url: navigationAction.request.url,
            allowedRoot: allowedRootDirectory
        ) ? .allow : .cancel
    }
}
