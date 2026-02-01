//
//  DataExtractor.swift
//  webScraper
//
//  Created by Rob Evans on 1/31/26.
//

import Foundation

/// Extracts data from HTML using extraction rules
/// Supports CSS selectors, regex, and meta tag extraction
final class DataExtractor {
    
    // MARK: - Types
    
    struct ExtractionResult {
        let ruleId: UUID
        let fieldName: String
        let values: [String]
        let success: Bool
        let errorMessage: String?
    }
    
    // MARK: - Properties
    
    private let parser: HTMLParser
    
    // MARK: - Initialization
    
    init(html: String) {
        self.parser = HTMLParser(html: html)
    }
    
    init(parser: HTMLParser) {
        self.parser = parser
    }
    
    // MARK: - Extraction
    
    /// Extract data using a single rule
    func extract(rule: ExtractionRule) -> ExtractionResult {
        guard rule.isEnabled else {
            return ExtractionResult(
                ruleId: rule.id,
                fieldName: rule.fieldName,
                values: [],
                success: true,
                errorMessage: "Rule is disabled"
            )
        }
        
        do {
            var values: [String]
            
            switch rule.ruleType {
            case .cssSelector:
                values = try extractWithCSS(selector: rule.selector, attribute: rule.attribute)
            case .xpath:
                values = try extractWithXPath(expression: rule.selector, attribute: rule.attribute)
            case .regex:
                values = try extractWithRegex(pattern: rule.selector)
            case .jsonPath:
                values = try extractWithJSONPath(path: rule.selector)
            case .meta:
                values = try extractMeta(name: rule.selector)
            }
            
            // Apply transformations
            if let transformation = rule.transformation {
                values = applyTransformations(values, operations: transformation.operations)
            }
            
            // Handle empty results
            if values.isEmpty {
                if rule.isRequired {
                    return ExtractionResult(
                        ruleId: rule.id,
                        fieldName: rule.fieldName,
                        values: [],
                        success: false,
                        errorMessage: "Required field not found"
                    )
                }
                
                if let defaultValue = rule.defaultValue {
                    values = [defaultValue]
                }
            }
            
            return ExtractionResult(
                ruleId: rule.id,
                fieldName: rule.fieldName,
                values: values,
                success: true,
                errorMessage: nil
            )
            
        } catch {
            return ExtractionResult(
                ruleId: rule.id,
                fieldName: rule.fieldName,
                values: rule.defaultValue.map { [$0] } ?? [],
                success: false,
                errorMessage: error.localizedDescription
            )
        }
    }
    
    /// Extract data using multiple rules
    func extract(rules: [ExtractionRule]) -> [String: ExtractedValue] {
        var results: [String: ExtractedValue] = [:]
        
        for rule in rules {
            let result = extract(rule: rule)
            
            if result.values.isEmpty {
                results[rule.fieldName] = .null
            } else if result.values.count == 1 {
                results[rule.fieldName] = .string(result.values[0])
            } else {
                results[rule.fieldName] = .strings(result.values)
            }
        }
        
        return results
    }
    
