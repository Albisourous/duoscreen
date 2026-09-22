import SwiftUI
import WebKit

/// One browser pane: a WKWebView (any site loads — top-level loads ignore
/// X-Frame-Options, unlike iframes) plus a floating liquid-glass toolbar.
final class WebStore: NSObject, ObservableObject, WKNavigationDelegate {
    let webView: WKWebView
    let name: String
    @Published var urlText = ""
    @Published var failed = false
    @Published var toolbarHidden = false
    @Published var atStart = true

    static func startPage(name: String) -> String {
        let (demo, label): (String, String) = name == "A"
            ? ("https://www.apple.com/iphone/", "Apple")
            : ("https://m.youtube.com", "YouTube")
        let hints = name == "A"
            ? "Drag the seam to resize.<br>Double-tap to lock it, then tap the swap icon."
            : ""
        return """
        <!DOCTYPE html><meta name="viewport" content="width=device-width,initial-scale=1">
        <body data-duo="1" style="margin:0;min-height:100vh;display:grid;place-items:center;
        padding-bottom:110px;box-sizing:border-box;
        background:radial-gradient(120% 100% at 20% 0%,#1b1e3a,#0a0a0f 55%);
        font-family:-apple-system;color:#fff;text-align:center">
        <div style="padding:0 24px">
        <div style="font-size:22px;font-weight:600;letter-spacing:-0.5px">DuoScreen</div>
        <div style="margin-top:6px;font-size:12px;font-weight:700;letter-spacing:3px;color:rgba(255,255,255,.35)">WINDOW \(name)</div>
        <a href="\(demo)" style="display:inline-block;margin-top:14px;padding:11px 20px;
        border-radius:999px;background:rgba(255,255,255,.1);color:#fff;
        text-decoration:none;font-size:15px;font-weight:500">Try it: open \(label)</a>
        <div style="margin-top:14px;font-size:13px;color:rgba(255,255,255,.4);line-height:1.7;min-height:44px">\(hints)</div>
        </div>
        </body>
        """
    }

    init(name: String) {
        self.name = name
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true // videos play in-page, not fullscreen
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        home()
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
        webView.load(URLRequest(url: url))
    }

    func home() {
        urlText = ""
        atStart = true
        webView.loadHTMLString(Self.startPage(name: name), baseURL: nil)
    }

    func webView(_ wv: WKWebView, didFinish _: WKNavigation!) {
        failed = false
        guard let u = wv.url, u.scheme != "about" else {
            // Going back can land on the raw about:blank slot with an empty
            // document — re-render the start page unless ours survived.
            wv.evaluateJavaScript("document.body?.dataset.duo ? 1 : 0") { r, _ in
                if (r as? Int) == 1 { self.atStart = true } else { self.home() }
            }
            return
        }
        urlText = u.absoluteString
        atStart = false
    }
    func webView(_ wv: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError _: Error) { failed = true }

    func webView(
        _ wv: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url,
              url.scheme == "http" || url.scheme == "https" || url.scheme == "about"
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
        // Our own recognizer on the webview itself: the scrollview's pan gets
        // cancelled by pages that take over touches (touch-action, JS swipe
        // handlers — YouTube Shorts), so it can't be trusted to fire.
        let pan = UIPanGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.didPan(_:)))
        pan.delegate = context.coordinator
        store.webView.addGestureRecognizer(pan)
        return store.webView
    }

    func updateUIView(_: WKWebView, context _: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(store: store) }

    /// Safari-style bar behavior: hide on scroll down, reveal on scroll up / at top.
    final class Coordinator: NSObject, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        let store: WebStore
        private var lastY: CGFloat = 0

        init(store: WebStore) { self.store = store }

        /// Observe alongside every other recognizer — never steal touches.
        func gestureRecognizer(_: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer) -> Bool { true }

        @objc func didPan(_ g: UIPanGestureRecognizer) {
            guard g.state == .changed else { return }
            let v = g.velocity(in: g.view)
            guard abs(v.y) > abs(v.x) else { return } // vertical swipes only, not edge-back
            if v.y < -200 { store.toolbarHidden = true }   // swiping up = content moves down
            else if v.y > 200 { store.toolbarHidden = false }
        }

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
    var resizing = false
    var insets = EdgeInsets()
    @State private var editing = false
    @FocusState private var fieldFocused: Bool

    var body: some View {
        WebView(store: store)
            .overlay(alignment: .bottom) {
                // Hidden while the seam drags (the pane is scaleEffect-squished,
                // so live chrome would deform) or on Safari-style scroll-away.
                let chromeHidden = resizing || (store.toolbarHidden && !editing)
                addressBar
                    .padding(.horizontal, 10)
                    .frame(maxWidth: 420)
                    .padding(.bottom, insets.bottom + (clearsSeam ? 36 : 12))
                    .opacity(chromeHidden ? 0 : 1)
                    .allowsHitTesting(!chromeHidden)
                    .animation(.easeOut(duration: 0.2), value: chromeHidden)
                    .onChange(of: resizing) { editing = false }
            }
            .overlay(alignment: .top) {
                if store.failed && !resizing {
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
                // No history (e.g. start page slot was replaced) → go home.
                barButton("chevron.left", enabled: store.webView.canGoBack || !store.atStart) {
                    if store.webView.canGoBack { store.webView.goBack() } else { store.home() }
                }
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
