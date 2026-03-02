import SwiftUI
import Textual
import MarkdownView

struct TextualContentView: View {
    let document: MarkdownDocument

    var body: some View {
        ScrollView {
            StructuredText(markdown: document.markdown)
                .textual.structuredTextStyle(.gitHub)
                .textual.textSelection(.enabled)
                .padding(32)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MarkdownViewContentView: View {
    let document: MarkdownDocument

    var body: some View {
        ScrollView {
            MarkdownView(document.markdown)
                .padding(32)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
