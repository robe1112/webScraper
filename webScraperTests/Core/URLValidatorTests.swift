//
//  URLValidatorTests.swift
//  webScraperTests
//
//  Unit tests for URLValidator - validation, normalization, domain extraction
//  Follows Arrange-Act-Assert pattern per .cursor/rules
//

import Testing
import Foundation
@testable import webScraper

struct URLValidatorTests {

    // MARK: - Validation Tests

    @Test("Valid HTTPS URL returns valid result")
    func validHttpsURL() throws {
        // Arrange
        let urlString = "https://example.com/page"

        // Act
        let result = URLValidator.validate(urlString)

        // Assert
        #expect(result.isValid == true)
        #expect(result.url?.absoluteString == "https://example.com/page")
    }

    @Test("Valid HTTP URL returns valid result")
    func validHttpURL() throws {
        // Arrange
        let urlString = "http://example.org"

        // Act
        let result = URLValidator.validate(urlString)

        // Assert
        #expect(result.isValid == true)
        #expect(result.url?.scheme == "http")
    }

    @Test("Empty URL returns invalid")
    func emptyURLInvalid() throws {
        // Arrange
        let urlString = ""

        // Act
        let result = URLValidator.validate(urlString)

        // Assert
        #expect(result.isValid == false)
        if case .invalid(let reason) = result {
            #expect(reason.contains("empty"))
        } else {
            Issue.record("Expected invalid result for empty URL")
        }
    }

    @Test("Whitespace-only URL returns invalid")
    func whitespaceURLInvalid() throws {
        // Arrange
        let urlString = "   \t  "

        // Act
        let result = URLValidator.validate(urlString)

        // Assert
        #expect(result.isValid == false)
    }

    @Test("Invalid format returns invalid")
    func invalidFormat() throws {
        // Arrange
        let urlString = "not-a-valid-url"

        // Act
        let result = URLValidator.validate(urlString)

        // Assert
        #expect(result.isValid == false)
        if case .invalid(let reason) = result {
            #expect(reason.contains("format") || reason.contains("scheme"))
        }
    }

    @Test("FTP URL returns invalid - only HTTP/HTTPS supported")
    func ftpURLInvalid() throws {
        // Arrange
        let urlString = "ftp://files.example.com"

        // Act
        let result = URLValidator.validate(urlString)

        // Assert
        #expect(result.isValid == false)
        if case .invalid(let reason) = result {
            #expect(reason.contains("HTTP") || reason.contains("HTTPS"))
        }
    }

    @Test("URL without host returns invalid")
    func urlWithoutHostInvalid() throws {
        // Arrange
        let urlString = "https://"

        // Act
        let result = URLValidator.validate(urlString)

        // Assert
        #expect(result.isValid == false)
    }

    @Test("Localhost returns warning")
    func localhostReturnsWarning() throws {
        // Arrange
        let urlString = "http://localhost:8080"

        // Act
        let result = URLValidator.validate(urlString)

        // Assert
        #expect(result.isValid == true)
        if case .warning(_, let message) = result {
            #expect(message.contains("local"))
        }
    }

    // MARK: - isValidForScraping Tests

    @Test("Valid scraping URL returns true")
    func isValidForScrapingValid() throws {
        // Arrange
        let url = URL(string: "https://example.com")!

        // Act
        let result = URLValidator.isValidForScraping(url)

        // Assert
        #expect(result == true)
    }

    @Test("File URL returns false for scraping")
    func fileURLNotValidForScraping() throws {
        // Arrange
        let url = URL(string: "file:///tmp/test.html")!

        // Act
        let result = URLValidator.isValidForScraping(url)

        // Assert
        #expect(result == false)
    }

    // MARK: - Normalization Tests

    @Test("Normalize lowercases scheme and host")
    func normalizeLowercases() throws {
        // Arrange
        let url = URL(string: "HTTPS://WWW.EXAMPLE.COM/Page")!

        // Act
        let normalized = URLValidator.normalize(url)

        // Assert
        #expect(normalized.contains("https://"))
        #expect(normalized.contains("www.example.com") || normalized.contains("example.com"))
    }

