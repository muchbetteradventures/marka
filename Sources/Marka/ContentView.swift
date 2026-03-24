import SwiftUI

struct ContentView: View {
    let document: MarkdownDocument

    var body: some View {
        // Accessing document.markdown registers this view as a SwiftUI @Observable
        // observer so updateNSView is called when the file changes on disk.
        let _ = document.markdown
        MarkdownNativeView(document: document)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
