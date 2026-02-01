//
//  CoreDataStorage.swift
//  webScraper
//
//  Created by Rob Evans on 1/31/26.
//

import Foundation
@preconcurrency import CoreData

/// Core Data implementation of StorageProvider
/// Best for complex queries and relationships
@MainActor
final class CoreDataStorage: StorageProvider {
    
    // MARK: - Properties
    
    private let container: NSPersistentContainer
    private let context: NSManagedObjectContext
    
    // Type name to entity name mapping
    private let entityNames: [String: String] = [
        "Project": "ProjectEntity",
        "ScrapeJob": "ScrapeJobEntity",
        "ScrapedPage": "ScrapedPageEntity",
        "DownloadedFile": "DownloadedFileEntity",
        "SiteNode": "SiteNodeEntity",
        "ExtractionRule": "ExtractionRuleEntity"
    ]
    
    // MARK: - Initialization
    
    init(containerName: String = "webScraper") {
        let model = CoreDataStorage.makeManagedObjectModel()
        container = NSPersistentContainer(name: containerName, managedObjectModel: model)
        
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Failed to load Core Data: \(error)")
            }
        }
        
        context = container.viewContext
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    /// Creates the Core Data model programmatically (avoids needing a .xcdatamodeld file)
    private static func makeManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        let entityNames = [
            "ProjectEntity", "ScrapeJobEntity", "ScrapedPageEntity",
            "DownloadedFileEntity", "SiteNodeEntity", "ExtractionRuleEntity"
        ]
        
        for entityName in entityNames {
            let entity = NSEntityDescription()
            entity.name = entityName
            entity.managedObjectClassName = "NSManagedObject"
            
            let idAttr = NSAttributeDescription()
            idAttr.name = "id"
            idAttr.attributeType = .stringAttributeType
            idAttr.isOptional = false
            
            let jsonAttr = NSAttributeDescription()
            jsonAttr.name = "jsonData"
            jsonAttr.attributeType = .stringAttributeType
            jsonAttr.isOptional = false
            
            let createdAttr = NSAttributeDescription()
            createdAttr.name = "createdAt"
            createdAttr.attributeType = .dateAttributeType
            createdAttr.isOptional = false
            createdAttr.defaultValue = Date()
            
            let updatedAttr = NSAttributeDescription()
            updatedAttr.name = "updatedAt"
            updatedAttr.attributeType = .dateAttributeType
            updatedAttr.isOptional = false
            updatedAttr.defaultValue = Date()
            
            entity.properties = [idAttr, jsonAttr, createdAttr, updatedAttr]
            model.entities.append(entity)
        }
        
        return model
    }
    
    // MARK: - StorageProvider Implementation
    
    func save<T: Codable & Identifiable>(_ item: T) async throws {
        let entityName = self.entityName(for: T.self)
        try await context.perform {
            let data = try JSONEncoder().encode(item)
            
            // Check if item exists
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
            fetchRequest.predicate = NSPredicate(format: "id == %@", "\(item.id)")
            
            let results = try self.context.fetch(fetchRequest)
            
            let entity: NSManagedObject
            let now = Date()
            if let existing = results.first {
                entity = existing
            } else {
                guard let entityDescription = NSEntityDescription.entity(forEntityName: entityName, in: self.context) else {
                    throw StorageError.unsupportedType
                }
                entity = NSManagedObject(entity: entityDescription, insertInto: self.context)
                entity.setValue(now, forKey: "createdAt")
            }
            
            entity.setValue(String(data: data, encoding: .utf8), forKey: "jsonData")
            entity.setValue("\(item.id)", forKey: "id")
            entity.setValue(now, forKey: "updatedAt")
            
            try self.context.save()
        }
    }
    
    func fetch<T: Codable & Identifiable>(predicate: NSPredicate?) async throws -> [T] {
        let entityName = self.entityName(for: T.self)
        return try await context.perform {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
            fetchRequest.predicate = predicate
            
            let results = try self.context.fetch(fetchRequest)
            
            var items: [T] = []
            for entity in results {
                guard let jsonString = entity.value(forKey: "jsonData") as? String,
                      let data = jsonString.data(using: .utf8) else { continue }
                items.append(try JSONDecoder().decode(T.self, from: data))
            }
            return items
        }
    }
    
    func fetchById<T: Codable & Identifiable>(_ id: T.ID, type: T.Type) async throws -> T? {
        let entityName = self.entityName(for: T.self)
        return try await context.perform {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
            fetchRequest.predicate = NSPredicate(format: "id == %@", "\(id)")
            fetchRequest.fetchLimit = 1
            
            guard let entity = try self.context.fetch(fetchRequest).first,
                  let jsonString = entity.value(forKey: "jsonData") as? String,
                  let data = jsonString.data(using: .utf8) else {
                return nil as T?
            }
            
            return try JSONDecoder().decode(T.self, from: data)
        }
    }
    
    func delete<T: Codable & Identifiable>(_ item: T) async throws {
        let entityName = self.entityName(for: T.self)
        try await context.perform {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
            fetchRequest.predicate = NSPredicate(format: "id == %@", "\(item.id)")
            
            let results = try self.context.fetch(fetchRequest)
            for entity in results {
                self.context.delete(entity)
            }
            
            try self.context.save()
        }
    }
    
    func deleteWhere<T: Codable & Identifiable>(type: T.Type, predicate: NSPredicate) async throws {
        let entityName = self.entityName(for: T.self)
        try await context.perform {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
            fetchRequest.predicate = predicate
            
            let results = try self.context.fetch(fetchRequest)
            for entity in results {
                self.context.delete(entity)
            }
            
            try self.context.save()
        }
    }
    
    func update<T: Codable & Identifiable>(_ item: T) async throws {
        try await save(item)
    }
    
    func count<T: Codable & Identifiable>(type: T.Type, predicate: NSPredicate?) async throws -> Int {
        let entityName = self.entityName(for: T.self)
        return try await context.perform {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
            fetchRequest.predicate = predicate
            return try self.context.count(for: fetchRequest)
        }
    }
    
    func observe<T: Codable & Identifiable>(type: T.Type, predicate: NSPredicate?) -> AsyncStream<[T]> {
        AsyncStream { continuation in
            Task {
                // Initial fetch
                do {
                    let items: [T] = try await self.fetch(predicate: predicate)
                    continuation.yield(items)
                } catch {
                    // Continue without yielding on error
                }
                
                // Set up notification observer for changes
                let notificationCenter = NotificationCenter.default
                let notification = notificationCenter.addObserver(
                    forName: .NSManagedObjectContextDidSave,
                    object: self.context,
                    queue: nil
                ) { [weak self] _ in
                    Task {
                        do {
                            let items: [T] = try await self?.fetch(predicate: predicate) ?? []
                            continuation.yield(items)
                        } catch {
                            // Continue on error
                        }
                    }
                }
                
                continuation.onTermination = { _ in
                    notificationCenter.removeObserver(notification)
                }
            }
        }
    }
    
    func clearAll() async throws {
        try await context.perform {
            for entityName in self.entityNames.values {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                try self.context.execute(deleteRequest)
            }
            try self.context.save()
        }
    }
    
    func export(to url: URL) async throws {
        // Export all data as JSON
        var exportData: [String: Any] = [:]
        
        for (typeName, entityName) in entityNames {
            try await context.perform {
                let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
                let results = try self.context.fetch(fetchRequest)
                
                let jsonStrings = results.compactMap { entity -> String? in
                    entity.value(forKey: "jsonData") as? String
                }
                
                exportData[typeName] = jsonStrings
            }
        }
        
        let data = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
        try data.write(to: url)
    }
    
    func `import`(from url: URL) async throws {
        let data = try Data(contentsOf: url)
        guard let importData = try JSONSerialization.jsonObject(with: data) as? [String: [String]] else {
            throw StorageError.invalidData
        }
        
        for (typeName, jsonStrings) in importData {
            guard let entityName = entityNames[typeName] else { continue }
            
            try await context.perform {
                for jsonString in jsonStrings {
                    guard let entityDescription = NSEntityDescription.entity(forEntityName: entityName, in: self.context) else {
                        continue
                    }
                    
                    let entity = NSManagedObject(entity: entityDescription, insertInto: self.context)
                    let now = Date()
                    entity.setValue(jsonString, forKey: "jsonData")
                    entity.setValue(now, forKey: "createdAt")
                    entity.setValue(now, forKey: "updatedAt")
                    
                    // Extract ID from JSON
                    if let jsonData = jsonString.data(using: .utf8),
                       let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                       let id = dict["id"] {
                        entity.setValue("\(id)", forKey: "id")
                    }
                }
                
                try self.context.save()
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func entityName<T>(for type: T.Type) -> String {
        let typeName = String(describing: type)
        return entityNames[typeName] ?? "\(typeName)Entity"
    }
}
