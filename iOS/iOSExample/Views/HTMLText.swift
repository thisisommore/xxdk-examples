//
//  HTMLText.swift
//  iOSExample
//
//  Created by Om More on 29/09/25.
//

import SwiftUI
import UIKit

// MARK: - Attributed helpers

private extension NSAttributedString {
    /// Replace every font run with a system font, preserving bold/italic and (optionally) the original point size.
    func withSystemFonts(
        baseTextStyle: UIFont.TextStyle = .body,
        preserveSizes: Bool = true,
        preserveBoldItalic: Bool = true,
        customFontSize: CGFloat? = nil
    ) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: self)
        let full = NSRange(location: 0, length: mutable.length)

        mutable.enumerateAttributes(in: full, options: []) { attrs, range, _ in
            let srcFont = (attrs[.font] as? UIFont) ?? UIFont.preferredFont(forTextStyle: baseTextStyle)

            let baseSize: CGFloat = preserveSizes
                ? srcFont.pointSize
                : UIFont.preferredFont(forTextStyle: baseTextStyle).pointSize
            
            let size = customFontSize ?? (baseSize * 1.4)

            var weight: UIFont.Weight = .regular
            if preserveBoldItalic, srcFont.fontDescriptor.symbolicTraits.contains(.traitBold) {
                weight = .bold
            }

            var newFont = UIFont.systemFont(ofSize: size, weight: weight)

            if preserveBoldItalic, srcFont.fontDescriptor.symbolicTraits.contains(.traitItalic) {
                var traits = newFont.fontDescriptor.symbolicTraits
                traits.insert(.traitItalic)
                if let desc = newFont.fontDescriptor.withSymbolicTraits(traits) {
                    newFont = UIFont(descriptor: desc, size: size)
                }
            }

            mutable.addAttribute(.font, value: newFont, range: range)
        }

        return mutable
    }

    /// Force the foreground color for **all** text runs.
    func withForegroundColor(_ color: UIColor) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: self)
        let full = NSRange(location: 0, length: mutable.length)
        mutable.addAttribute(.foregroundColor, value: color, range: full)
        return mutable
    }

    /// Recolor only link runs (and their underline) to a specific UIColor.
    func withLinkColor(_ color: UIColor, underline: Bool = true) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: self)
        let full = NSRange(location: 0, length: mutable.length)

        mutable.enumerateAttribute(.link, in: full, options: []) { value, range, _ in
            guard value != nil else { return }
            var attrs: [NSAttributedString.Key: Any] = [.foregroundColor: color]
            if underline {
                attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
                attrs[.underlineColor] = color
            } else {
                attrs[.underlineStyle] = 0
            }
            mutable.addAttributes(attrs, range: range)
        }

        return mutable
    }

    /// Remove trailing `\n`/`\r` characters that HTML import often appends.
    func trimmingTrailingNewlines() -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: self)
        while mutable.length > 0 {
            let last = (mutable.string as NSString).substring(with: NSRange(location: mutable.length - 1, length: 1))
            if last == "\n" || last == "\r" {
                mutable.deleteCharacters(in: NSRange(location: mutable.length - 1, length: 1))
            } else {
                break
            }
        }
        return mutable
    }

    /// Zero out paragraph spacing AFTER the **last** paragraph only (prevents extra bottom gap).
    func removingBottomParagraphSpacing() -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: self)
        guard mutable.length > 0 else { return mutable }

        let nsString = mutable.string as NSString
        let lastIndex = max(mutable.length - 1, 0)
        let lastParaRange = nsString.paragraphRange(for: NSRange(location: lastIndex, length: 0))

        let currentStyle = (mutable.attribute(.paragraphStyle, at: lastIndex, effectiveRange: nil) as? NSParagraphStyle) ?? NSParagraphStyle.default
        let newStyle = (currentStyle.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
        newStyle.paragraphSpacing = 0
        newStyle.paragraphSpacingBefore = 0

        mutable.addAttribute(.paragraphStyle, value: newStyle, range: lastParaRange)
        return mutable
    }
}

// MARK: - View

@available(iOS 15.0, *)
struct HTMLText: View {
    private let html: String
    private let textColor: Color
    private let linkColor: Color
    private let underlineLinks: Bool
    private let baseTextStyle: UIFont.TextStyle
    private let preserveSizes: Bool
    private let preserveBoldItalic: Bool
    private let customFontSize: CGFloat?
    
