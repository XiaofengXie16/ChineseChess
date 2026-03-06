import SwiftUI

@main
struct ChineseChessApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .frame(minWidth: 680, minHeight: 540)
        }
        .defaultSize(width: 860, height: 680)
    }
}
