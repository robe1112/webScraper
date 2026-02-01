//
//  webScraperTests.swift
//  webScraperTests
//
//  Main test suite entry - see Core/ for unit tests
//  Follows .cursor/rules: @testable import, Arrange-Act-Assert, focused tests
//

import Testing
@testable import webScraper

struct webScraperTests {

    @Test("Test suite is properly configured")
    func testSuiteConfigured() throws {
        // Verify @testable import works and core types are accessible
        #expect(URLValidator.validate("https://example.com").isValid == true)
    }
}
