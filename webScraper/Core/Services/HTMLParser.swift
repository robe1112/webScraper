//
//  HTMLParser.swift
//  webScraper
//
//  Created by Rob Evans on 1/31/26.
//

import Foundation

/// Parses HTML content and extracts elements using CSS selectors
/// Provides a simple API similar to SwiftSoup
/// All members are nonisolated so it can be used from CrawlerEngine (non-MainActor actor)
final class HTMLParser {
    
    // MARK: - Types
    
    struct ParsedDocument {
        let html: String
        let title: String?
        let metaTags: [MetaTag]
        let links: [ParsedLink]
        let images: [ParsedImage]
        let scripts: [ParsedScript]
        let stylesheets: [ParsedStylesheet]
        let textContent: String
    }
    
    struct MetaTag {
        let name: String?
        let property: String?
        let content: String?
        let httpEquiv: String?
    }
    
    struct ParsedLink {
        let href: String
        let text: String
        let title: String?
        let rel: String?
        let target: String?
    }
    
    struct ParsedImage {
        let src: String
        let alt: String?
        let title: String?
        let width: String?
        let height: String?
    }
    
    struct ParsedScript {
        let src: String?
        let type: String?
        let content: String?
    }
    
    struct ParsedStylesheet {
        let href: String
        let media: String?
    }
    
    // MARK: - Properties
    
    private let html: String
    
    // MARK: - Initialization
    
    nonisolated init(html: String) {
        self.html = html
    }
    
    // MARK: - Parsing
    
    /// Parse the document and extract all elements
    nonisolated func parse() -> ParsedDocument {
        ParsedDocument(
            html: html,
            title: extractTitle(),
            metaTags: extractMetaTags(),
            links: extractLinks(),
            images: extractImages(),
            scripts: extractScripts(),
            stylesheets: extractStylesheets(),
            textContent: extractTextContent()
        )
    }
    
    /// Extract title from the document
    func extractTitle() -> String? {
        if let match = html.range(of: "<title[^>]*>(.*?)</title>", options: [.regularExpression, .caseInsensitive]) {
            let titleTag = String(html[match])
            return extractTagContent(from: titleTag)?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
    
    /// Extract all meta tags
    func extractMetaTags() -> [MetaTag] {
        var tags: [MetaTag] = []
        let pattern = "<meta\\s+[^>]*>"
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(html.startIndex..., in: html)
            let matches = regex.matches(in: html, range: range)
            
            for match in matches {
                if let matchRange = Range(match.range, in: html) {
                    let tag = String(html[matchRange])
                    tags.append(MetaTag(
                        name: extractAttribute(named: "name", from: tag),
                        property: extractAttribute(named: "property", from: tag),
                        content: extractAttribute(named: "content", from: tag),
                        httpEquiv: extractAttribute(named: "http-equiv", from: tag)
                    ))
                }
            }
        }
        
        return tags
    }
    
    /// Extract all links
    func extractLinks() -> [ParsedLink] {
        var links: [ParsedLink] = []
        let pattern = "<a\\s+[^>]*href\\s*=\\s*[\"']([^\"']*)[\"'][^>]*>(.*?)</a>"
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            let range = NSRange(html.startIndex..., in: html)
            let matches = regex.matches(in: html, range: range)
            
            for match in matches {
                if let fullRange = Range(match.range, in: html) {
                    let tag = String(html[fullRange])
                    
                    if match.numberOfRanges > 2,
                       let hrefRange = Range(match.range(at: 1), in: html),
                       let textRange = Range(match.range(at: 2), in: html) {
                        
                        let href = String(html[hrefRange])
                        let text = stripHTML(String(html[textRange]))
                        
                        links.append(ParsedLink(
                            href: href,
                            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                            title: extractAttribute(named: "title", from: tag),
                            rel: extractAttribute(named: "rel", from: tag),
                            target: extractAttribute(named: "target", from: tag)
                        ))
                    }
                }
            }
        }
        
        return links
    }
    
