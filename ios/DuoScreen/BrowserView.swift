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
                ? "https://www.google.com/search?q=\(v.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? v)"
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

    func webView(_ wv: WKWebView, didFinish _: WKNavigation!) {
        failed = false
        if let u = wv.url { urlText = u.absoluteString }
    }
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

/// Safari-style chrome: one bottom bar — back, domain pill (expands into the
/// address field on tap), reload. Hides on scroll down, reveals on scroll up.
struct BrowserView: View {
    @StateObject var store: WebStore
    var clearsSeam = false
    var insets = EdgeInsets()
    @State private var editing = false
    @FocusState private var fieldFocused: Bool

    var body: some View {
        WebView(store: store)
            .overlay(alignment: .bottom) {
                addressBar
                    .padding(.horizontal, 10)
                    .frame(maxWidth: 420)
                    .padding(.bottom, insets.bottom + (clearsSeam ? 36 : 12))
                    .opacity(store.toolbarHidden && !editing ? 0 : 1)
                    .allowsHitTesting(!store.toolbarHidden || editing)
                    .animation(.easeOut(duration: 0.2), value: store.toolbarHidden)
            }
            .overlay(alignment: .top) {
                if store.failed {
                    Text("Couldn't reach that site")
                        .font(.caption)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .glassEffect()
                        .padding(.top, insets.top + 8)
                }
            }
            .background(.black)
    }

    private func barButton(_ icon: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .foregroundStyle(enabled ? .primary : .tertiary)
    }

    private var addressBar: some View {
        HStack(spacing: 0) {
            if editing {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .padding(.leading, 12)
                TextField("Search or enter address", text: $store.urlText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .submitLabel(.go)
                    .focused($fieldFocused)
                    .onSubmit { store.go(store.urlText); editing = false }
                    .onAppear { fieldFocused = true }
                Button {
                    if store.urlText.isEmpty { editing = false } else { store.urlText = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                // canGoBack isn't observable, but didFinish republishing urlText
                // refreshes this view after every navigation — close enough.
                barButton("chevron.left", enabled: store.webView.canGoBack) { store.webView.goBack() }
                Button { editing = true } label: {
                    Label(host.isEmpty ? "Search or enter address" : host, systemImage: "magnifyingglass")
                        .font(.callout)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                barButton("arrow.clockwise") { store.webView.reload() }
            }
        }
        .frame(height: 44)
        .padding(4)
        .glassEffect(in: .capsule)
    }

    private var host: String { store.webView.url?.host() ?? "" }
}
