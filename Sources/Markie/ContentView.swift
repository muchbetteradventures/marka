import SwiftUI

struct ContentView: View {
    let document: MarkdownDocument

    var body: some View {
        MarkdownWebView(document: document)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
