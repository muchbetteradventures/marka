import SwiftUI

struct ContentView: View {
    let document: MarkdownDocument

    var body: some View {
        let _ = document.markdown
        return MarkdownNativeView(document: document)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
