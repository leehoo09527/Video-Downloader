import Cocoa

final class LinkEditor: NSTextView {
    private let gutter: CGFloat = 42
    private let rowHeight: CGFloat = 34
    func configure() {
        isRichText = false
        font = .systemFont(ofSize: 14)
        textContainerInset = NSSize(width: 52, height: 12)
        let paragraph = NSMutableParagraphStyle()
        paragraph.paragraphSpacing = 16
        defaultParagraphStyle = paragraph
        typingAttributes = [.font: font!, .paragraphStyle: paragraph, .foregroundColor: NSColor.labelColor]
        backgroundColor = .textBackgroundColor
    }
    override func didChangeText() {
        super.didChangeText()
        if let style = defaultParagraphStyle {
            textStorage?.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: (string as NSString).length))
        }
        needsDisplay = true
    }
    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        guard let manager = layoutManager, let container = textContainer else { return }
        manager.ensureLayout(for: container)
        NSColor.clear.setFill()
        NSRect(x: 0, y: rect.minY, width: gutter, height: rect.height).fill()
        let source = string as NSString
        var offset = 0
        var number = 1
        var bottom: CGFloat = textContainerInset.height
        func drawRow(_ top: CGFloat, _ end: CGFloat, _ index: Int) {
            if end >= rect.minY && top <= rect.maxY {
                let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium), .foregroundColor: NSColor.secondaryLabelColor]
                let label = String(format: "%02d", index) as NSString
                let width = label.size(withAttributes: attrs).width
                label.draw(at: NSPoint(x: gutter - 12 - width, y: top + 1), withAttributes: attrs)
                NSColor.separatorColor.withAlphaComponent(0.12).setFill()
                NSRect(x: gutter, y: end - 8, width: max(0, bounds.width - gutter - 18), height: 0.5).fill()
            }
        }
        while offset < source.length {
            let paragraph = source.paragraphRange(for: NSRange(location: offset, length: 0))
            let glyphs = manager.glyphRange(forCharacterRange: paragraph, actualCharacterRange: nil)
            if glyphs.length > 0 {
                let first = manager.lineFragmentRect(forGlyphAt: glyphs.location, effectiveRange: nil)
                let last = manager.lineFragmentRect(forGlyphAt: NSMaxRange(glyphs) - 1, effectiveRange: nil)
                let top = first.minY + textContainerInset.height
                bottom = last.maxY + textContainerInset.height
                if NSMaxRange(paragraph) == source.length && !string.hasSuffix("\n") { bottom += 16 }
                drawRow(top, bottom, number)
            }
            offset = NSMaxRange(paragraph); number += 1
        }
        // Empty rows keep the entry area legible; their numbers are decoration, never pasted text.
        while bottom + rowHeight <= max(bounds.height, rect.maxY) {
            drawRow(bottom, bottom + rowHeight, number)
            bottom += rowHeight; number += 1
        }
        if string.isEmpty {
            ("粘贴视频链接，每行一个…" as NSString).draw(at: NSPoint(x: 55, y: textContainerInset.height), withAttributes: [.font: NSFont.systemFont(ofSize: 14), .foregroundColor: NSColor.placeholderTextColor])
        }
    }
}
