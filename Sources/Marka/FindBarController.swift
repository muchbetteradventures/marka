import AppKit
import MarkdownView

@MainActor
final class FindBarController: NSView, NSTextFieldDelegate {
    private let searchField = NSTextField()
    private let matchLabel = NSTextField(labelWithString: "")
    private let prevButton = NSButton()
    private let nextButton = NSButton()
    private let closeButton = NSButton()

    private weak var markdownTextView: MarkdownTextView?
    private weak var scrollView: NSScrollView?

    private var matches: [NSRange] = []
    private var currentMatch: Int = -1

    init(markdownTextView: MarkdownTextView, scrollView: NSScrollView) {
        self.markdownTextView = markdownTextView
        self.scrollView = scrollView
        super.init(frame: NSRect(x: 0, y: 0, width: 400, height: 32))
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        searchField.placeholderString = "Find"
        searchField.delegate = self
        searchField.target = self
        searchField.action = #selector(searchFieldAction)
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.focusRingType = .none
        searchField.bezelStyle = .roundedBezel

        matchLabel.translatesAutoresizingMaskIntoConstraints = false
        matchLabel.font = NSFont.systemFont(ofSize: 11)
        matchLabel.textColor = .secondaryLabelColor
        matchLabel.setContentHuggingPriority(.required, for: .horizontal)

        prevButton.bezelStyle = .inline
        prevButton.image = NSImage(systemSymbolName: "chevron.up", accessibilityDescription: "Previous")
        prevButton.target = self
        prevButton.action = #selector(previousMatch)
        prevButton.translatesAutoresizingMaskIntoConstraints = false
        prevButton.setContentHuggingPriority(.required, for: .horizontal)

        nextButton.bezelStyle = .inline
        nextButton.image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: "Next")
        nextButton.target = self
        nextButton.action = #selector(nextMatch)
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.setContentHuggingPriority(.required, for: .horizontal)

        closeButton.bezelStyle = .inline
        closeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")
        closeButton.target = self
        closeButton.action = #selector(closeFindBar)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setContentHuggingPriority(.required, for: .horizontal)

        addSubview(searchField)
        addSubview(matchLabel)
        addSubview(prevButton)
        addSubview(nextButton)
        addSubview(closeButton)

        NSLayoutConstraint.activate([
            searchField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            searchField.centerYAnchor.constraint(equalTo: centerYAnchor),
            searchField.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),

            matchLabel.leadingAnchor.constraint(equalTo: searchField.trailingAnchor, constant: 8),
            matchLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            prevButton.leadingAnchor.constraint(equalTo: matchLabel.trailingAnchor, constant: 4),
            prevButton.centerYAnchor.constraint(equalTo: centerYAnchor),

            nextButton.leadingAnchor.constraint(equalTo: prevButton.trailingAnchor, constant: 2),
            nextButton.centerYAnchor.constraint(equalTo: centerYAnchor),

            closeButton.leadingAnchor.constraint(greaterThanOrEqualTo: nextButton.trailingAnchor, constant: 8),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),

            heightAnchor.constraint(equalToConstant: 32),
        ])

        translatesAutoresizingMaskIntoConstraints = false
    }

    func controlTextDidChange(_ obj: Notification) {
        performSearch()
    }

    @objc private func searchFieldAction() {
        if NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
            previousMatch()
        } else {
            nextMatch()
        }
    }

    private func performSearch() {
        let query = searchField.stringValue
        matches = []
        currentMatch = -1

        guard !query.isEmpty,
              let fullString = markdownTextView?.textView.textLayout.attributedString.string else {
            matchLabel.stringValue = ""
            markdownTextView?.textView.selectionRange = nil
            return
        }

        let text = fullString as NSString
        var searchRange = NSRange(location: 0, length: text.length)
        while searchRange.location < text.length {
            let foundRange = text.range(of: query, options: [.caseInsensitive], range: searchRange)
            if foundRange.location == NSNotFound { break }
            matches.append(foundRange)
            searchRange.location = foundRange.location + foundRange.length
            searchRange.length = text.length - searchRange.location
        }

        if matches.isEmpty {
            matchLabel.stringValue = "No matches"
            markdownTextView?.textView.selectionRange = nil
        } else {
            currentMatch = 0
            navigateToCurrentMatch()
        }
    }

    @objc private func nextMatch() {
        guard !matches.isEmpty else { return }
        currentMatch = (currentMatch + 1) % matches.count
        navigateToCurrentMatch()
    }

    @objc private func previousMatch() {
        guard !matches.isEmpty else { return }
        currentMatch = (currentMatch - 1 + matches.count) % matches.count
        navigateToCurrentMatch()
    }

    private func navigateToCurrentMatch() {
        guard currentMatch >= 0, currentMatch < matches.count else { return }
        let range = matches[currentMatch]

        matchLabel.stringValue = "\(currentMatch + 1) of \(matches.count)"
        markdownTextView?.textView.selectionRange = range

        // Scroll to the match
        let rects = markdownTextView?.textView.textLayout.rects(for: range) ?? []
        if let rect = rects.first, let scrollView = scrollView, let markdownTextView = markdownTextView {
            let rectInScrollView = markdownTextView.convert(rect, to: scrollView.contentView)
            scrollView.contentView.scrollToVisible(rectInScrollView.insetBy(dx: 0, dy: -40))
        }
    }

    @objc private func closeFindBar() {
        markdownTextView?.textView.selectionRange = nil
        Self.dismiss(from: window)
    }

    override func cancelOperation(_ sender: Any?) {
        closeFindBar()
    }

    // MARK: - Static management

    static func toggle(in window: NSWindow, markdownTextView: MarkdownTextView, scrollView: NSScrollView) {
        if findExisting(in: window) != nil {
            dismiss(from: window)
            return
        }
        show(in: window, markdownTextView: markdownTextView, scrollView: scrollView)
    }

    static func show(in window: NSWindow, markdownTextView: MarkdownTextView, scrollView: NSScrollView) {
        guard let contentView = window.contentView else { return }
        if findExisting(in: window) != nil { return }

        let findBar = FindBarController(markdownTextView: markdownTextView, scrollView: scrollView)
        contentView.addSubview(findBar)

        NSLayoutConstraint.activate([
            findBar.topAnchor.constraint(equalTo: contentView.topAnchor),
            findBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            findBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])

        window.makeFirstResponder(findBar.searchField)
    }

    static func dismiss(from window: NSWindow?) {
        findExisting(in: window)?.removeFromSuperview()
    }

    private static func findExisting(in window: NSWindow?) -> FindBarController? {
        window?.contentView?.subviews.first(where: { $0 is FindBarController }) as? FindBarController
    }
}
