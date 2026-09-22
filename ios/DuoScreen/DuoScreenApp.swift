import AVFAudio
import SwiftUI

@main
struct DuoScreenApp: App {
    init() {
        // Let both panes play audio at once — the default session makes a new
        // playback interrupt the other pane's video.
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
    }

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
