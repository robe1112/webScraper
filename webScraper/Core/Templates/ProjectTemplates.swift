//
//  ProjectTemplates.swift
//  webScraper
//
//  Created by Rob Evans on 1/31/26.
//

import Foundation

/// Predefined project templates for common use cases
struct ProjectTemplate: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let category: TemplateCategory
    let settings: ProjectSettings
    let extractionRules: [ExtractionRule]
    let icon: String
    
    enum TemplateCategory: String, Codable, CaseIterable {
        case general = "General"
        case news = "News & Media"
        case ecommerce = "E-Commerce"
        case government = "Government"
        case research = "Research"
        case social = "Social Media"
        case custom = "Custom"
    }
}

/// Built-in project templates
struct ProjectTemplates {
    
    /// All available templates
    static let all: [ProjectTemplate] = [
        basicWebsite,
        newsArticles,
        governmentDocuments,
        ecommerceProducts,
        researchPapers,
        blogPosts,
        documentArchive,
        apiEndpoint
    ]
    
    // MARK: - Template Definitions
    
    /// Basic website scraping
    static let basicWebsite = ProjectTemplate(
        id: UUID(),
        name: "Basic Website",
        description: "General-purpose website scraping with standard settings",
        category: .general,
        settings: ProjectSettings(
            maxDepth: 5,
            maxPages: 500,
            respectRobotsTxt: true,
            enableJavaScript: false,
            downloadImages: false,
            downloadPDFs: true
        ),
        extractionRules: ExtractionRule.templates,
        icon: "globe"
    )
    
    /// News article scraping
    static let newsArticles = ProjectTemplate(
        id: UUID(),
        name: "News Articles",
        description: "Optimized for scraping news websites and articles",
        category: .news,
        settings: ProjectSettings(
            maxDepth: 3,
            maxPages: 1000,
            respectRobotsTxt: true,
            requestDelayMs: 2000,
            enableJavaScript: true,
            downloadImages: true,
            downloadPDFs: false
        ),
        extractionRules: [
            ExtractionRule(
                name: "Article Title",
                fieldName: "title",
                ruleType: .cssSelector,
                selector: "article h1, .article-title, .headline",
                isRequired: true
            ),
            ExtractionRule(
                name: "Article Body",
                fieldName: "content",
                ruleType: .cssSelector,
                selector: "article .content, .article-body, .story-body",
                transformation: DataTransformation(operations: [.removeHTML, .trim])
            ),
            ExtractionRule(
                name: "Author",
                fieldName: "author",
                ruleType: .cssSelector,
                selector: ".author, .byline, [rel='author']"
            ),
            ExtractionRule(
                name: "Publish Date",
                fieldName: "publishDate",
                ruleType: .cssSelector,
                selector: "time, .publish-date, .date"
            ),
            ExtractionRule(
                name: "Category",
                fieldName: "category",
                ruleType: .cssSelector,
                selector: ".category, .section-name"
            )
        ],
        icon: "newspaper"
    )
    
    /// Government document scraping (like DOJ)
    static let governmentDocuments = ProjectTemplate(
        id: UUID(),
        name: "Government Documents",
        description: "For scraping government websites and document archives",
        category: .government,
        settings: ProjectSettings(
            maxDepth: 10,
            maxPages: 5000,
            respectRobotsTxt: true,
            requestDelayMs: 3000,
            maxConcurrentRequests: 2,
            enableJavaScript: true,
            downloadImages: false,
            downloadPDFs: true,
            downloadDocuments: true,
            downloadMedia: true,
            maxFileSizeMB: 1000
        ),
        extractionRules: [
            ExtractionRule(
                name: "Document Title",
                fieldName: "title",
                ruleType: .cssSelector,
                selector: "h1, .document-title, .page-title"
            ),
            ExtractionRule(
                name: "Document Date",
                fieldName: "date",
                ruleType: .cssSelector,
                selector: ".date, .document-date, time"
            ),
            ExtractionRule(
                name: "Document Type",
                fieldName: "documentType",
                ruleType: .cssSelector,
                selector: ".document-type, .file-type"
            ),
            ExtractionRule(
                name: "Department",
                fieldName: "department",
                ruleType: .cssSelector,
                selector: ".department, .agency"
            )
        ],
        icon: "building.columns"
    )
    
    /// E-commerce product scraping
    static let ecommerceProducts = ProjectTemplate(
        id: UUID(),
        name: "E-Commerce Products",
        description: "For scraping product listings and details",
        category: .ecommerce,
        settings: ProjectSettings(
            maxDepth: 4,
            maxPages: 2000,
            respectRobotsTxt: true,
            requestDelayMs: 2000,
            enableJavaScript: true,
            downloadImages: true,
            downloadPDFs: false
        ),
        extractionRules: [
            ExtractionRule(
                name: "Product Name",
                fieldName: "name",
                ruleType: .cssSelector,
                selector: "h1, .product-title, .product-name",
                isRequired: true
            ),
            ExtractionRule(
                name: "Price",
                fieldName: "price",
                ruleType: .cssSelector,
                selector: ".price, .product-price, [data-price]",
                transformation: DataTransformation(operations: [.extractNumbers])
            ),
            ExtractionRule(
                name: "Description",
                fieldName: "description",
                ruleType: .cssSelector,
                selector: ".description, .product-description, #description"
            ),
            ExtractionRule(
                name: "SKU",
                fieldName: "sku",
                ruleType: .cssSelector,
                selector: ".sku, .product-sku, [data-sku]"
            ),
            ExtractionRule(
                name: "Availability",
                fieldName: "availability",
                ruleType: .cssSelector,
                selector: ".availability, .stock-status"
            ),
            ExtractionRule(
                name: "Rating",
                fieldName: "rating",
                ruleType: .cssSelector,
                selector: ".rating, .stars, [data-rating]"
            )
        ],
        icon: "cart"
    )
    