    @Test("Normalize removes default HTTP port")
    func normalizeRemovesDefaultHttpPort() throws {
        // Arrange
        let url = URL(string: "http://example.com:80/path")!

        // Act
        let normalized = URLValidator.normalize(url)

        // Assert
        #expect(!normalized.contains(":80"))
    }

    @Test("Normalize removes default HTTPS port")
    func normalizeRemovesDefaultHttpsPort() throws {
        // Arrange
        let url = URL(string: "https://example.com:443/path")!

        // Act
        let normalized = URLValidator.normalize(url)

        // Assert
        #expect(!normalized.contains(":443"))
    }

    @Test("Normalize removes fragment")
    func normalizeRemovesFragment() throws {
        // Arrange
        let url = URL(string: "https://example.com/page#section")!

        // Act
        let normalized = URLValidator.normalize(url)

        // Assert
        #expect(!normalized.contains("#"))
    }

    @Test("Normalize removes trailing slash from path")
    func normalizeRemovesTrailingSlash() throws {
        // Arrange
        let url = URL(string: "https://example.com/path/")!

        // Act
        let normalized = URLValidator.normalize(url)

        // Assert
        #expect(!normalized.hasSuffix("/") || normalized == "https://example.com/")
    }

    // MARK: - Domain Extraction Tests

    @Test("Extract domain returns host")
    func extractDomain() throws {
        // Arrange
        let url = URL(string: "https://www.example.com/path")!

        // Act
        let domain = URLValidator.extractDomain(url)

        // Assert
        #expect(domain == "www.example.com")
    }

    @Test("Extract base domain returns last two parts")
    func extractBaseDomain() throws {
        // Arrange
        let url = URL(string: "https://blog.sub.example.com/page")!

        // Act
        let baseDomain = URLValidator.extractBaseDomain(url)

        // Assert
        #expect(baseDomain == "example.com")
    }

    @Test("Same domain URLs return true")
    func isSameDomainTrue() throws {
        // Arrange
        let url1 = URL(string: "https://example.com/page1")!
        let url2 = URL(string: "https://example.com/page2")!

        // Act
        let result = URLValidator.isSameDomain(url1, url2)

        // Assert
        #expect(result == true)
    }

    @Test("Different domain URLs return false")
    func isSameDomainFalse() throws {
        // Arrange
        let url1 = URL(string: "https://example.com")!
        let url2 = URL(string: "https://other.com")!

        // Act
        let result = URLValidator.isSameDomain(url1, url2)

        // Assert
        #expect(result == false)
    }

    @Test("Same base domain returns true")
    func isSameBaseDomainTrue() throws {
        // Arrange
        let url1 = URL(string: "https://www.example.com")!
        let url2 = URL(string: "https://api.example.com")!

        // Act
        let result = URLValidator.isSameBaseDomain(url1, url2)

        // Assert
        #expect(result == true)
    }

    // MARK: - URL Classification Tests

    @Test("PDF URL classified as pdf")
    func classifyPDF() throws {
        // Arrange
        let url = URL(string: "https://example.com/doc.pdf")!

        // Act
        let type = URLValidator.classifyURL(url)

        // Assert
        #expect(type == .pdf)
    }

    @Test("Image URL classified as image")
    func classifyImage() throws {
        // Arrange
        let url = URL(string: "https://example.com/photo.jpg")!

        // Act
        let type = URLValidator.classifyURL(url)

        // Assert
        #expect(type == .image)
    }

    @Test("JSON URL classified as data")
    func classifyJSON() throws {
        // Arrange
        let url = URL(string: "https://api.example.com/data.json")!

        // Act
        let type = URLValidator.classifyURL(url)

        // Assert
        #expect(type == .data)
    }

    @Test("HTML path classified as page")
    func classifyPage() throws {
        // Arrange
        let url = URL(string: "https://example.com/index.html")!

        // Act
        let type = URLValidator.classifyURL(url)

        // Assert
        #expect(type == .page)
    }
}
