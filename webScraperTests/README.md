# webScraper Test Suite

Automated tests following `.cursor/rules/testing` guidelines.

## Structure

- **Core/GlobalSettingsTests.swift** – GlobalSettings persistence and defaults, FeatureFlags behavior
- **Core/NewProjectTests.swift** – New Project flow (createProject, validation)
- **Core/URLValidatorTests.swift** – URL validation, normalization, domain extraction, classification
- **Core/SiteNodeTests.swift** – SiteNode.normalizeURL, NodeFileType.detect
- **Core/SiteMapBuilderTests.swift** – SiteMapBuilder actor (add nodes, stats, export)
- **Core/ProjectTemplatesTests.swift** – Project template validity and creation
- **Core/TestSiteIntegrationTests.swift** – Integration tests using the TestSite fixture
- **Core/TestSiteFixtures.swift** – Embedded HTML fixtures (test website)
- **Resources/TestSite/** – Standalone HTML files (mirror of embedded fixtures)

## Test Website (TestSite)

A fixture website for integration testing. Includes:

- **index.html** – Homepage with nav links, sections, images
- **about.html**, **contact.html** – Static pages
- **blog.html** – Blog index with article links
- **blog-article-1.html**, **blog-article-2.html** – Articles with metadata (author, date, category) for News template extraction
- **products.html** – Product listings for E-commerce template extraction
- **api-data.json** – JSON for API/JSON Path tests

Fixtures are embedded in `TestSiteFixtures.swift` for reliable loading. The HTML files in `Resources/TestSite/` mirror this structure for reference.

## Conventions (per .cursor/rules)

- **@testable import** for internal API access
- **Arrange-Act-Assert** pattern in each test
- **Focused tests** – one behavior per test
- **Edge cases** – empty input, invalid data, boundary conditions
- **Positive & negative** – valid and invalid scenarios

## Running Tests

**Unit tests:**
```bash
xcodebuild -scheme webScraper -destination 'platform=macOS' -only-testing:webScraperTests test
```

**UI tests (New Project window):**
```bash
xcodebuild -scheme webScraper -destination 'platform=macOS' -only-testing:webScraperUITests test
```

Or use ⌘U in Xcode.
