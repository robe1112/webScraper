//
//  TestSiteIntegrationTests.swift
//  webScraperTests
//
//  Integration tests using the bundled TestSite fixture website
//  Follows Arrange-Act-Assert per .cursor/rules
//

import Testing
import Foundation
@testable import webScraper

@Suite("TestSite Integration Tests")
struct TestSiteIntegrationTests {

    @Test("TestSite fixtures load successfully")
    func fixturesLoad() throws {
        // Arrange & Act
        let index = TestSiteFixtures.indexHTML
        let article = TestSiteFixtures.article1HTML

        // Assert
        #expect(!index.isEmpty, "index.html should be available")
        #expect(!article.isEmpty, "blog-article-1 should be available")
        #expect(index.contains("Test Website") == true)
        #expect(article.contains("First Test Article") == true)
        #expect(TestSiteFixtures.loadData("api-data.json") != nil)
    }

    @Test("HTMLParser extracts links from index")
    func parserExtractsLinksFromIndex() throws {
        // Arrange
        let html = TestSiteFixtures.indexHTML
        let parser = HTMLParser(html: html)

        // Act
        let doc = parser.parse()

        // Assert
        #expect(doc.links.count >= 4, "Index should have nav links (Home, About, Contact, Blog, Products)")
        let hrefs = doc.links.map { $0.href }
        #expect(hrefs.contains { $0.contains("about") || $0.contains("about.html") })
        #expect(doc.title?.contains("Test Site") == true)
    }

    @Test("HTMLParser extracts title and meta from index")
    func parserExtractsMeta() throws {
        // Arrange
        let html = TestSiteFixtures.indexHTML
        let parser = HTMLParser(html: html)

        // Act
        let doc = parser.parse()

        // Assert
        #expect(doc.title != nil)
        #expect(doc.title?.contains("Test Site") == true)
        #expect(doc.textContent.contains("Welcome") || doc.html.contains("Welcome"))
    }

    @Test("DataExtractor finds article content with News template rules")
    func extractorFindsArticleContent() throws {
        // Arrange
        let html = TestSiteFixtures.article1HTML
        let extractor = DataExtractor(html: html)
        // Use selectors supported by HTMLParser: .class, tag, #id
        let rules: [ExtractionRule] = [
            ExtractionRule(name: "Title", fieldName: "title", ruleType: .cssSelector, selector: ".article-title", isRequired: true),
            ExtractionRule(name: "Content", fieldName: "content", ruleType: .cssSelector, selector: ".article-body"),
            ExtractionRule(name: "Author", fieldName: "author", ruleType: .cssSelector, selector: ".author"),
            ExtractionRule(name: "Date", fieldName: "publishDate", ruleType: .cssSelector, selector: ".publish-date"),
            ExtractionRule(name: "Category", fieldName: "category", ruleType: .cssSelector, selector: ".category")
        ]

        // Act
        let results = extractor.extract(rules: rules)

        // Assert
        if case .string(let title) = results["title"] {
            #expect(title.contains("First Test Article"))
        } else {
            Issue.record("Expected to extract title")
        }
        if case .string(let author) = results["author"] {
            #expect(author.contains("Jane Doe"))
        }
        if case .string(let category) = results["category"] {
            #expect(category.contains("Testing"))
        }
    }

    @Test("DataExtractor finds product data with E-commerce rules")
    func extractorFindsProductData() throws {
        // Arrange
        let html = TestSiteFixtures.productsHTML
        let extractor = DataExtractor(html: html)
        let rules: [ExtractionRule] = [
            ExtractionRule(name: "Product Name", fieldName: "name", ruleType: .cssSelector, selector: ".product-title", isRequired: true),
            ExtractionRule(name: "Price", fieldName: "price", ruleType: .cssSelector, selector: ".product-price"),
            ExtractionRule(name: "SKU", fieldName: "sku", ruleType: .cssSelector, selector: ".product-sku")
        ]

        // Act
        let results = extractor.extract(rules: rules)

        // Assert - first product
        #expect(results["name"] != nil)
        if case .string(let name) = results["name"] {
            #expect(name.contains("Product") || name.contains("Test"))
        }
    }

    @Test("SiteMapBuilder builds tree from TestSite link structure")
    func siteMapFromTestSiteStructure() async throws {
        // Arrange - simulate adding nodes as if we crawled TestSite
        let jobId = UUID()
        let builder = SiteMapBuilder(jobId: jobId)
        let base = TestSiteFixtures.baseURL

        // Act - add pages in crawl order
        _ = await builder.addNode(url: base, parentURL: nil, depth: 0, title: "Test Site", statusCode: 200)
        _ = await builder.addNode(url: base.appendingPathComponent("about.html"), parentURL: base, depth: 1, title: "About", statusCode: 200)
        _ = await builder.addNode(url: base.appendingPathComponent("contact.html"), parentURL: base, depth: 1, title: "Contact", statusCode: 200)
        _ = await builder.addNode(url: base.appendingPathComponent("blog.html"), parentURL: base, depth: 1, title: "Blog", statusCode: 200)

        let stats = await builder.getStats()
        let root = await builder.getRootNode()

        // Assert
        #expect(stats.totalNodes == 4)
        #expect(stats.totalPages == 4)
        #expect(root != nil)
        #expect(root?.title == "Test Site")
        let children = await builder.getChildren(of: root!.id)
        #expect(children.count == 3)
    }

    @Test("Extract meta tag with meta rule type")
    func extractorMetaTag() throws {
        // Arrange
        let html = TestSiteFixtures.article1HTML
        let extractor = DataExtractor(html: html)
        let rule = ExtractionRule(name: "Author", fieldName: "author", ruleType: .meta, selector: "author")

        // Act
        let result = extractor.extract(rule: rule)

        // Assert
        #expect(result.success == true)
        #expect(result.values.contains { $0.contains("Jane") })
    }

    @Test("API JSON fixture loads for JSON Path tests")
    func jsonFixtureLoads() throws {
        // Arrange & Act
        let data = TestSiteFixtures.loadData("api-data.json")

        // Assert
        #expect(data != nil)
        if let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let items = json["items"] as? [[String: Any]]
            #expect(items?.count == 2)
        }
    }
}
