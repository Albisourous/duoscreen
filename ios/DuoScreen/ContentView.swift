import SwiftUI
import UIKit

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
        .onAppear { UIDevice.current.isBatteryMonitoringEnabled = true }
    }

    private func first(_ geo: GeometryProxy) -> some View {
        let s = dragSplit ?? split
        return BrowserView(store: paneA)
            .overlay { snapA.map { Image(uiImage: $0).resizable().scaledToFill() } }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .frame(
                width: geo.size.width > geo.size.height ? geo.size.width * s : nil,
                height: geo.size.width > geo.size.height ? nil : geo.size.height * s
            )
            .padding(6)
    }

    private func second(_ geo: GeometryProxy) -> some View {
        let s = dragSplit ?? split
        return BrowserView(store: paneB, toolbarAtTop: false)
            .overlay { snapB.map { Image(uiImage: $0).resizable().scaledToFill() } }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .frame(
                width: geo.size.width > geo.size.height ? geo.size.width * (1 - s) : nil,
                height: geo.size.width > geo.size.height ? nil : geo.size.height * (1 - s)
            )
            .padding(6)
    }

    private func divider(_ axis: CGFloat, landscape: Bool) -> some View {
        Rectangle()
            .fill(.white.opacity(0.15))
            .frame(width: landscape ? 1 : nil, height: landscape ? nil : 1)
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
                        let delta = (landscape ? v.translation.width : v.translation.height) / axis
                        dragSplit = min(0.85, max(0.15, split + delta))
                    }
                    .onEnded { v in
                        guard !locked else { return }
                        let delta = (landscape ? v.translation.width : v.translation.height) / axis
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            split = min(0.85, max(0.15, split + delta))
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
