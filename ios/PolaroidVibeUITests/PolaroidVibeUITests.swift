import XCTest
import UIKit

final class PolaroidVibeUITests: XCTestCase {
    func testSamplePresetSaveGalleryDetailAndRelaunch() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-camera-mock"]; app.launch()
        XCTAssertTrue(app.buttons["shutter"].waitForExistence(timeout: 10))
        attach(app, name: "01-camera")
        app.buttons["shutter"].tap()
        let save = app.buttons["savePhoto"]
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        waitUntilEnabled(save)
        for name in ["instant669", "px70", "timeZero", "sx70"] {
            if name == "timeZero" || name == "sx70" {
                let strip = app.scrollViews.allElementsBoundByIndex.last!
                if name == "sx70" { strip.swipeRight() }
                else { strip.swipeLeft() }
            }
            let button = app.buttons.matching(identifier: "preset_\(name)").allElementsBoundByIndex.last!
            button.tap()
            waitUntilEnabled(save)
        }
        app.sliders["Chất film"].adjust(toNormalizedSliderPosition: 0)
        waitUntilEnabled(save)
        app.buttons["compareOriginal"].tap()
        XCTAssertTrue(app.buttons["Đang xem ảnh gốc"].exists || app.staticTexts["Đang xem ảnh gốc"].exists)
        app.buttons["compareOriginal"].tap()
        attach(app, name: "02-preview")
        save.tap()
        let photo = app.buttons["Ảnh Soft"]
        XCTAssertTrue(photo.waitForExistence(timeout: 10))
        attach(app, name: "03-gallery")
        photo.firstMatch.tap()
        XCTAssertTrue(app.buttons["sharePhoto"].waitForExistence(timeout: 5))
        attach(app, name: "04-detail")
        app.terminate()
        app.launchArguments = ["-camera-mock"]; app.launch()
        app.buttons["cameraBack"].tap()
        XCTAssertTrue(app.buttons["Ảnh Soft"].firstMatch.waitForExistence(timeout: 8), "Saved photo should survive relaunch")
    }
    func testCameraControlsAndRatioTransaction() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-camera-mock"]
        app.launch()
        let finder = app.otherElements["cameraViewfinder"].firstMatch
        XCTAssertTrue(app.buttons["shutter"].waitForExistence(timeout: 10))
        attach(app, name: "camera-square")
        app.buttons["toggleFlash"].tap()
        XCTAssertEqual(app.buttons["toggleFlash"].value as? String, "Bật")
        app.buttons["toggleGrid"].tap()
        XCTAssertEqual(app.buttons["toggleGrid"].value as? String, "Bật")
        attach(app, name: "camera-flash-grid")
        app.buttons["toggleZoom"].tap()
        XCTAssertEqual(app.buttons["toggleZoom"].value as? String, "2x")
        app.buttons["chooseRatio"].tap()
        XCTAssertTrue(app.buttons["ratio_portrait"].waitForExistence(timeout: 5))
        app.buttons["ratio_portrait"].tap()
        attach(app, name: "camera-portrait")
        XCTAssertGreaterThan(finder.frame.height, finder.frame.width)
        app.buttons["cancelRatio"].tap()
        XCTAssertTrue(app.buttons["shutter"].waitForExistence(timeout: 3))
        XCTAssertEqual(finder.frame.width, finder.frame.height, accuracy: 1)
        app.buttons["chooseRatio"].tap()
        app.buttons["ratio_landscape"].tap()
        attach(app, name: "camera-landscape")
        app.buttons["confirmRatio"].tap()
        XCTAssertTrue(app.buttons["shutter"].waitForExistence(timeout: 3))
        XCTAssertEqual(finder.frame.width / finder.frame.height, 99.0 / 62, accuracy: 0.02)
        app.buttons["choosePreset"].tap()
        attach(app, name: "camera-presets")
        app.buttons["preset_sx70"].firstMatch.tap()
        app.buttons["choosePreset"].tap()
        app.buttons["shutter"].tap()
        XCTAssertTrue(app.buttons["savePhoto"].waitForExistence(timeout: 10))
        waitUntilEnabled(app.buttons["savePhoto"])
    }
    func testPresetPreviewChangesAndKeepsShutterGapForAllRatios() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-camera-sample"]; app.launch()
        let finder = app.otherElements["cameraViewfinder"].firstMatch
        XCTAssertTrue(app.buttons["shutter"].waitForExistence(timeout: 10))
        for ratio in ["portrait", "square", "landscape"] {
            app.buttons["chooseRatio"].tap()
            app.buttons["ratio_\(ratio)"].tap()
            app.buttons["confirmRatio"].tap()
            app.buttons["choosePreset"].tap()
            // Wait for the layout animation to finish before measuring actual bounds.
            let gap = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                app.buttons["shutter"].frame.minY - finder.frame.maxY >= 31.9
                    && finder.frame.minY - app.buttons["cameraBack"].frame.maxY >= 19.9
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [gap], timeout: 5), .completed)
            let topGap = finder.frame.minY - app.buttons["cameraBack"].frame.maxY
            let bottomGap = app.buttons["shutter"].frame.minY - finder.frame.maxY
            print("Preset layout \(ratio): toolbar gap=\(topGap), shutter gap=\(bottomGap), finder=\(finder.frame)")
            XCTAssertGreaterThanOrEqual(finder.frame.minX, 19.9)
            XCTAssertGreaterThanOrEqual(app.frame.maxX - finder.frame.maxX, 19.9)
            if ratio == "portrait" {
                XCTAssertEqual(topGap, 20, accuracy: 1)
                XCTAssertEqual(bottomGap, 32, accuracy: 1)
            }
            attach(app, name: "preset-spacing-\(ratio)")
            if ratio == "portrait" {
                attach(app, name: "preset-soft-layers")
                var previous: Data?
                for (id, title) in [("sx70", "Soft"), ("px70", "Sunny"), ("timeZero", "Old Days"), ("instant669", "Clear")] {
                    let button = app.buttons["preset_\(id)"].firstMatch
                    if !button.isHittable { app.scrollViews.firstMatch.swipeLeft() }
                    button.tap()
                    let rendered = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", title), object: finder)
                    XCTAssertEqual(XCTWaiter.wait(for: [rendered], timeout: 10), .completed)
                    let screenshot = app.screenshot().image
                    let scale = screenshot.size.width / app.frame.width
                    let rect = finder.frame.insetBy(dx: 40, dy: 40)
                    let crop = screenshot.cgImage!.cropping(to: CGRect(x: rect.minX * scale, y: rect.minY * scale, width: rect.width * scale, height: rect.height * scale))!
                    let pixels = UIImage(cgImage: crop).pngData()!
                    if let previous { XCTAssertNotEqual(previous, pixels, "Preset must change pixels inside the camera frame") }
                    previous = pixels
                }
                attach(app, name: "portrait-live-preset-gap")
            }
            app.buttons["choosePreset"].tap()
        }
    }
    private func waitUntilEnabled(_ element: XCUIElement) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 20), .completed)
    }
    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
