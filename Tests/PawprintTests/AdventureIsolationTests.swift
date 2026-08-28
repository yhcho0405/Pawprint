import AppKit
import XCTest
@testable import Pawprint

@MainActor
final class AdventureIsolationTests: XCTestCase {

    func testPawprintOwnProcessIsAlwaysExcludedFromTracking() {
        XCTAssertTrue(
            ActivityCenter.isOwnProcess(
                bundleID: "com.pawprint.app",
                runningBundleID: nil
            )
        )
        XCTAssertTrue(
            ActivityCenter.isOwnProcess(
                bundleID: "dev.pawprint.local",
                runningBundleID: "dev.pawprint.local"
            )
        )
        XCTAssertFalse(
            ActivityCenter.isOwnProcess(
                bundleID: "com.apple.dt.Xcode",
                runningBundleID: "dev.pawprint.local"
            )
        )
        XCTAssertTrue(
            ActivityCenter.shouldExclude(
                bundleID: "com.pawprint.app",
                runningBundleID: nil,
                isUserExcluded: false
            )
        )
        XCTAssertTrue(
            ActivityCenter.shouldExclude(
                bundleID: "example.private",
                runningBundleID: "dev.pawprint.local",
                isUserExcluded: true
            )
        )
        XCTAssertFalse(
            ActivityCenter.shouldExclude(
                bundleID: "com.apple.dt.Xcode",
                runningBundleID: "dev.pawprint.local",
                isUserExcluded: false
            )
        )
    }

    func testClosingAdventureWindowReleasesHostedContent() {
        let window = NSWindow()
        window.contentViewController = NSViewController()

        AdventureWindowController.releaseContent(
            from: Notification(
                name: NSWindow.willCloseNotification,
                object: window
            )
        )

        XCTAssertNil(window.contentViewController)
    }

    func testDockPolicyKeepsNormalWindowsReachable() {
        XCTAssertEqual(
            AppWindowActivationPolicy.desiredPolicy(
                wantsDockIcon: false,
                hasVisibleTitledWindow: true
            ),
            .regular
        )
        XCTAssertEqual(
            AppWindowActivationPolicy.desiredPolicy(
                wantsDockIcon: false,
                hasVisibleTitledWindow: false
            ),
            .accessory
        )
        XCTAssertEqual(
            AppWindowActivationPolicy.desiredPolicy(
                wantsDockIcon: true,
                hasVisibleTitledWindow: false
            ),
            .regular
        )
    }

    func testSwiftUISettingsSceneInjectsTheAppEnvironment() throws {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repository.appendingPathComponent(
                "Sources/Pawprint/App/PawprintApp.swift"
            ),
            encoding: .utf8
        )

