# webScraper Test Suite

Automated tests following `.cursor/rules/testing` guidelines.

## Structure

- **Core/URLValidatorTests.swift** – URL validation, normalization, domain extraction, classification
- **Core/SiteNodeTests.swift** – SiteNode.normalizeURL, NodeFileType.detect
- **Core/SiteMapBuilderTests.swift** – SiteMapBuilder actor (add nodes, stats, export)
- **Core/ProjectTemplatesTests.swift** – Project template validity and creation

## Conventions (per .cursor/rules)

- **@testable import** for internal API access
- **Arrange-Act-Assert** pattern in each test
- **Focused tests** – one behavior per test
- **Edge cases** – empty input, invalid data, boundary conditions
- **Positive & negative** – valid and invalid scenarios

## Running Tests

```bash
xcodebuild -scheme webScraper -destination 'platform=macOS' -only-testing:webScraperTests test
```

Or use ⌘U in Xcode.
