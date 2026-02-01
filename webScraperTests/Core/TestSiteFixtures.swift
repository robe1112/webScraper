//
//  TestSiteFixtures.swift
//  webScraperTests
//
//  Test website fixtures for integration testing.
//  HTML is embedded to avoid bundle resource path issues across build configs.
//

import Foundation

enum TestSiteFixtures {

    /// Base URL for the test site (used for resolving relative URLs in tests)
    static let baseURL = URL(string: "https://test-site.example.com")!

    /// Load HTML content by fixture name
    static func loadHTML(_ name: String) -> String? {
        switch name {
        case "index.html": return indexHTML
        case "about.html": return aboutHTML
        case "contact.html": return contactHTML
        case "blog.html": return blogHTML
        case "blog-article-1.html": return blogArticle1HTML
        case "blog-article-2.html": return blogArticle2HTML
        case "products.html": return productsHTML
        default: return nil
        }
    }

    /// Load fixture as Data (for JSON etc.)
    static func loadData(_ name: String) -> Data? {
        if name == "api-data.json" {
            return apiDataJSON.data(using: .utf8)
        }
        return loadHTML(name)?.data(using: .utf8)
    }

    // MARK: - Embedded Fixtures

    static let indexHTML = """
    <!DOCTYPE html>
    <html lang="en">
    <head><meta charset="UTF-8"><title>Test Site - Home</title></head>
    <body>
        <nav>
            <a href="/index.html">Home</a>
            <a href="/about.html">About</a>
            <a href="/contact.html">Contact</a>
            <a href="/blog.html">Blog</a>
            <a href="/products.html">Products</a>
        </nav>
        <h1>Test Website</h1>
        <p>A fixture site for automated scraping tests</p>
        <section class="intro"><h2>Welcome</h2><p>This is a test website.</p></section>
        <img src="/images/logo.png" alt="Logo" title="Logo">
    </body>
    </html>
    """

    static let aboutHTML = """
    <!DOCTYPE html>
    <html><head><title>About - Test Site</title></head>
    <body>
        <nav><a href="/index.html">Home</a> <a href="/about.html">About</a></nav>
        <article><h1 class="page-title">About Us</h1><p class="content">We are a fictional organization.</p></article>
    </body>
    </html>
    """

    static let contactHTML = """
    <!DOCTYPE html>
    <html><head><title>Contact</title></head>
    <body><nav><a href="/index.html">Home</a></nav><h1>Contact Us</h1><p>Email: test@example.com</p></body>
    </html>
    """

    static let blogHTML = """
    <!DOCTYPE html>
    <html><head><title>Blog</title></head>
    <body>
        <nav><a href="/index.html">Home</a> <a href="/blog.html">Blog</a></nav>
        <h1>Blog</h1>
        <article><h2><a href="/blog-article-1.html">First Test Article</a></h2><p class="excerpt">Extraction testing.</p></article>
        <article><h2><a href="/blog-article-2.html">Second Test Article</a></h2></article>
    </body>
    </html>
    """

    static let blogArticle1HTML = """
    <!DOCTYPE html>
    <html>
    <head>
        <meta name="author" content="Jane Doe">
        <meta name="description" content="First test article">
        <title>First Test Article</title>
    </head>
    <body>
        <article>
            <header>
                <h1 class="article-title headline">First Test Article</h1>
                <span class="author byline">Jane Doe</span>
                <time class="publish-date date" datetime="2025-01-15">January 15, 2025</time>
                <span class="category section-name">Testing</span>
            </header>
            <div class="content article-body story-body">
                <p>This is the first test article with structured content for extraction rules.</p>
                <p>Additional content for full-text extraction.</p>
            </div>
        </article>
    </body>
    </html>
    """

    static let blogArticle2HTML = """
    <!DOCTYPE html>
    <html>
    <head><meta name="author" content="John Smith"><title>Second Test Article</title></head>
    <body>
        <article>
            <h1 class="article-title">Second Test Article</h1>
            <span class="author">John Smith</span>
            <time class="publish-date" datetime="2025-01-20">January 20, 2025</time>
            <span class="category">Development</span>
            <div class="article-body"><p>Second article content.</p></div>
        </article>
    </body>
    </html>
    """

    static let productsHTML = """
    <!DOCTYPE html>
    <html><head><title>Products</title></head>
    <body>
        <nav><a href="/index.html">Home</a> <a href="/products.html">Products</a></nav>
        <h1>Products</h1>
        <article class="product" data-sku="SKU-001" data-price="29.99">
            <h2 class="product-title product-name">Test Product One</h2>
            <span class="price product-price">$29.99</span>
            <p class="description product-description">A test product.</p>
            <span class="sku product-sku">SKU-001</span>
            <span class="availability stock-status">In Stock</span>
        </article>
        <article class="product" data-sku="SKU-002">
            <h1 class="product-title">Test Product Two</h1>
            <span class="product-price">$49.99</span>
        </article>
    </body>
    </html>
    """

    static let apiDataJSON = """
    {"items":[{"id":1,"name":"API Item 1","value":100},{"id":2,"name":"API Item 2","value":200}],"total":2}
    """

    // Convenience aliases for tests
    static var article1HTML: String { blogArticle1HTML }
    static var article2HTML: String { blogArticle2HTML }
    static var blogIndexHTML: String { blogHTML }
}
