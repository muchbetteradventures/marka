import SwiftUI

struct FrontmatterInfoView: View {
    let fields: [(key: String, value: String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Document Info")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            ForEach(Array(fields.enumerated()), id: \.offset) { _, field in
                FieldRow(key: field.key, value: field.value)
            }
        }
        .padding(14)
        .frame(minWidth: 260, maxWidth: 320)
    }
}

// MARK: - FieldRow

private struct FieldRow: View {
    let key: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(key.uppercased())
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .tracking(0.3)
            renderedValue
        }
    }

    @ViewBuilder
    private var renderedValue: some View {
        switch classify(value) {
        case .datetime(let date, let hasTime):
            Text(format(date, hasTime: hasTime))
                .font(.system(size: 12))
        case .array(let items):
            tagsView(items)
        case .text(let str):
            Text(str)
                .font(.system(size: 12))
                .lineLimit(3)
        }
    }

    private func tagsView(_ items: [String]) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Text(item)
                    .font(.system(size: 10))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Value classification

private enum FieldValue {
    case datetime(Date, hasTime: Bool)
    case array([String])
    case text(String)
}

private enum Formatters {
    nonisolated(unsafe) static let isoFull: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    nonisolated(unsafe) static let dateOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    nonisolated(unsafe) static let displayWithTime: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "d MMM yyyy, HH:mm 'UTC'"
        return f
    }()

    nonisolated(unsafe) static let displayDateOnly: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "d MMM yyyy"
        return f
    }()
}

private func classify(_ raw: String) -> FieldValue {
    if let date = Formatters.isoFull.date(from: raw) {
        return .datetime(date, hasTime: true)
    }
    if let date = Formatters.dateOnly.date(from: raw) {
        return .datetime(date, hasTime: false)
    }
    if let items = parseFlowArray(raw) {
        return .array(items)
    }
    return .text(raw)
}

private func parseFlowArray(_ raw: String) -> [String]? {
    let trimmed = raw.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix("["), trimmed.hasSuffix("]") else { return nil }
    let inner = String(trimmed.dropFirst().dropLast())
    guard !inner.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
    let items = inner
        .components(separatedBy: ",")
        .map {
            $0.trimmingCharacters(in: .whitespaces)
              .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        }
        .filter { !$0.isEmpty }
    return items.isEmpty ? nil : items
}

private func format(_ date: Date, hasTime: Bool) -> String {
    hasTime
        ? Formatters.displayWithTime.string(from: date)
        : Formatters.displayDateOnly.string(from: date)
}
