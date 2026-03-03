import SwiftUI
import MarkdownView

struct ContentView: View {
    let document: MarkdownDocument

    var body: some View {
        ScrollView {
            MarkdownView(document.markdown)
                .textSelection(.enabled)
                .padding(32)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
