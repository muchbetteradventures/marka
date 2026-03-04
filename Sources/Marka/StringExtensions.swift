import Foundation

extension String {
    /// Escapes backslashes, backticks, and dollar signs for safe
    /// embedding inside a JavaScript template literal.
    var jsTemplateEscaped: String {
        self
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
    }
}