    /// Extract all images
    func extractImages() -> [ParsedImage] {
        var images: [ParsedImage] = []
        let pattern = "<img\\s+[^>]*>"
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(html.startIndex..., in: html)
            let matches = regex.matches(in: html, range: range)
            
            for match in matches {
                if let matchRange = Range(match.range, in: html) {
                    let tag = String(html[matchRange])
                    
                    if let src = extractAttribute(named: "src", from: tag) {
                        images.append(ParsedImage(
                            src: src,
                            alt: extractAttribute(named: "alt", from: tag),
                            title: extractAttribute(named: "title", from: tag),
                            width: extractAttribute(named: "width", from: tag),
                            height: extractAttribute(named: "height", from: tag)
                        ))
                    }
                }
            }
        }
        
        return images
    }
    
    /// Extract all scripts
    func extractScripts() -> [ParsedScript] {
        var scripts: [ParsedScript] = []
        let pattern = "<script\\s*[^>]*>(.*?)</script>"
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            let range = NSRange(html.startIndex..., in: html)
            let matches = regex.matches(in: html, range: range)
            
            for match in matches {
                if let fullRange = Range(match.range, in: html) {
                    let tag = String(html[fullRange])
                    
                    var content: String?
                    if match.numberOfRanges > 1, let contentRange = Range(match.range(at: 1), in: html) {
                        content = String(html[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        if content?.isEmpty == true { content = nil }
                    }
                    
                    scripts.append(ParsedScript(
                        src: extractAttribute(named: "src", from: tag),
                        type: extractAttribute(named: "type", from: tag),
                        content: content
                    ))
                }
            }
        }
        
        return scripts
    }
    
    /// Extract all stylesheets
    func extractStylesheets() -> [ParsedStylesheet] {
        var stylesheets: [ParsedStylesheet] = []
        let pattern = "<link\\s+[^>]*rel\\s*=\\s*[\"']stylesheet[\"'][^>]*>"
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(html.startIndex..., in: html)
            let matches = regex.matches(in: html, range: range)
            
            for match in matches {
                if let matchRange = Range(match.range, in: html) {
                    let tag = String(html[matchRange])
                    
                    if let href = extractAttribute(named: "href", from: tag) {
                        stylesheets.append(ParsedStylesheet(
                            href: href,
                            media: extractAttribute(named: "media", from: tag)
                        ))
                    }
                }
            }
        }
        
        return stylesheets
    }
    
    /// Extract text content (strip all HTML tags)
    func extractTextContent() -> String {
        stripHTML(html)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
    
    // MARK: - CSS Selector Queries
    
    /// Select elements using a CSS selector (simplified implementation)
    func select(_ selector: String) -> [String] {
        var results: [String] = []
        
        // Handle simple selectors
        if selector.hasPrefix("#") {
            // ID selector
            let id = String(selector.dropFirst())
            results = selectById(id)
        } else if selector.hasPrefix(".") {
            // Class selector
            let className = String(selector.dropFirst())
            results = selectByClass(className)
        } else if selector.contains("[") {
            // Attribute selector
            results = selectByAttribute(selector)
        } else {
            // Tag selector
            results = selectByTag(selector)
        }
        
        return results
    }
    
    /// Get text from elements matching selector
    func selectText(_ selector: String) -> [String] {
        select(selector).map { stripHTML($0).trimmingCharacters(in: .whitespacesAndNewlines) }
    }
    
    /// Get first element matching selector
    func selectFirst(_ selector: String) -> String? {
        select(selector).first
    }
    
    /// Get attribute value from elements matching selector
    func selectAttribute(_ selector: String, attribute: String) -> [String] {
        select(selector).compactMap { extractAttribute(named: attribute, from: $0) }
    }
    
    // MARK: - Private Methods
    
    private func selectById(_ id: String) -> [String] {
        let pattern = "<[^>]+id\\s*=\\s*[\"']\(NSRegularExpression.escapedPattern(for: id))[\"'][^>]*>.*?</[^>]+>"
        return matchPattern(pattern)
    }
    
    private func selectByClass(_ className: String) -> [String] {
        let pattern = "<[^>]+class\\s*=\\s*[\"'][^\"']*\\b\(NSRegularExpression.escapedPattern(for: className))\\b[^\"']*[\"'][^>]*>.*?</[^>]+>"
        return matchPattern(pattern)
    }
    
    private func selectByTag(_ tag: String) -> [String] {
        let pattern = "<\(NSRegularExpression.escapedPattern(for: tag))[^>]*>.*?</\(NSRegularExpression.escapedPattern(for: tag))>"
        return matchPattern(pattern)
    }
    
    private func selectByAttribute(_ selector: String) -> [String] {
        // Parse selector like "a[href]" or "a[href='value']"
        let pattern = "([a-zA-Z0-9]+)\\[([a-zA-Z0-9-]+)(?:=['\"]?([^'\"\\]]*)['\"]?)?\\]"
        
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: selector, range: NSRange(selector.startIndex..., in: selector)) else {
            return []
        }
        
        let tag = match.numberOfRanges > 1 ? String(selector[Range(match.range(at: 1), in: selector)!]) : "*"
        let attr = match.numberOfRanges > 2 ? String(selector[Range(match.range(at: 2), in: selector)!]) : ""
        let value = match.numberOfRanges > 3 && match.range(at: 3).location != NSNotFound ? 
            String(selector[Range(match.range(at: 3), in: selector)!]) : nil
        
        var htmlPattern: String
        if let value = value {
            htmlPattern = "<\(tag)[^>]+\(attr)\\s*=\\s*[\"']\(NSRegularExpression.escapedPattern(for: value))[\"'][^>]*>.*?</\(tag)>"
        } else {
            htmlPattern = "<\(tag)[^>]+\(attr)\\s*=[^>]*>.*?</\(tag)>"
        }
        
        return matchPattern(htmlPattern)
    }
    
    private func matchPattern(_ pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return []
        }
        
        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, range: range)
        
        return matches.compactMap { match -> String? in
            guard let matchRange = Range(match.range, in: html) else { return nil }
            return String(html[matchRange])
        }
    }
    
    private func extractAttribute(named name: String, from tag: String) -> String? {
        let pattern = "\(name)\\s*=\\s*[\"']([^\"']*)[\"']"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: tag, range: NSRange(tag.startIndex..., in: tag)),
              match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: tag) else {
            return nil
        }
        
        return String(tag[valueRange])
    }
    
    private func extractTagContent(from tag: String) -> String? {
        let pattern = ">([^<]*)<"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators),
              let match = regex.firstMatch(in: tag, range: NSRange(tag.startIndex..., in: tag)),
              match.numberOfRanges > 1,
              let contentRange = Range(match.range(at: 1), in: tag) else {
            return nil
        }
        
        return String(tag[contentRange])
    }
    
    private func stripHTML(_ html: String) -> String {
        var text = html
        
        // Remove script and style contents
        text = text.replacingOccurrences(of: "<script[^>]*>.*?</script>", with: " ", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: "<style[^>]*>.*?</style>", with: " ", options: [.regularExpression, .caseInsensitive])
        
        // Remove all HTML tags
        text = text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        
        // Decode HTML entities
        text = decodeHTMLEntities(text)
        
        // Collapse whitespace
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func decodeHTMLEntities(_ string: String) -> String {
        var result = string
        
        let entities: [String: String] = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'",
            "&nbsp;": " ",
            "&#39;": "'",
            "&#x27;": "'",
            "&mdash;": "—",
            "&ndash;": "–",
            "&copy;": "©",
            "&reg;": "®",
            "&trade;": "™"
        ]
        
        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        
        // Handle numeric entities
        let numericPattern = "&#([0-9]+);"
        if let regex = try? NSRegularExpression(pattern: numericPattern) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "") // Simplified
        }
        
        return result
    }
}
