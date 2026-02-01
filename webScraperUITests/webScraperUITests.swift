//
//  webScraperUITests.swift
//  webScraperUITests
//
//  Created by Rob Evans on 1/31/26.
//

import XCTest

final class webScraperUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        let app = XCUIApplication()
        app.launch()
    }

    @MainActor
    func testNewProjectWindowFlow() throws {
        let app = XCUIApplication()
        app.launch()

        let newProjectButton = app.buttons["newProjectButton"].firstMatch
        XCTAssertTrue(newProjectButton.waitForExistence(timeout: 5))
        newProjectButton.tap()

        let createButton = app.buttons["createButton"].firstMatch
        XCTAssertTrue(createButton.waitForExistence(timeout: 2))
        XCTAssertFalse(createButton.isEnabled, "Create should be disabled with empty form")

        let nameField = app.textFields["projectNameField"].firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText("UI Test Project")

        let urlField = app.textFields["startURLField"].firstMatch
        XCTAssertTrue(urlField.waitForExistence(timeout: 2))
        urlField.tap()
        urlField.typeText("https://example.com")

        XCTAssertTrue(createButton.waitForExistence(timeout: 2))
        if createButton.isEnabled {
            createButton.tap()
        } else {
            XCTFail("Create button should be enabled after entering valid name and URL")
        }

        // Sheet should dismiss (newProjectButton visible again)
        XCTAssertTrue(newProjectButton.waitForExistence(timeout: 3))

        // Verify no error alert appeared (create succeeded)
        let errorAlert = app.alerts["Create Failed"]
        XCTAssertFalse(errorAlert.exists, "Create should succeed without error")
    }

    @MainActor
    func testNewProjectCancelDismissesSheet() throws {
        let app = XCUIApplication()
        app.launch()

        let newProjectButton = app.buttons["newProjectButton"].firstMatch
        XCTAssertTrue(newProjectButton.waitForExistence(timeout: 5))
        newProjectButton.tap()

        let cancelButton = app.buttons["cancelButton"].firstMatch
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 2))
        cancelButton.tap()

        XCTAssertTrue(newProjectButton.waitForExistence(timeout: 2))
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
