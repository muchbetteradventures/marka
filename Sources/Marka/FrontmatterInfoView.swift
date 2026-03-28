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
            ForEach(items, id: \.self) { item in
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

private func classify(_ raw: String) -> FieldValue {
    // ISO 8601 with time: 2013-04-04T15:22:06+00:00 or 2013-04-04T15:22:06Z
    let isoFull = ISO8601DateFormatter()
    isoFull.formatOptions = [.withInternetDateTime]
    if let date = isoFull.date(from: raw) {
        return .datetime(date, hasTime: true)
    }

    // Date only: 2024-01-15
    let dateFmt = DateFormatter()
    dateFmt.dateFormat = "yyyy-MM-dd"
    dateFmt.locale = Locale(identifier: "en_US_POSIX")
    if let date = dateFmt.date(from: raw) {
        return .datetime(date, hasTime: false)
    }

    // YAML flow array: ["a", "b"] or ["single"]
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
    let fmt = DateFormatter()
    fmt.locale = Locale(identifier: "en_US_POSIX")
    if hasTime {
        fmt.timeZone = TimeZone(identifier: "UTC")
        fmt.dateFormat = "d MMM yyyy, HH:mm 'UTC'"
    } else {
        fmt.dateFormat = "d MMM yyyy"
    }
    return fmt.string(from: date)
}