    @State private var attributedString: AttributedString?

    /// - Parameters:
    ///   - html: Raw HTML string.
    ///   - textColor: Desired color for all text (default: `.white`).
    ///   - linkColor: Desired color for link text/underline (default: `.white`).
    ///   - underlineLinks: Whether links should be underlined (default: `true`).
    ///   - baseTextStyle: Base text style used if a run has no size (default: `.body`).
    ///   - preserveSizes: Keep original point sizes from HTML (keeps H1/H2 larger). Default `true`.
    ///   - preserveBoldItalic: Keep bold/italic traits from HTML. Default `true`.
    init(
        _ html: String,
        textColor: Color = .white,
        linkColor: Color = .white,
        underlineLinks: Bool = true,
        baseTextStyle: UIFont.TextStyle = .body,
        preserveSizes: Bool = true,
        preserveBoldItalic: Bool = true,
        customFontSize: CGFloat? = nil
    ) {
        self.html = html
        self.textColor = textColor
        self.linkColor = linkColor
        self.underlineLinks = underlineLinks
        self.baseTextStyle = baseTextStyle
        self.preserveSizes = preserveSizes
        self.preserveBoldItalic = preserveBoldItalic
        self.customFontSize = customFontSize
    }

    var body: some View {
        Group {
            if let attributedString = attributedString {
                Text(attributedString)
                    .tint(linkColor) // for SwiftUI-driven link styling
            } else {
                Text(html).foregroundStyle(textColor)
            }
        }
        .task {
            await loadAttributedString()
        }
        .onChange(of: html) { _, _ in
            Task { await loadAttributedString() }
        }
        .onChange(of: textColor) { _, _ in
            Task { await loadAttributedString() }
        }
        .onChange(of: linkColor) { _, _ in
            Task { await loadAttributedString() }
        }
        .onChange(of: underlineLinks) { _, _ in
            Task { await loadAttributedString() }
        }
        .onChange(of: customFontSize) { _, _ in
            Task { await loadAttributedString() }
        }
    }
    
    /// Modifier to set a custom font size
    func fontSize(_ size: CGFloat) -> HTMLText {
        HTMLText(
            html,
            textColor: textColor,
            linkColor: linkColor,
            underlineLinks: underlineLinks,
            baseTextStyle: baseTextStyle,
            preserveSizes: preserveSizes,
            preserveBoldItalic: preserveBoldItalic,
            customFontSize: size
        )
    }
    
    @MainActor
    private func loadAttributedString() async {
        await Task.detached {
            let ns = makeNSAttributedString(fromHTML: html)
            
            guard let ns = ns else {
                await MainActor.run { attributedString = nil }
                return
            }
            
            // Normalize fonts/colors/links, then remove trailing newline and last-paragraph spacing.
            let normalized = ns
                .withSystemFonts(
                    baseTextStyle: baseTextStyle,
                    preserveSizes: preserveSizes,
                    preserveBoldItalic: preserveBoldItalic,
                    customFontSize: customFontSize
                )
                .withForegroundColor(UIColor(textColor))
                .withLinkColor(UIColor(linkColor), underline: underlineLinks)
                .trimmingTrailingNewlines()
                .removingBottomParagraphSpacing()
            
            let attr = try? AttributedString(normalized, including: \.uiKit)
            await MainActor.run { attributedString = attr }
        }.value
    }

    // MARK: - HTML → NSAttributedString

    private func makeNSAttributedString(fromHTML html: String) -> NSAttributedString? {
        let data = Data(html.utf8)
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        return try? NSAttributedString(data: data, options: options, documentAttributes: nil)
    }
}

// MARK: - Preview

@available(iOS 15.0, *)
struct HTMLText_Previews: PreviewProvider {
    static var previews: some View {
        HTMLText("""
            <p>This is a paragraph with a <a href="https://example.com">link</a>,
            and <strong>bold</strong>/<em>italic</em> text.</p>
            <h2>Heading keeps larger size</h2>
            """,
            textColor: .white,
            linkColor: .white,
            underlineLinks: true,
            baseTextStyle: .body,
            preserveSizes: true,
            preserveBoldItalic: true
        )
        .padding()
        .background(Color.blue) // blue preview background
        .previewLayout(.sizeThatFits)
    }
}
