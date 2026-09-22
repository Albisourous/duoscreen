import SwiftUI

struct ContentView: View {
    @StateObject private var paneA = WebStore(key: "duo.url.a")
    @StateObject private var paneB = WebStore(key: "duo.url.b")
    @AppStorage("duo.split") private var split = 0.5
    @State private var locked = false
    @State private var dragSplit: CGFloat?
    @State private var snapA: UIImage?
    @State private var snapB: UIImage?

    var body: some View {
        GeometryReader { geo in
            let l = geo.size.width > geo.size.height
            let axis = (l ? geo.size.width : geo.size.height) - 3 // minus the seam
            Group {
                if l {
                    HStack(spacing: 0) { first(geo); divider(axis, l); second(geo) }
                } else {
                    VStack(spacing: 0) { first(geo); divider(axis, l); second(geo) }
                }
            }
        }
        .background(.black)
        .ignoresSafeArea(.container) // edge-to-edge, but still avoids the keyboard
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
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

    private func first(_ geo: GeometryProxy) -> some View {
        let l = geo.size.width > geo.size.height
        let s = dragSplit ?? split
        let axis = (l ? geo.size.width : geo.size.height) - 3
        return BrowserView(
            store: paneA,
            railEdge: l ? .leading : .trailing,
            clearsSeam: !l,
            insets: realInsets
        )
        .overlay { snapA.map { Image(uiImage: $0).resizable().scaledToFill() } }
        .frame(width: l ? axis * s : nil, height: l ? nil : axis * s)
    }

    private func second(_ geo: GeometryProxy) -> some View {
        let l = geo.size.width > geo.size.height
        let s = dragSplit ?? split
        let axis = (l ? geo.size.width : geo.size.height) - 3
        return BrowserView(store: paneB, railEdge: .trailing, insets: realInsets)
            .overlay { snapB.map { Image(uiImage: $0).resizable().scaledToFill() } }
            .frame(width: l ? axis * (1 - s) : nil, height: l ? nil : axis * (1 - s))
    }

    private func divider(_ axis: CGFloat, _ l: Bool) -> some View {
        let lo = min(120 / axis, 0.4) // a pane never shrinks below ~120pt
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
                        dragSplit = min(1 - lo, max(lo, split + d))
                    }
                    .onEnded { v in
                        guard !locked else { return }
                        let d = (l ? v.translation.width : v.translation.height) / axis
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            split = min(1 - lo, max(lo, split + d))
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