    /// Extract all common elements (title, meta, links, etc.)
    func extractCommon() -> [String: ExtractedValue] {
        let document = parser.parse()
        var results: [String: ExtractedValue] = [:]
        
        // Title
        if let title = document.title {
            results["title"] = .string(title)
        }
        
        // Meta description
        if let description = document.metaTags.first(where: { $0.name == "description" })?.content {
            results["description"] = .string(description)
        }
        
        // Meta keywords
        if let keywords = document.metaTags.first(where: { $0.name == "keywords" })?.content {
            results["keywords"] = .strings(keywords.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) })
        }
        
        // Open Graph
        for meta in document.metaTags where meta.property?.hasPrefix("og:") == true {
            if let property = meta.property, let content = meta.content {
                let key = property.replacingOccurrences(of: "og:", with: "og_")
                results[key] = .string(content)
            }
        }
        
        // Twitter Card
        for meta in document.metaTags where meta.name?.hasPrefix("twitter:") == true {
            if let name = meta.name, let content = meta.content {
                let key = name.replacingOccurrences(of: "twitter:", with: "twitter_")
                results[key] = .string(content)
            }
        }
        
        // Canonical URL
        // (Would need additional parsing for <link rel="canonical">)
        
        return results
    }
    
    // MARK: - Private Extraction Methods
    
    private func extractWithCSS(selector: String, attribute: String?) throws -> [String] {
        if let attr = attribute {
            return parser.selectAttribute(selector, attribute: attr)
        } else {
            return parser.selectText(selector)
        }
    }
    
    private func extractWithXPath(expression: String, attribute: String?) throws -> [String] {
        // XPath support would require additional library
        // For now, try to convert simple XPath to CSS selector
        let cssSelector = convertXPathToCSS(expression)
        return try extractWithCSS(selector: cssSelector, attribute: attribute)
    }
    
    private func extractWithRegex(pattern: String) throws -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            throw ExtractionError.invalidPattern(pattern)
        }
        
        let document = parser.parse()
        let text = document.html
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)
        
        var results: [String] = []
        
        for match in matches {
            // If there are capture groups, extract them
            if match.numberOfRanges > 1 {
                for i in 1..<match.numberOfRanges {
                    if let captureRange = Range(match.range(at: i), in: text) {
                        results.append(String(text[captureRange]))
                    }
                }
            } else {
                // Otherwise extract the whole match
                if let matchRange = Range(match.range, in: text) {
                    results.append(String(text[matchRange]))
                }
            }
        }
        
        return results
    }
    
    private func extractWithJSONPath(path: String) throws -> [String] {
        // JSON Path support is simplified
        // Would need a proper JSON Path library for full support
        
        // Try to find JSON in script tags
        let document = parser.parse()
        
        for script in document.scripts {
            if let content = script.content,
               content.contains("{"),
               let data = content.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                // Simple path evaluation
                let value = evaluateSimpleJSONPath(path, in: json)
                if let stringValue = value as? String {
                    return [stringValue]
                } else if let arrayValue = value as? [String] {
                    return arrayValue
                }
            }
        }
        
        return []
    }
    
    private func extractMeta(name: String) throws -> [String] {
        let document = parser.parse()
        
        // Check by name
        if let meta = document.metaTags.first(where: { $0.name == name }),
           let content = meta.content {
            return [content]
        }
        
        // Check by property (for Open Graph, etc.)
        if let meta = document.metaTags.first(where: { $0.property == name }),
           let content = meta.content {
            return [content]
        }
        
        return []
    }
    
    // MARK: - Transformations
    
    private func applyTransformations(_ values: [String], operations: [TransformOperation]) -> [String] {
        var result = values
        
        for operation in operations {
            result = result.map { value in
                applyOperation(operation, to: value)
            }
        }
        
        return result
    }
    
    private func applyOperation(_ operation: TransformOperation, to value: String) -> String {
        switch operation {
        case .trim:
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
            
        case .lowercase:
            return value.lowercased()
            
        case .uppercase:
            return value.uppercased()
            
        case .removeHTML:
            return value.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            
        case .extractNumbers:
            return value.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            
        case .extractEmails:
            let emailPattern = "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}"
            if let regex = try? NSRegularExpression(pattern: emailPattern),
               let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
               let range = Range(match.range, in: value) {
                return String(value[range])
            }
            return ""
            
        case .extractURLs:
            let urlPattern = "https?://[^\\s<>\"']+"
            if let regex = try? NSRegularExpression(pattern: urlPattern),
               let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
               let range = Range(match.range, in: value) {
                return String(value[range])
            }
            return ""
            
        case .replace(let pattern, let replacement):
            return value.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
            
        case .prefix(let prefix):
            return prefix + value
            
        case .suffix(let suffix):
            return value + suffix
            
        case .split(let separator):
            // Returns first element after split
            return value.components(separatedBy: separator).first ?? value
            
        case .join(let separator):
            // For single values, this is a no-op
            return value
            
        case .regexCapture(let pattern, let group):
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
               match.numberOfRanges > group,
               let range = Range(match.range(at: group), in: value) {
                return String(value[range])
            }
            return ""
            
        case .dateFormat(let from, let to):
            let inputFormatter = DateFormatter()
            inputFormatter.dateFormat = from
            
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = to
            
            if let date = inputFormatter.date(from: value) {
                return outputFormatter.string(from: date)
            }
            return value
            
        case .custom(_, _):
            // Custom scripts would need additional sandboxed execution
            return value
        }
    }
    
    // MARK: - Helper Methods
    
    private func convertXPathToCSS(_ xpath: String) -> String {
        // Very simplified XPath to CSS conversion
        var css = xpath
        
        // //div -> div
        css = css.replacingOccurrences(of: "//", with: "")
        
        // /div -> > div
        css = css.replacingOccurrences(of: "/", with: " > ")
        
        // [@class='x'] -> .x
        let classPattern = "\\[@class=['\"]([^'\"]+)['\"]\\]"
        if let regex = try? NSRegularExpression(pattern: classPattern) {
            css = regex.stringByReplacingMatches(in: css, range: NSRange(css.startIndex..., in: css), withTemplate: ".$1")
        }
        
        // [@id='x'] -> #x
        let idPattern = "\\[@id=['\"]([^'\"]+)['\"]\\]"
        if let regex = try? NSRegularExpression(pattern: idPattern) {
            css = regex.stringByReplacingMatches(in: css, range: NSRange(css.startIndex..., in: css), withTemplate: "#$1")
        }
        
        return css.trimmingCharacters(in: .whitespaces)
    }
    
    private func evaluateSimpleJSONPath(_ path: String, in json: [String: Any]) -> Any? {
        // Remove leading $. if present
        var cleanPath = path
        if cleanPath.hasPrefix("$.") {
            cleanPath = String(cleanPath.dropFirst(2))
        }
        
        let parts = cleanPath.components(separatedBy: ".")
        var current: Any = json
        
        for part in parts {
            if let dict = current as? [String: Any] {
                if let next = dict[part] {
                    current = next
                } else {
                    return nil
                }
            } else if let array = current as? [Any], let index = Int(part) {
                if index < array.count {
                    current = array[index]
                } else {
                    return nil
                }
            } else {
                return nil
            }
        }
        
        return current
    }
}

// MARK: - Errors

enum ExtractionError: LocalizedError {
    case invalidPattern(String)
    case extractionFailed(String)
    case transformationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidPattern(let pattern):
            return "Invalid pattern: \(pattern)"
        case .extractionFailed(let message):
            return "Extraction failed: \(message)"
        case .transformationFailed(let message):
            return "Transformation failed: \(message)"
        }
    }
}