        XCTAssertTrue(
            source.contains("SettingsRootView()\n                .pawprintEnvironment()"),
            "The system-owned Settings scene must inject ActivityCenter before restoration renders it"
        )
    }

    func testAdventurePreservesPawprintPopoverDimensions() throws {
        let source = try repositorySource(
            "Sources/Pawprint/UI/PopoverRootView.swift"
        )

        XCTAssertTrue(source.contains("?? 520"))
        XCTAssertTrue(source.contains(".frame(width: 380)"))
    }

    func testRPGDevelopmentBuildPreservesPawprintV010LinkedSDKAppearance() throws {
        let buildScript = try repositorySource("scripts/build_app.sh")
        let installer = try repositorySource("scripts/install_rpg_dev.sh")

        XCTAssertTrue(installer.contains("PAWPRINT_LEGACY_UI=1"))
        XCTAssertTrue(
            installer.contains("export DEVELOPER_DIR=\"/Library/Developer/CommandLineTools\"")
        )
        XCTAssertTrue(buildScript.contains("MacOSX15.4.sdk"))
        XCTAssertTrue(buildScript.contains("export SDKROOT=\"$LEGACY_UI_SDK\""))
        XCTAssertTrue(buildScript.contains("named(shouldNotifyObservers)"))
        XCTAssertTrue(buildScript.contains("xcrun vtool -show-build"))
        XCTAssertTrue(
            installer.contains("the development binary links SDK $linked_sdk, not 15.x"),
            "Installation must fail closed before an SDK-26-linked build can replace the app"
        )
    }

    func testAdventureRemainsReachableFromTheTopBarAndGallery() throws {
        let popoverSource = try repositorySource(
            "Sources/Pawprint/UI/PopoverRootView.swift"
        )
        let gallerySource = try repositorySource(
            "Sources/Pawprint/UI/PawpetGalleryView.swift"
        )

        XCTAssertTrue(
            popoverSource.contains("Image(systemName: \"map.fill\")"),
            "The top-bar map is the direct entry point to Adventure"
        )
        XCTAssertTrue(
            gallerySource.contains("browseButton(L10n.t(\"adventure.button\")"),
            "Removing the top-bar control must not make Adventure unreachable"
        )
    }

    func testAdventurePresentationHasNoPerpetualAnimation() throws {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let paths = [
            "Sources/Pawprint/UI/Adventure/AdventureBattleView.swift",
            "Sources/Pawprint/UI/Adventure/AdventureExpeditionHUDView.swift",
            "Sources/Pawprint/UI/Adventure/AdventureExpeditionDetailView.swift",
            "Sources/Pawprint/UI/Adventure/SunlitWispView.swift",
        ]

        for path in paths {
            let source = try String(
                contentsOf: repository.appendingPathComponent(path),
                encoding: .utf8
            )
            XCTAssertFalse(
                source.contains("repeatForever"),
                "\(path) must become idle while waiting for the next turn"
            )
        }
    }

    func testAdventureRouteSelectorsUseStablePullDownMenus() throws {
        let presentation = try repositorySource(
            "Sources/Pawprint/UI/Adventure/AdventureExpeditionPresentation.swift"
        )
        let root = try repositorySource(
            "Sources/Pawprint/UI/Adventure/AdventureRootView.swift"
        )
        let hud = try repositorySource(
            "Sources/Pawprint/UI/Adventure/AdventureExpeditionHUDView.swift"
        )

        XCTAssertTrue(presentation.contains("struct AdventureRouteMenu: View"))
        XCTAssertTrue(
            presentation.contains(
                "private var routeMenu: some View {\n        Menu {"
            )
        )
        XCTAssertFalse(presentation.contains(".pickerStyle(.menu)"))
        XCTAssertTrue(root.contains("AdventureRouteMenu("))
        XCTAssertTrue(hud.contains("AdventureRouteMenu("))
        XCTAssertFalse(
            root.contains(".pickerStyle(.menu)"),
            "A pop-up Picker repositions its menu around the selected route"
        )
        XCTAssertFalse(
            hud.contains(".pickerStyle(.menu)"),
            "The HUD route selector must use the same stable pull-down menu"
        )
    }

    func testSnapshotHarnessRequiresAnExplicitSeparateDatabase() throws {
        XCTAssertNil(try AdventureSnapshotHarness.configuration(environment: [:]))

        XCTAssertThrowsError(
            try AdventureSnapshotHarness.configuration(
                environment: ["PAWPRINT_ADVENTURE_SHOT": "/tmp/adventure.png"]
            )
        ) { error in
            XCTAssertEqual(error as? AdventureSnapshotHarnessError, .missingDatabase)
        }

        XCTAssertThrowsError(
            try AdventureSnapshotHarness.configuration(
                environment: [
                    "PAWPRINT_ADVENTURE_SHOT": "/tmp/adventure.sqlite3",
                    "PAWPRINT_DB": "/tmp/./adventure.sqlite3",
                ]
            )
        ) { error in
            XCTAssertEqual(error as? AdventureSnapshotHarnessError, .outputMatchesDatabase)
        }

        let environment = [
            "PAWPRINT_ADVENTURE_SHOT": "/tmp/adventure.png",
            "PAWPRINT_DB": "/tmp/adventure.sqlite3",
            "PAWPRINT_ADVENTURE_AUTORUN": "1",
        ]
        XCTAssertEqual(
            try AdventureSnapshotHarness.configuration(environment: environment),
            AdventureSnapshotConfiguration(
                outputPath: "/tmp/adventure.png",
                databasePath: "/tmp/adventure.sqlite3"
            )
        )
        XCTAssertTrue(AdventureSnapshotHarness.shouldAutorun(environment: environment))
        XCTAssertFalse(
            AdventureSnapshotHarness.shouldAutorun(
                environment: ["PAWPRINT_ADVENTURE_AUTORUN": "1"]
            )
        )
    }

    private func repositorySource(_ path: String) throws -> String {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: repository.appendingPathComponent(path),
            encoding: .utf8
        )
    }
}
