import SwiftUI

struct ContentView: View {
    @StateObject private var paneA = WebStore(name: "A")
    @StateObject private var paneB = WebStore(name: "B")
    @AppStorage("duo.split.v2") private var split = 0.5
    @Environment(\.verticalSizeClass) private var vSize
    @State private var locked = false
    @State private var swapped = false
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
        // During a drag the webviews keep their pre-drag size and a GPU
        // scaleEffect squish tracks the finger — resizing a WKWebView reflows
        // the whole page (the jank), a layer transform is free. Same trick
        // WebKit uses internally for live resize. The real frame commits once
        // on release.
        let ps = dragSplit == nil ? s : (split.isFinite ? min(1 - lo, max(lo, split)) : 0.5)
        // `swapped` trades the panes' slots: the views move, so each WKWebView
        // keeps its own page. disp/froz are pane A's display/frozen fractions.
        let dispA = swapped ? 1 - s : s
        let frozA = swapped ? 1 - ps : ps
        let kA = dispA / max(frozA, 0.01)
        let kB = (1 - dispA) / max(1 - frozA, 0.01)
        // Explicit rects, not stack sizing — a flexible WKWebView inside an
        // HStack can negotiate itself to full width and push its sibling off-screen.
        ZStack(alignment: .topLeading) {
            pane(paneA, clearsSeam: !l && !swapped, resizing: dragSplit != nil,
                 w: l ? axis * frozA : nil, h: l ? nil : axis * frozA)
                .scaleEffect(x: l ? kA : 1, y: l ? 1 : kA, anchor: .topLeading)
                .offset(x: l && swapped ? axis * s + 3 : 0,
                        y: !l && swapped ? axis * s + 3 : 0)
            pane(paneB, clearsSeam: !l && swapped, resizing: dragSplit != nil,
                 w: l ? axis * (1 - frozA) : nil, h: l ? nil : axis * (1 - frozA))
                .scaleEffect(x: l ? kB : 1, y: l ? 1 : kB, anchor: .topLeading)
                .offset(x: l && !swapped ? axis * s + 3 : 0,
                        y: !l && !swapped ? axis * s + 3 : 0)
            // Snapshot cover: WKWebView blanks to white between a resize and
            // the web content re-committing — hold the last frames over the
            // gap. Gated off while dragging: stale covers would freeze over
            // the live squish if a new drag starts inside the cover window.
            if let snapA, dragSplit == nil {
                Image(uiImage: snapA).resizable()
                    .frame(width: l ? axis * dispA : nil, height: l ? nil : axis * dispA)
                    .offset(x: l && swapped ? axis * s + 3 : 0,
                            y: !l && swapped ? axis * s + 3 : 0)
                    .allowsHitTesting(false)
            }
            if let snapB, dragSplit == nil {
                Image(uiImage: snapB).resizable()
                    .frame(width: l ? axis * (1 - dispA) : nil, height: l ? nil : axis * (1 - dispA))
                    .offset(x: l && !swapped ? axis * s + 3 : 0,
                            y: !l && !swapped ? axis * s + 3 : 0)
                    .allowsHitTesting(false)
            }
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

    private func pane(_ store: WebStore, clearsSeam: Bool = false, resizing: Bool = false,
                      w: CGFloat? = nil, h: CGFloat? = nil) -> some View {
        BrowserView(store: store, clearsSeam: clearsSeam, resizing: resizing, insets: realInsets)
            .frame(width: w, height: h)
    }

    private var lockBadge: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white.opacity(0.7))
            .frame(width: 26, height: 26)
            .glassEffect(.regular, in: .circle)
    }

    /// Cover a pane-moving change with the last rendered frames: a resized or
    /// relocated WKWebView blanks to white until its content re-commits.
    private func withSnapshotCover(_ change: @escaping () -> Void) {
        paneA.webView.takeSnapshot(with: nil) { a, _ in
            paneB.webView.takeSnapshot(with: nil) { b, _ in
                snapA = a
                snapB = b
                change()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    snapA = nil
                    snapB = nil
                }
            }
        }
    }

    private var swapButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withSnapshotCover { swapped.toggle() }
        } label: {
            Image(systemName: "arrow.2.squarepath")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 26, height: 26)
                .glassEffect(.regular, in: .circle)
        }
        .buttonStyle(.plain)
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
                    Group {
                        if l {
                            VStack(spacing: 6) { lockBadge; swapButton }
                        } else {
                            HStack(spacing: 6) { lockBadge; swapButton }
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3), value: locked)
            .contentShape(Rectangle().inset(by: -20))
            .gesture(
                // .global: in local space the seam's own movement shifts the
                // coordinate space mid-drag, feeding back into translation —
                // that's the residual jitter.
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { v in
                        guard !locked else { return }
                        let d = (l ? v.translation.width : v.translation.height) / axis
                        dragSplit = min(1 - lo, max(lo, base + d))
                    }
                    .onEnded { v in
                        guard !locked else { return }
                        let d = (l ? v.translation.width : v.translation.height) / axis
                        // No settle animation: animating the frame would reflow
                        // both pages for the whole spring. Commit where the
                        // finger already is, behind a cover so the reflow's
                        // white gap never shows.
                        withSnapshotCover {
                            split = min(1 - lo, max(lo, base + d))
                            dragSplit = nil
                        }
                    }
            )
            .simultaneousGesture(
                TapGesture(count: 2).onEnded {
                    locked.toggle()
                    // Locking pins the app to the orientation it's in; on
                    // unlock, re-evaluate so a device already rotated snaps
                    // back without needing another tilt.
                    AppDelegate.mask = locked ? (l ? .landscape : .portrait) : nil
                    (UIApplication.shared.connectedScenes
                        .compactMap { $0 as? UIWindowScene }.first)?
                        .keyWindow?.rootViewController?
                        .setNeedsUpdateOfSupportedInterfaceOrientations()
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                }
            )
    }
}
