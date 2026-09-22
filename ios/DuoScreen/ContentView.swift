import SwiftUI

struct ContentView: View {
    @StateObject private var paneA = WebStore(key: "duo.url.a")
    @StateObject private var paneB = WebStore(key: "duo.url.b")
    @AppStorage("duo.split.v2") private var split = 0.5
    @Environment(\.verticalSizeClass) private var vSize
    @State private var locked = false
    @State private var dragSplit: CGFloat?
    @State private var snapA: UIImage?
    @State private var snapB: UIImage?

    var body: some View {
        // geo.size has been observed stuck at its portrait value after rotation,
        // leaving the stacked layout inside a landscape window: pane A fills the
        // screen and the seam + pane B sit off-screen. Scene bounds are the
        // authoritative rotated size; verticalSizeClass triggers the re-render.
        let size = sceneBounds
        let l = vSize == .compact
        let axis = max(1, (l ? size.width : size.height) - 3) // minus the seam
        let lo = min(120 / axis, 0.4) // a pane never shrinks below ~120pt
        let raw = dragSplit ?? split
        let s = raw.isFinite ? min(1 - lo, max(lo, raw)) : 0.5
        // Explicit rects, not stack sizing — a flexible WKWebView inside an
        // HStack can negotiate itself to full width and push its sibling off-screen.
        ZStack(alignment: .topLeading) {
            pane(paneA, snap: snapA,
                 railEdge: l ? .leading : .trailing, clearsSeam: !l,
                 w: l ? axis * s : nil, h: l ? nil : axis * s)
            pane(paneB, snap: snapB, railEdge: .trailing,
                 w: l ? axis * (1 - s) : nil, h: l ? nil : axis * (1 - s))
                .offset(x: l ? axis * s + 3 : 0, y: l ? 0 : axis * s + 3)
            // Last = topmost: the seam's ±20pt grab area must sit over both panes
            divider(axis, l)
                .offset(x: l ? axis * s : 0, y: l ? 0 : axis * s)
        }
        // Offsets don't expand a ZStack's bounds — without this the stack
        // shrinks to pane A and centers, leaving black gaps and clipping pane B.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.black)
        .ignoresSafeArea(.container) // edge-to-edge, but still avoids the keyboard
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }

    /// Window-scene bounds — the authoritative rotated size. GeometryReader's
    /// geo.size has been observed stuck at portrait inside a landscape window.
    private var sceneBounds: CGRect {
        (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.first)?.screen.bounds ?? .zero
    }

    /// Real device insets (Dynamic Island, home indicator). geo.safeAreaInsets
    /// reports zero because the container ignores the safe area — read the
    /// window's instead.
    private var realInsets: EdgeInsets {
        let i = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?.safeAreaInsets ?? .zero
        return EdgeInsets(top: i.top, leading: i.left, bottom: i.bottom, trailing: i.right)
    }

    private func pane(_ store: WebStore, snap: UIImage?, railEdge: HorizontalEdge,
                      clearsSeam: Bool = false, w: CGFloat? = nil, h: CGFloat? = nil) -> some View {
        BrowserView(store: store, railEdge: railEdge, clearsSeam: clearsSeam, insets: realInsets)
            .overlay { snap.map { Image(uiImage: $0).resizable().scaledToFill() } }
            .frame(width: w, height: h)
    }

    private func divider(_ axis: CGFloat, _ l: Bool) -> some View {
        let lo = min(120 / axis, 0.4)
        // split can hold a poisoned value (NaN/inf): the display path masks it,
        // but `split + d` would be NaN and every drag update would no-op.
        // Base drags on a finite value instead — one drag heals the store.
        let base = split.isFinite ? split : 0.5
        return Rectangle()
            .fill(.black)
            .frame(width: l ? 3 : nil, height: l ? nil : 3)
            .overlay {
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(7)
                        .glassEffect(.regular, in: .circle)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3), value: locked)
            .contentShape(Rectangle().inset(by: -20))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        guard !locked else { return }
                        if dragSplit == nil {
                            // Freeze the live webviews into snapshots for the
                            // drag — reflowing two pages per frame is the jank.
                            paneA.webView.takeSnapshot(with: nil) { img, _ in
                                if dragSplit != nil { snapA = img }
                            }
                            paneB.webView.takeSnapshot(with: nil) { img, _ in
                                if dragSplit != nil { snapB = img }
                            }
                        }
                        let d = (l ? v.translation.width : v.translation.height) / axis
                        dragSplit = min(1 - lo, max(lo, base + d))
                    }
                    .onEnded { v in
                        guard !locked else { return }
                        let d = (l ? v.translation.width : v.translation.height) / axis
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            split = min(1 - lo, max(lo, base + d))
                        }
                        dragSplit = nil
                        snapA = nil
                        snapB = nil
                    }
            )
            .simultaneousGesture(
                TapGesture(count: 2).onEnded {
                    locked.toggle()
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                }
            )
    }
}
