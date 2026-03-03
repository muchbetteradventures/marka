import Foundation

@MainActor
@Observable
final class MarkdownDocument {
    var markdown: String = ""
    var title: String = "Marka"
    var baseURL: URL?
}
