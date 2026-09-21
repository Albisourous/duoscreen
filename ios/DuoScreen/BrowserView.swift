import SwiftUI
import WebKit

/// One browser pane: a WKWebView (any site loads — top-level loads ignore
/// X-Frame-Options, unlike iframes) plus a floating liquid-glass toolbar.
final class WebStore: NSObject, ObservableObject, WKNavigationDelegate {
    let webView = WKWebView()
    let key: String
    @Published var urlText = ""
    @Published var failed = false

    static let startPage = """
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <body style="margin:0;min-height:100vh;display:grid;place-items:center;
    background:radial-gradient(120% 100% at 20% 0%,#1b1e3a,#0a0a0f 55%);
    font-family:-apple-system;color:#fff">
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:10px;width:80%;max-width:280px">
    <style>a{display:block;padding:12px;border-radius:14px;text-align:center;
    color:#eee;text-decoration:none;font-size:14px;
    background:rgba(255,255,255,.08);border:1px solid rgba(255,255,255,.15)}</style>
    <a href="https://google.com">Google</a>
    <a href="https://en.m.wikipedia.org">Wikipedia</a>
    <a href="https://news.ycombinator.com">Hacker News</a>
    <a href="https://www.bing.com">Bing</a>
    <a href="https://www.youtube.com">YouTube</a>
    <a href="https://wttr.in">Weather</a>
    </div>
    <p style="position:fixed;bottom:20px;width:100%;text-align:center;
    font-size:12px;color:rgba(255,255,255,.4)">Type an address or tap a site</p>
    </body>
    """

    init(key: String) {
        self.key = key
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
}

struct WebView: UIViewRepresentable {
    let store: WebStore
    func makeUIView(context _: Context) -> WKWebView { store.webView }
    func updateUIView(_: WKWebView, context _: Context) {}
}

struct BrowserView: View {
    @StateObject var store: WebStore
    var toolbarAtTop = true

    var body: some View {
        ZStack(alignment: toolbarAtTop ? .top : .bottom) {
            WebView(store: store)
            toolbar
                .padding(.horizontal, 12)
                .padding(toolbarAtTop ? .top : .bottom, 10)
            if store.failed {
                Text("Couldn't reach that site")
                    .font(.caption)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .glassEffect()
                    .padding(toolbarAtTop ? .top : .bottom, 60)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .background(.black)
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
                .frame(height: 34)
                .background(.black.opacity(0.3), in: .capsule)
            Button { store.home() } label: { Image(systemName: "house") }
            Button {
                if let u = store.webView.url { UIApplication.shared.open(u) }
            } label: { Image(systemName: "safari") }
        }
        .buttonStyle(.glass)
        .padding(6)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}
