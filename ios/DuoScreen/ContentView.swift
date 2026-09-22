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
            let w = geo.size.width - 3 // minus the seam
            let s = dragSplit ?? split
            HStack(spacing: 0) {
                BrowserView(store: paneA, railEdge: .leading, insets: realInsets)
                    .overlay { snapA.map { Image(uiImage: $0).resizable().scaledToFill() } }
                    .frame(width: w * s)
                divider(axis: w)
                BrowserView(store: paneB, railEdge: .trailing, insets: realInsets)
                    .overlay { snapB.map { Image(uiImage: $0).resizable().scaledToFill() } }
                    .frame(width: w * (1 - s))
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

    private func divider(axis: CGFloat) -> some View {
        Rectangle()
            .fill(.black)
            .frame(width: 3)
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
                        dragSplit = min(0.85, max(0.15, split + v.translation.width / axis))
                    }
                    .onEnded { v in
                        guard !locked else { return }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            split = min(0.85, max(0.15, split + v.translation.width / axis))
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
