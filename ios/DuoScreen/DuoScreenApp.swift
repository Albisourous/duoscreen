import AVFAudio
import SwiftUI

/// Runtime orientation mask: set while the seam is locked to pin the app to
/// its current orientation family. nil = portrait + both landscapes.
final class AppDelegate: NSObject, UIApplicationDelegate {
    static var mask: UIInterfaceOrientationMask?

    func application(_: UIApplication, supportedInterfaceOrientationsFor _: UIWindow?)
        -> UIInterfaceOrientationMask {
        Self.mask ?? .allButUpsideDown
    }
}

@main
struct DuoScreenApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        // Let both panes play audio at once — the default session makes a new
        // playback interrupt the other pane's video.
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
    }

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
