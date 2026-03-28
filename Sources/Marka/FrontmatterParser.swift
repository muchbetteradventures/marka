import Foundation

struct FrontmatterResult {
    let body: String
    let fields: [(key: String, value: String)]
}

enum FrontmatterParser {
    /// Parse frontmatter and body from a markdown string.
    /// Returns empty fields and the original string as body when no valid
    /// frontmatter block (opening `---`, closing `---` or `...`) is found.
    static func parse(_ content: String) -> FrontmatterResult {
        let lines = content.components(separatedBy: "\n")
        guard lines.first == "---" || lines.first == "---\r" else {
            return FrontmatterResult(body: content, fields: [])
        }

        var endLine: Int? = nil
        for i in 1..<lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .init(charactersIn: "\r"))
            if trimmed == "---" || trimmed == "..." {
                endLine = i
                break
            }
        }

        guard let end = endLine else {
            return FrontmatterResult(body: content, fields: [])
        }

        var fields: [(key: String, value: String)] = []
        for i in 1..<end {
            let line = lines[i].trimmingCharacters(in: .init(charactersIn: "\r"))
            if let colonIdx = line.firstIndex(of: ":") {
                let key = String(line[..<colonIdx]).trimmingCharacters(in: .whitespaces)
                let value = String(line[line.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
                if !key.isEmpty {
                    fields.append((key: key, value: value))
                }
            }
        }

        let body = lines[(end + 1)...].joined(separator: "\n")
        return FrontmatterResult(body: body, fields: fields)
    }

    /// Returns the markdown body with YAML frontmatter stripped.
    /// If no valid frontmatter block is found the original string is returned unchanged.
    static func body(from content: String) -> String {
        parse(content).body
    }
}
