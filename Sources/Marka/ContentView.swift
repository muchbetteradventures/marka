import SwiftUI

struct ContentView: View {
    let document: MarkdownDocument

    var body: some View {
        MarkdownNativeView(document: document)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
