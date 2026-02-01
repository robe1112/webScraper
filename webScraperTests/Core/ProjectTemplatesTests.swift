//
//  ProjectTemplatesTests.swift
//  webScraperTests
//
//  Unit tests for ProjectTemplates - verify templates are valid and usable
//  Follows Arrange-Act-Assert pattern per .cursor/rules
//

import Testing
import Foundation
@testable import webScraper

struct ProjectTemplatesTests {

    @Test("All templates have unique IDs")
    func uniqueTemplateIds() throws {
        // Arrange
        let templates = ProjectTemplates.all
        let ids = Set(templates.map { $0.id })

        // Assert
        #expect(ids.count == templates.count, "All template IDs should be unique")
    }

    @Test("All templates have valid settings")
    func validSettings() throws {
        // Arrange & Act
        for template in ProjectTemplates.all {
            let settings = template.settings

            // Assert
            #expect(settings.maxDepth > 0, "maxDepth must be positive for \(template.name)")
            #expect(settings.maxPages > 0, "maxPages must be positive for \(template.name)")
            #expect(settings.requestDelayMs >= 0, "requestDelayMs must be non-negative for \(template.name)")
            #expect(settings.maxConcurrentRequests > 0, "maxConcurrentRequests must be positive for \(template.name)")
        }
    }

    @Test("Create project from template produces valid project")
    func createProjectFromTemplate() throws {
        // Arrange
        let template = ProjectTemplates.basicWebsite
        let name = "Test Project"
        let startURL = "https://example.com"

        // Act
        let project = ProjectTemplates.createProject(from: template, name: name, startURL: startURL)

        // Assert
        #expect(project.name == name)
        #expect(project.startURL == startURL)
        #expect(project.settings.maxDepth == template.settings.maxDepth)
        #expect(project.settings.maxPages == template.settings.maxPages)
    }

    @Test("Templates for category returns filtered list")
    func templatesForCategory() throws {
        // Arrange
        let generalTemplates = ProjectTemplates.templates(for: .general)

        // Assert
        #expect(generalTemplates.allSatisfy { $0.category == .general })
        #expect(!generalTemplates.isEmpty)
    }

    @Test("Template by ID returns matching template")
    func templateById() throws {
        // Arrange
        let template = ProjectTemplates.basicWebsite

        // Act
        let found = ProjectTemplates.template(id: template.id)

        // Assert
        #expect(found?.id == template.id)
        #expect(found?.name == template.name)
    }

    @Test("Government template has document download enabled")
    func governmentTemplateHasDocumentSettings() throws {
        // Arrange
        let template = ProjectTemplates.governmentDocuments

        // Assert
        #expect(template.settings.downloadDocuments == true)
        #expect(template.settings.downloadPDFs == true)
        #expect(template.settings.requestDelayMs >= 2000)
    }
}
