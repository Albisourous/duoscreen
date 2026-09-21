import SwiftUI
import WebKit

/// One browser pane: a WKWebView (any site loads — top-level loads ignore
/// X-Frame-Options, unlike iframes) plus a floating liquid-glass toolbar.
final class WebStore: NSObject, ObservableObject, WKNavigationDelegate {
    let webView: WKWebView
    let key: String
    @Published var urlText = ""
    @Published var failed = false
    @Published var toolbarHidden = false

    static let startPage = """
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <body style="margin:0;min-height:100vh;display:grid;place-items:center;
    background:radial-gradient(120% 100% at 20% 0%,#1b1e3a,#0a0a0f 55%);
    font-family:-apple-system;color:#fff;text-align:center">
    <div>
    <div style="font-size:22px;font-weight:600;letter-spacing:-0.5px">DuoScreen</div>
    <div style="margin-top:6px;font-size:13px;color:rgba(255,255,255,.4)">Type an address to begin</div>
    </div>
    </body>
    """

    init(key: String) {
        self.key = key
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true // videos play in-page, not fullscreen
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        if let saved = UserDefaults.standard.string(forKey: key), !saved.isEmpty {
            urlText = saved
            webView.load(URLRequest(url: URL(string: saved)!))
        } else {
            home()
        }
    }

    func go(_ raw: String) {
        var v = raw.trimmingCharacters(in: .whitespaces)
        if v.isEmpty { home(); return }
        if !v.contains("://") {
            v = v.contains(" ") || !v.contains(".")
                ? "https://www.bing.com/search?q=\(v.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? v)"
                : "https://\(v)"
        }
        guard let url = URL(string: v) else { return }
        urlText = v
        UserDefaults.standard.set(v, forKey: key)
        webView.load(URLRequest(url: url))
    }

    func home() {
        urlText = ""
        UserDefaults.standard.removeObject(forKey: key)
        webView.loadHTMLString(Self.startPage, baseURL: nil)
    }

    func webView(_ wv: WKWebView, didFinish _: WKNavigation!) { failed = false }
    func webView(_ wv: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError _: Error) { failed = true }

    func webView(
        _ wv: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url,
              url.scheme == "http" || url.scheme == "https"
        else {
            decisionHandler(.cancel) // youtube://, itms://, tel:, mailto: — stay in-app
            return
        }
        // Universal links only jump to native apps on link-activated
        // navigations; reloading as a plain load keeps it in this pane.
        if navigationAction.navigationType == .linkActivated {
            decisionHandler(.cancel)
            wv.load(navigationAction.request)
            return
        }
        decisionHandler(.allow)
    }
}

struct WebView: UIViewRepresentable {
    let store: WebStore

    func makeUIView(context: Context) -> WKWebView {
        store.webView.scrollView.delegate = context.coordinator
        return store.webView
    }

    func updateUIView(_: WKWebView, context _: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(store: store) }

    /// Safari-style bar behavior: hide on scroll down, reveal on scroll up / at top.
    final class Coordinator: NSObject, UIScrollViewDelegate {
        let store: WebStore
        private var lastY: CGFloat = 0

        init(store: WebStore) { self.store = store }

        func scrollViewDidScroll(_ sv: UIScrollView) {
            let y = sv.contentOffset.y
            let dy = y - lastY
            lastY = y
            if y <= 0 || dy < -6 {
                store.toolbarHidden = false
            } else if dy > 6, y > 80 {
                store.toolbarHidden = true
            }
        }
    }
}

struct BrowserView: View {
    @StateObject var store: WebStore
    var toolbarAtTop = true
    var insets = EdgeInsets()

    var body: some View {
        WebView(store: store)
            .overlay(alignment: .topTrailing) {
                statusBar
                    .padding(.top, insets.top + 6)
                    .padding(.trailing, 18 + insets.trailing)
            }
            .overlay(alignment: toolbarAtTop ? .top : .bottom) {
                toolbar
                    .opacity(store.toolbarHidden ? 0 : 1)
                    .allowsHitTesting(!store.toolbarHidden)
                    .animation(.easeOut(duration: 0.2), value: store.toolbarHidden)
                    .padding(.horizontal, 12 + max(insets.leading, insets.trailing))
                    .padding(toolbarAtTop ? .top : .bottom, (toolbarAtTop ? insets.top : insets.bottom) + 8)
            }
            .overlay(alignment: toolbarAtTop ? .top : .bottom) {
                if store.failed {
                    Text("Couldn't reach that site")
                        .font(.caption)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .glassEffect()
                        .padding(toolbarAtTop ? .top : .bottom, 60)
                }
            }
            .background(.black)
    }

    /// Duo detail: each screen carries its own status bar. Drawn under the
    /// toolbar — it surfaces when the bar auto-hides on scroll.
    private var statusBar: some View {
        TimelineView(.periodic(from: .now, by: 60)) { _ in
            HStack(spacing: 4) {
                Text(Date.now, format: .dateTime.hour().minute())
                Image(systemName: "wifi")
                Image(systemName: batterySymbol)
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.white.opacity(0.75))
        }
    }

    private var batterySymbol: String {
        switch UIDevice.current.batteryLevel {
        case ..<0: "battery.100"
        case ..<0.25: "battery.25"
        case ..<0.5: "battery.50"
        case ..<0.75: "battery.75"
        default: "battery.100"
        }
    }

    private var toolbar: some View {
        HStack(spacing: 4) {
            Button { store.webView.goBack() } label: { Image(systemName: "chevron.left") }
            Button { store.webView.reload() } label: { Image(systemName: "arrow.clockwise") }
            TextField("Search or enter address", text: $store.urlText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .submitLabel(.go)
                .onSubmit { store.go(store.urlText) }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(.black.opacity(0.3), in: .capsule)
            Button { store.home() } label: { Image(systemName: "house") }
            Button {
                if let u = store.webView.url { UIApplication.shared.open(u) }
            } label: { Image(systemName: "safari") }
        }
        .buttonStyle(.glass)
        .frame(maxWidth: .infinity)
        .padding(6)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}
