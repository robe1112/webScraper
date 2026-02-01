//
//  SiteNodeTests.swift
//  webScraperTests
//
//  Unit tests for SiteNode and NodeFileType
//  Follows Arrange-Act-Assert pattern per .cursor/rules
//

import Testing
import Foundation
@testable import webScraper

struct SiteNodeTests {

    // MARK: - SiteNode.normalizeURL Tests

    @Test("Normalize URL lowercases scheme and host")
    func normalizeURLLowercases() throws {
        // Arrange
        let url = "HTTPS://WWW.EXAMPLE.COM/Path"

        // Act
        let normalized = SiteNode.normalizeURL(url)

        // Assert
        #expect(normalized.contains("https://"))
    }

    @Test("Normalize URL removes fragment")
    func normalizeURLRemovesFragment() throws {
        // Arrange
        let url = "https://example.com/page#anchor"

        // Act
        let normalized = SiteNode.normalizeURL(url)

        // Assert
        #expect(!normalized.contains("#"))
    }

    @Test("Normalize URL removes trailing slash")
    func normalizeURLRemovesTrailingSlash() throws {
        // Arrange
        let url = "https://example.com/path/"

        // Act
        let normalized = SiteNode.normalizeURL(url)

        // Assert
        #expect(!normalized.hasSuffix("/") || normalized == "https://example.com")
    }

    @Test("Normalize URL preserves root path")
    func normalizeURLPreservesRoot() throws {
        // Arrange
        let url = "https://example.com/"

        // Act
        let normalized = SiteNode.normalizeURL(url)

        // Assert
        #expect(normalized.contains("example.com"))
    }

    // MARK: - NodeFileType.detect Tests (by extension)

    @Test("Detect PDF by extension")
    func detectPDFByExtension() throws {
        // Arrange & Act
        let type = NodeFileType.detect(url: "https://example.com/doc.pdf", contentType: nil)

        // Assert
        #expect(type == .pdf)
    }

    @Test("Detect image by extension")
    func detectImageByExtension() throws {
        // Arrange & Act
        let type = NodeFileType.detect(url: "https://example.com/photo.jpg", contentType: nil)

        // Assert
        #expect(type == .image)
    }

    @Test("Detect script by extension")
    func detectScriptByExtension() throws {
        // Arrange & Act
        let type = NodeFileType.detect(url: "https://example.com/app.js", contentType: nil)

        // Assert
        #expect(type == .script)
    }

    @Test("Detect stylesheet by extension")
    func detectStylesheetByExtension() throws {
        // Arrange & Act
        let type = NodeFileType.detect(url: "https://example.com/style.css", contentType: nil)

        // Assert
        #expect(type == .stylesheet)
    }

    @Test("Detect JSON as data")
    func detectJSONAsData() throws {
        // Arrange & Act
        let type = NodeFileType.detect(url: "https://api.example.com/data.json", contentType: nil)

        // Assert
        #expect(type == .data)
    }

    @Test("Detect archive by extension")
    func detectArchiveByExtension() throws {
        // Arrange & Act
        let type = NodeFileType.detect(url: "https://example.com/files.zip", contentType: nil)

        // Assert
        #expect(type == .archive)
    }

    @Test("Detect video by extension")
    func detectVideoByExtension() throws {
        // Arrange & Act
        let type = NodeFileType.detect(url: "https://example.com/video.mp4", contentType: nil)

        // Assert
        #expect(type == .video)
    }

    @Test("Detect audio by extension")
    func detectAudioByExtension() throws {
        // Arrange & Act
        let type = NodeFileType.detect(url: "https://example.com/audio.mp3", contentType: nil)

        // Assert
        #expect(type == .audio)
    }

    // MARK: - NodeFileType.detect Tests (by content type)

    @Test("Detect page by HTML content type")
    func detectPageByContentType() throws {
        // Arrange & Act
        let type = NodeFileType.detect(url: "https://example.com/dynamic", contentType: "text/html")

        // Assert
        #expect(type == .page)
    }

    @Test("Detect image by content type")
    func detectImageByContentType() throws {
        // Arrange & Act
        let type = NodeFileType.detect(url: "https://example.com/asset", contentType: "image/png")

        // Assert
        #expect(type == .image)
    }

    @Test("Detect PDF by content type")
    func detectPDFByContentType() throws {
        // Arrange & Act
        let type = NodeFileType.detect(url: "https://example.com/file", contentType: "application/pdf")

        // Assert
        #expect(type == .pdf)
    }

    // MARK: - NodeFileType.detect Edge Cases

    @Test("HTML extension defaults to page")
    func detectHTMLExtensionAsPage() throws {
        // Arrange & Act
        let type = NodeFileType.detect(url: "https://example.com/index.html", contentType: nil)

        // Assert
        #expect(type == .page)
    }

    @Test("Unknown extension defaults to other or page")
    func detectUnknownExtension() throws {
        // Arrange & Act
        let type = NodeFileType.detect(url: "https://example.com/file.xyz", contentType: nil)

        // Assert
        #expect(type == .other)
    }
}
