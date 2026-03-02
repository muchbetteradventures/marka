import Foundation

@MainActor
@Observable
final class MarkdownDocument {
    var markdown: String = ""
    var title: String = "Markie"
    var baseURL: URL?
}
