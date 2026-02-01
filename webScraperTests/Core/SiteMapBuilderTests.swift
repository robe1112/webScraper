//
//  SiteMapBuilderTests.swift
//  webScraperTests
//
//  Unit tests for SiteMapBuilder actor
//  Follows Arrange-Act-Assert pattern per .cursor/rules
//

import Testing
import Foundation
@testable import webScraper

@Suite("SiteMapBuilder Tests")
struct SiteMapBuilderTests {

    @Test("Add root node creates node and sets as root")
    func addRootNode() async throws {
        // Arrange
        let jobId = UUID()
        let builder = SiteMapBuilder(jobId: jobId)
        let url = URL(string: "https://example.com")!

        // Act
        let node = await builder.addNode(url: url, parentURL: nil, depth: 0, title: "Home")

        // Assert
        #expect(node.url == "https://example.com")
        #expect(node.depth == 0)
        #expect(node.parentId == nil)
        #expect(node.jobId == jobId)
        #expect(await builder.getRootNode()?.id == node.id)
    }

    @Test("Add child node links to parent")
    func addChildNode() async throws {
        // Arrange
        let jobId = UUID()
        let builder = SiteMapBuilder(jobId: jobId)
        let parentURL = URL(string: "https://example.com")!
        let childURL = URL(string: "https://example.com/about")!

        // Act
        _ = await builder.addNode(url: parentURL, parentURL: nil, depth: 0)
        let childNode = await builder.addNode(url: childURL, parentURL: parentURL, depth: 1, title: "About")

        // Assert
        #expect(childNode.depth == 1)
        #expect(childNode.parentId != nil)
        let children = await builder.getChildren(of: (await builder.getRootNode()!).id)
        #expect(children.contains { $0.id == childNode.id })
    }

    @Test("Stats reflect added nodes")
    func statsReflectNodes() async throws {
        // Arrange
        let jobId = UUID()
        let builder = SiteMapBuilder(jobId: jobId)
        let urls = [
            URL(string: "https://example.com")!,
            URL(string: "https://example.com/page1")!,
            URL(string: "https://example.com/image.jpg")!
        ]

        // Act
        _ = await builder.addNode(url: urls[0], parentURL: nil, depth: 0, statusCode: 200)
        _ = await builder.addNode(url: urls[1], parentURL: urls[0], depth: 1, statusCode: 200)
        _ = await builder.addNode(url: urls[2], parentURL: urls[0], depth: 1, contentType: "image/jpeg")
        let stats = await builder.getStats()

        // Assert
        #expect(stats.totalNodes == 3)
        #expect(stats.totalPages >= 2)
        #expect(stats.maxDepth == 1)
    }

    @Test("Mark node failed updates status")
    func markNodeFailed() async throws {
        // Arrange
        let jobId = UUID()
        let builder = SiteMapBuilder(jobId: jobId)
        let url = URL(string: "https://example.com/failed")!
        _ = await builder.addNode(url: url, parentURL: nil, depth: 0)

        // Act
        await builder.markNodeFailed(url: url, statusCode: 404)
        let node = await builder.getNode(url: url)

        // Assert
        #expect(node?.nodeStatus == .failed)
        #expect(node?.statusCode == 404)
    }

    @Test("Mark node blocked updates status")
    func markNodeBlocked() async throws {
        // Arrange
        let jobId = UUID()
        let builder = SiteMapBuilder(jobId: jobId)
        let url = URL(string: "https://example.com/blocked")!
        _ = await builder.addNode(url: url, parentURL: nil, depth: 0)

        // Act
        await builder.markNodeBlocked(url: url)
        let node = await builder.getNode(url: url)

        // Assert
        #expect(node?.nodeStatus == .blocked)
    }

    @Test("Add duplicate URL updates existing node")
    func addDuplicateUpdatesNode() async throws {
        // Arrange
        let jobId = UUID()
        let builder = SiteMapBuilder(jobId: jobId)
        let url = URL(string: "https://example.com/page")!
        _ = await builder.addNode(url: url, parentURL: nil, depth: 0, title: "Original")

        // Act
        let updatedNode = await builder.addNode(url: url, parentURL: nil, depth: 0, title: "Updated", statusCode: 200)
        let allNodes = await builder.getAllNodes()

        // Assert
        #expect(updatedNode.title == "Updated")
        #expect(updatedNode.statusCode == 200)
        #expect(allNodes.count == 1)
    }

    @Test("Clear removes all nodes")
    func clearRemovesAll() async throws {
        // Arrange
        let jobId = UUID()
        let builder = SiteMapBuilder(jobId: jobId)
        _ = await builder.addNode(url: URL(string: "https://example.com")!, parentURL: nil, depth: 0)

        // Act
        await builder.clear()
        let nodes = await builder.getAllNodes()
        let root = await builder.getRootNode()

        // Assert
        #expect(nodes.isEmpty)
        #expect(root == nil)
    }

    @Test("Export JSON produces valid data")
    func exportJSON() async throws {
        // Arrange
        let jobId = UUID()
        let builder = SiteMapBuilder(jobId: jobId)
        _ = await builder.addNode(url: URL(string: "https://example.com")!, parentURL: nil, depth: 0, statusCode: 200)

        // Act
        let jsonData = try await builder.exportAsJSON()
        let export = try JSONDecoder().decode(SiteMapExport.self, from: jsonData)

        // Assert
        #expect(export.nodes.count == 1)
        #expect(export.generatedAt <= Date())
        #expect(export.stats.totalNodes == 1)
    }
}
