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

/// Duo-style chrome: a status column and button clusters ride the pane's
/// outer edge rail; a small domain pill sits at the bottom and expands into
/// the address field on tap.
struct BrowserView: View {
    @StateObject var store: WebStore
    var railEdge: HorizontalEdge = .trailing
    var clearsSeam = false
    var insets = EdgeInsets()
    @State private var editing = false
    @FocusState private var fieldFocused: Bool

    private var railPad: CGFloat { 10 + (railEdge == .leading ? insets.leading : insets.trailing) }

    var body: some View {
        WebView(store: store)
            .overlay(alignment: railEdge == .leading ? .topLeading : .topTrailing) {
                status
                    .padding(.top, insets.top + 12)
                    .padding(railEdge == .leading ? .leading : .trailing, railPad)
            }
            .overlay(alignment: railEdge == .leading ? .leading : .trailing) {
                controls
                    .padding(railEdge == .leading ? .leading : .trailing, railPad)
                    .opacity(store.toolbarHidden ? 0 : 1)
                    .allowsHitTesting(!store.toolbarHidden)
                    .animation(.easeOut(duration: 0.2), value: store.toolbarHidden)
            }
            .overlay(alignment: .bottom) {
                addressPill
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

    /// Each screen carries its own status — camera dot, time, wifi, battery —
    /// in a glass capsule so it stays legible over any page.
    private var status: some View {
        TimelineView(.periodic(from: .now, by: 60)) { _ in
            VStack(spacing: 5) {
                Circle().fill(.black).frame(width: 14, height: 14)
                Text(Date.now, format: .dateTime.hour().minute())
                Image(systemName: "wifi")
                Image(systemName: batterySymbol)
            }
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 10)
            .glassEffect(in: .capsule)
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

    private var controls: some View {
        VStack {
            Spacer()
            VStack(spacing: 2) {
                railIcon("chevron.left") { store.webView.goBack() }
                railIcon("arrow.clockwise") { store.webView.reload() }
            }
            .padding(4)
            .glassEffect(in: .capsule)
            Spacer()
            VStack(spacing: 2) {
                railIcon("house") { store.home() }
                railIcon("safari") {
                    if let u = store.webView.url { UIApplication.shared.open(u) }
                }
            }
            .padding(4)
            .glassEffect(in: .capsule)
            Spacer().frame(height: insets.bottom + 48)
        }
    }

    private func railIcon(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .frame(width: 44, height: 44) // HIG minimum touch target
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private var addressPill: some View {
        Group {
            if editing {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search or enter address", text: $store.urlText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .submitLabel(.go)
                        .focused($fieldFocused)
                        .onSubmit { store.go(store.urlText); editing = false }
                    Button { editing = false } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: 330)
                .glassEffect(in: .capsule)
                .onAppear { fieldFocused = true }
            } else {
                Button { editing = true } label: {
                    Label(host.isEmpty ? "Search or enter address" : host, systemImage: "magnifyingglass")
                        .font(.callout)
                        .lineLimit(1)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .glassEffect(in: .capsule)
            }
        }
    }

    private var host: String { store.webView.url?.host() ?? "" }
}
