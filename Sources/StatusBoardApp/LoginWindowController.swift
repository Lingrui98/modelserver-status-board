import AppKit
import StatusBoardCore
import WebKit

@MainActor
final class LoginWindowController: NSObject {
    static let shared = LoginWindowController()

    private var window: NSWindow?
    private var webView: WKWebView?
    private weak var viewModel: DashboardViewModel?
    private var handledCallbackURLs = Set<String>()

    private override init() {
        super.init()
    }

    func show(viewModel: DashboardViewModel, authorizationURL: URL) {
        self.viewModel = viewModel
        handledCallbackURLs.removeAll()

        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            webView?.load(URLRequest(url: authorizationURL))
            return
        }

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 780),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        let webView = WKWebView(frame: window.contentView?.bounds ?? NSRect(x: 0, y: 0, width: 720, height: 780), configuration: configuration)
        webView.autoresizingMask = [.width, .height]
        webView.navigationDelegate = self

        window.center()
        window.title = "ModelServer 登录"
        window.contentView = webView
        window.delegate = self
        self.webView = webView
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        webView.load(URLRequest(url: authorizationURL))
    }

    func clearWebsiteSession() async {
        hide()
        webView?.stopLoading()
        handledCallbackURLs.removeAll()

        let store = WKWebsiteDataStore.default()
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        await withCheckedContinuation { continuation in
            store.fetchDataRecords(ofTypes: dataTypes) { records in
                let matching = records.filter { record in
                    let name = record.displayName.lowercased()
                    return name.contains("cs.ac.cn") || name.contains("code.cs") || name.contains("connect.cs")
                }

                guard !matching.isEmpty else {
                    continuation.resume()
                    return
                }

                store.removeData(ofTypes: dataTypes, for: matching) {
                    continuation.resume()
                }
            }
        }
    }

    private func scheduleCallbackHandling(_ url: URL) {
        guard url.host == "code.cs.ac.cn",
              url.path.contains("/auth/callback/") else {
            return
        }

        let rawURL = url.absoluteString
        guard handledCallbackURLs.insert(rawURL).inserted else {
            return
        }

        viewModel?.loginMessage = "已收到授权回调，正在登录..."

        Task { @MainActor [weak self, weak viewModel] in
            self?.hide()
            await viewModel?.completeLogin(with: rawURL)
        }
    }

    private func hide() {
        window?.orderOut(nil)
    }
}

extension LoginWindowController: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if let url = navigationAction.request.url,
           url.host == "code.cs.ac.cn",
           url.path.contains("/auth/callback/") {
            scheduleCallbackHandling(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        viewModel?.loginMessage = error.localizedDescription
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        viewModel?.loginMessage = error.localizedDescription
    }
}

extension LoginWindowController: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}
