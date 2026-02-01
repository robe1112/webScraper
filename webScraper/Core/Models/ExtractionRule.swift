//
//  ExtractionRule.swift
//  webScraper
//
//  Created by Rob Evans on 1/31/26.
//

import Foundation

/// Defines a rule for extracting data from web pages
/// Supports CSS selectors, XPath, and regex patterns
struct ExtractionRule: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var fieldName: String  // Key for extracted data
    var ruleType: ExtractionRuleType
    var selector: String  // CSS, XPath, or regex pattern
    var attribute: String?  // HTML attribute to extract (nil = text content)
    var transformation: DataTransformation?
    var isRequired: Bool
    var defaultValue: String?
    var isEnabled: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        fieldName: String,
        ruleType: ExtractionRuleType,
        selector: String,
        attribute: String? = nil,
        transformation: DataTransformation? = nil,
        isRequired: Bool = false,
        defaultValue: String? = nil,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.fieldName = fieldName
        self.ruleType = ruleType
        self.selector = selector
        self.attribute = attribute
        self.transformation = transformation
        self.isRequired = isRequired
        self.defaultValue = defaultValue
        self.isEnabled = isEnabled
    }
}

/// Type of extraction rule
enum ExtractionRuleType: String, Codable, CaseIterable {
    case cssSelector = "CSS Selector"
    case xpath = "XPath"
    case regex = "Regex"
    case jsonPath = "JSON Path"
    case meta = "Meta Tag"
    
    var description: String {
        switch self {
        case .cssSelector:
            return "Use CSS selectors like 'div.content > p' or '#main-title'"
        case .xpath:
            return "Use XPath expressions like '//div[@class=\"content\"]/p'"
        case .regex:
            return "Use regular expressions with capture groups"
        case .jsonPath:
            return "Use JSON Path for structured data"
        case .meta:
            return "Extract meta tag content by name or property"
        }
    }
    
    var placeholder: String {
        switch self {
        case .cssSelector:
            return "div.content > p.text"
        case .xpath:
            return "//div[@class='content']/p"
        case .regex:
            return "Price: \\$([0-9.]+)"
        case .jsonPath:
            return "$.data.items[*].name"
        case .meta:
            return "og:title"
        }
    }
}

/// Transformation to apply to extracted data
struct DataTransformation: Codable, Hashable {
    var operations: [TransformOperation]
    
    init(operations: [TransformOperation] = []) {
        self.operations = operations
    }
}

/// Individual transformation operation
enum TransformOperation: Codable, Hashable {
    case trim
    case lowercase
    case uppercase
    case removeHTML
    case extractNumbers
    case extractEmails
    case extractURLs
    case replace(pattern: String, replacement: String)
    case prefix(String)
    case suffix(String)
    case split(separator: String)
    case join(separator: String)
    case regexCapture(pattern: String, group: Int)
    case dateFormat(from: String, to: String)
    case custom(name: String, script: String)
}

// MARK: - Predefined Rule Templates

extension ExtractionRule {
    
    /// Common extraction rule templates
    static var templates: [ExtractionRule] {
        [
            ExtractionRule(
                name: "Page Title",
                fieldName: "title",
                ruleType: .cssSelector,
                selector: "title",
                isRequired: true
            ),
            ExtractionRule(
                name: "Meta Description",
                fieldName: "description",
                ruleType: .meta,
                selector: "description"
            ),
            ExtractionRule(
                name: "Main Content",
                fieldName: "content",
                ruleType: .cssSelector,
                selector: "article, main, .content, #content",
                transformation: DataTransformation(operations: [.removeHTML, .trim])
            ),
            ExtractionRule(
                name: "All Headings",
                fieldName: "headings",
                ruleType: .cssSelector,
                selector: "h1, h2, h3"
            ),
            ExtractionRule(
                name: "All Paragraphs",
                fieldName: "paragraphs",
                ruleType: .cssSelector,
                selector: "p"
            ),
            ExtractionRule(
                name: "Email Addresses",
                fieldName: "emails",
                ruleType: .regex,
                selector: "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}"
            ),
            ExtractionRule(
                name: "Phone Numbers",
                fieldName: "phones",
                ruleType: .regex,
                selector: "\\(?\\d{3}\\)?[-.\\s]?\\d{3}[-.\\s]?\\d{4}"
            ),
            ExtractionRule(
                name: "Prices",
                fieldName: "prices",
                ruleType: .regex,
                selector: "\\$[0-9,]+\\.?[0-9]*"
            ),
            ExtractionRule(
                name: "Open Graph Image",
                fieldName: "ogImage",
                ruleType: .meta,
                selector: "og:image"
            ),
            ExtractionRule(
                name: "Author",
                fieldName: "author",
                ruleType: .meta,
                selector: "author"
            )
        ]
    }
}
