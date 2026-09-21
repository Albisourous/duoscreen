import SwiftUI

struct ContentView: View {
    @StateObject private var paneA = WebStore(key: "duo.url.a")
    @StateObject private var paneB = WebStore(key: "duo.url.b")
    @AppStorage("duo.split") private var split = 0.5
    @State private var dragOrigin: CGFloat?
    @State private var snapA: UIImage?
    @State private var snapB: UIImage?

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            let axis = landscape ? geo.size.width : geo.size.height
            Group {
                if landscape {
                    HStack(spacing: 0) { first(geo); divider(axis, landscape: true); second(geo) }
                } else {
                    VStack(spacing: 0) { first(geo); divider(axis, landscape: false); second(geo) }
                }
            }
        }
        .background(.black)
        .persistentSystemOverlays(.hidden)
    }

    private func first(_ geo: GeometryProxy) -> some View {
        BrowserView(store: paneA)
            .overlay { snapA.map { Image(uiImage: $0).resizable().scaledToFill() } }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .frame(
                width: geo.size.width > geo.size.height ? geo.size.width * split : nil,
                height: geo.size.width > geo.size.height ? nil : geo.size.height * split
            )
            .padding(6)
    }

    private func second(_ geo: GeometryProxy) -> some View {
        BrowserView(store: paneB, toolbarAtTop: false)
            .overlay { snapB.map { Image(uiImage: $0).resizable().scaledToFill() } }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .frame(
                width: geo.size.width > geo.size.height ? geo.size.width * (1 - split) : nil,
                height: geo.size.width > geo.size.height ? nil : geo.size.height * (1 - split)
            )
            .padding(6)
    }

    private func divider(_ axis: CGFloat, landscape: Bool) -> some View {
        Rectangle()
            .fill(.white.opacity(0.15))
            .frame(width: landscape ? 1 : nil, height: landscape ? nil : 1)
            .overlay { handle }
            .zIndex(1)
            .contentShape(Rectangle().inset(by: -20))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        if dragOrigin == nil {
                            dragOrigin = split
                            // Freeze the live webviews into snapshots for the
                            // drag — reflowing two pages per frame is the jank.
                            paneA.webView.takeSnapshot(with: nil) { img, _ in snapA = img }
                            paneB.webView.takeSnapshot(with: nil) { img, _ in snapB = img }
                        }
                        let delta = (landscape ? v.translation.width : v.translation.height) / axis
                        split = min(0.85, max(0.15, (dragOrigin ?? split) + delta))
                    }
                    .onEnded { _ in
                        dragOrigin = nil
                        snapA = nil
                        snapB = nil
                    }
            )
    }

    private var handle: some View {
        HStack(spacing: 2) {
            Button {
                let a = paneA.urlText
                paneA.go(paneB.urlText)
                paneB.go(a)
            } label: {
                Image(systemName: "arrow.up.arrow.down").font(.system(size: 11))
            }
            Button { withAnimation(.spring()) { split = 0.5 } } label: {
                Capsule().fill(.white.opacity(0.7)).frame(width: 14, height: 2)
            }
        }
        .padding(8)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}