    /// Research paper scraping
    static let researchPapers = ProjectTemplate(
        id: UUID(),
        name: "Research Papers",
        description: "For academic and research paper repositories",
        category: .research,
        settings: ProjectSettings(
            maxDepth: 3,
            maxPages: 1000,
            respectRobotsTxt: true,
            requestDelayMs: 3000,
            enableJavaScript: false,
            downloadPDFs: true,
            downloadDocuments: true
        ),
        extractionRules: [
            ExtractionRule(
                name: "Paper Title",
                fieldName: "title",
                ruleType: .cssSelector,
                selector: "h1, .paper-title, .article-title",
                isRequired: true
            ),
            ExtractionRule(
                name: "Authors",
                fieldName: "authors",
                ruleType: .cssSelector,
                selector: ".authors, .author-list, [rel='author']"
            ),
            ExtractionRule(
                name: "Abstract",
                fieldName: "abstract",
                ruleType: .cssSelector,
                selector: ".abstract, #abstract, .summary"
            ),
            ExtractionRule(
                name: "DOI",
                fieldName: "doi",
                ruleType: .regex,
                selector: "10\\.\\d{4,}/[^\\s]+"
            ),
            ExtractionRule(
                name: "Publication Date",
                fieldName: "publicationDate",
                ruleType: .cssSelector,
                selector: ".pub-date, .publication-date"
            ),
            ExtractionRule(
                name: "Keywords",
                fieldName: "keywords",
                ruleType: .cssSelector,
                selector: ".keywords, .tags"
            )
        ],
        icon: "doc.text.magnifyingglass"
    )
    
    /// Blog post scraping
    static let blogPosts = ProjectTemplate(
        id: UUID(),
        name: "Blog Posts",
        description: "For scraping blogs and personal websites",
        category: .general,
        settings: ProjectSettings(
            maxDepth: 4,
            maxPages: 500,
            respectRobotsTxt: true,
            enableJavaScript: false,
            downloadImages: true,
            downloadPDFs: false
        ),
        extractionRules: [
            ExtractionRule(
                name: "Post Title",
                fieldName: "title",
                ruleType: .cssSelector,
                selector: "h1, .post-title, .entry-title"
            ),
            ExtractionRule(
                name: "Post Content",
                fieldName: "content",
                ruleType: .cssSelector,
                selector: ".post-content, .entry-content, article .content",
                transformation: DataTransformation(operations: [.removeHTML, .trim])
            ),
            ExtractionRule(
                name: "Author",
                fieldName: "author",
                ruleType: .cssSelector,
                selector: ".author, .post-author"
            ),
            ExtractionRule(
                name: "Date",
                fieldName: "date",
                ruleType: .cssSelector,
                selector: "time, .post-date, .entry-date"
            ),
            ExtractionRule(
                name: "Tags",
                fieldName: "tags",
                ruleType: .cssSelector,
                selector: ".tags a, .post-tags a"
            )
        ],
        icon: "text.bubble"
    )
    
    /// Document archive scraping
    static let documentArchive = ProjectTemplate(
        id: UUID(),
        name: "Document Archive",
        description: "For bulk downloading documents from archives",
        category: .general,
        settings: ProjectSettings(
            maxDepth: 8,
            maxPages: 10000,
            respectRobotsTxt: true,
            requestDelayMs: 2000,
            maxConcurrentRequests: 2,
            enableJavaScript: true,
            downloadImages: false,
            downloadPDFs: true,
            downloadDocuments: true,
            downloadMedia: true,
            maxFileSizeMB: 2000
        ),
        extractionRules: [],
        icon: "archivebox"
    )
    
    /// API endpoint scraping
    static let apiEndpoint = ProjectTemplate(
        id: UUID(),
        name: "API / JSON Data",
        description: "For scraping JSON APIs and data endpoints",
        category: .general,
        settings: ProjectSettings(
            maxDepth: 1,
            maxPages: 100,
            respectRobotsTxt: false,
            requestDelayMs: 500,
            enableJavaScript: false,
            downloadImages: false,
            downloadPDFs: false
        ),
        extractionRules: [
            ExtractionRule(
                name: "JSON Data",
                fieldName: "data",
                ruleType: .jsonPath,
                selector: "$"
            )
        ],
        icon: "curlybraces"
    )
    
    // MARK: - Helper Methods
    
    /// Get templates by category
    static func templates(for category: ProjectTemplate.TemplateCategory) -> [ProjectTemplate] {
        all.filter { $0.category == category }
    }
    
    /// Get template by ID
    static func template(id: UUID) -> ProjectTemplate? {
        all.first { $0.id == id }
    }
    
    /// Create project from template
    static func createProject(from template: ProjectTemplate, name: String, startURL: String) -> Project {
        Project(
            name: name,
            startURL: startURL,
            settings: template.settings
        )
    }
}
