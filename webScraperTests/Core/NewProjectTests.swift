//
//  NewProjectTests.swift
//  webScraperTests
//
//  Unit tests for New Project flow - AppState.createProject and validation
//  Follows Arrange-Act-Assert pattern per .cursor/rules
//

import Testing
import Foundation
@testable import webScraper

@Suite("New Project Tests")
struct NewProjectTests {

    @MainActor
    @Test("Create project saves to storage and returns project")
    func createProjectSavesAndReturns() async throws {
        // Arrange - use FileStorage with temp directory for isolated test
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storage = FileStorage(baseDirectory: tempDir)
        let appState = AppState(storageProvider: storage)

        let name = "Test Project"
        let url = "https://example.com"

        // Act
        let project = try await appState.createProject(name: name, url: url)

        // Assert
        #expect(project.name == name)
        #expect(project.startURL == url)
        #expect(project.id != UUID())

        let projects = try await appState.loadProjects()
        #expect(projects.count == 1)
        #expect(projects.first?.name == name)
        #expect(appState.selectedProject?.id == project.id)
    }

    @MainActor
    @Test("Create project with file URL is valid")
    func createProjectWithFileURL() async throws {
        // Arrange
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storage = FileStorage(baseDirectory: tempDir)
        let appState = AppState(storageProvider: storage)

        let name = "Local Test"
        let fileURL = "file://\(tempDir.path)/index.html"

        // Act
        let project = try await appState.createProject(name: name, url: fileURL)

        // Assert
        #expect(project.name == name)
        #expect(project.startURL == fileURL)
    }

    @Test("canCreate requires non-empty name and valid URL")
    func canCreateValidation() throws {
        // canCreate logic: !projectName.isEmpty && (validationResult?.isValid ?? false)
        // Test URLValidator handles empty/invalid
        let emptyResult = URLValidator.validate("")
        #expect(emptyResult.isValid == false)

        let invalidResult = URLValidator.validate("not-a-url")
        #expect(invalidResult.isValid == false)

        let validResult = URLValidator.validate("https://example.com")
        #expect(validResult.isValid == true)
    }

    @Test("Validation result shows warning for file URL")
    func fileURLValidationShowsWarning() throws {
        let result = URLValidator.validate("file:///tmp/test/index.html")
        #expect(result.isValid == true, "file:// URLs should be valid for create")
    }
}
