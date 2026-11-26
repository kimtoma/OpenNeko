import XCTest
@testable import OpenNekoKit

final class LocalModelSetupFlowTests: XCTestCase {
    private func reduce(_ step: LocalModelSetupStep, _ events: LocalModelSetupEvent...) -> LocalModelSetupStep {
        events.reduce(step) { LocalModelSetupFlow.reduce($0, $1) }
    }

    func testRunningOllamaGoesStraightToReady() {
        XCTAssertEqual(reduce(.checking, .ollamaProbed(running: true, appInstalled: true)), .ready)
    }

    func testMissingOllamaAsksForInstallThenWaits() {
        let needs = reduce(.checking, .ollamaProbed(running: false, appInstalled: false))
        XCTAssertEqual(needs, .needsOllama)
        XCTAssertTrue(needs.pollsForOllama)

        let waiting = reduce(needs, .openedOllamaDownload)
        XCTAssertEqual(waiting, .waitingForOllama)
        // A failed poll keeps waiting instead of bouncing back to the install prompt.
        XCTAssertEqual(reduce(waiting, .ollamaProbed(running: false, appInstalled: false)), .waitingForOllama)
        XCTAssertEqual(reduce(waiting, .ollamaProbed(running: true, appInstalled: true)), .ready)
    }

    func testInstalledButStoppedOllamaWaits() {
        XCTAssertEqual(reduce(.checking, .ollamaProbed(running: false, appInstalled: true)), .waitingForOllama)
    }

    func testDownloadProgressThenWarmUpThenDone() {
        var tracker = OllamaPullTracker()
        tracker.consume(line: #"{"status":"pulling a","digest":"sha256:a","total":4,"completed":1}"#)

        let downloading = reduce(.ready, .startDownload, .pullProgress(tracker))
        XCTAssertEqual(downloading, .downloading(fraction: 0.25))

        tracker.consume(line: #"{"status":"success"}"#)
        let warming = reduce(downloading, .pullProgress(tracker))
        XCTAssertEqual(warming, .warmingUp)
        XCTAssertEqual(reduce(warming, .warmUpFinished(succeeded: true, message: nil)), .done)
    }

    func testAlreadyInstalledModelSkipsDownload() {
        XCTAssertEqual(reduce(.ready, .modelAlreadyInstalled), .warmingUp)
    }

    func testPullErrorFailsAndRetryRestartsChecks() {
        var tracker = OllamaPullTracker()
        tracker.consume(line: #"{"error":"no space left on device"}"#)
        let failed = reduce(.ready, .startDownload, .pullProgress(tracker))
        XCTAssertEqual(failed, .failed("no space left on device"))
        XCTAssertEqual(reduce(failed, .retry), .checking)
    }

    func testTransportFailureDuringDownloadFails() {
        XCTAssertEqual(reduce(.ready, .startDownload, .pullFailed("offline")), .failed("offline"))
    }

    func testWarmUpFailureKeepsMessage() {
        XCTAssertEqual(reduce(.warmingUp, .warmUpFinished(succeeded: false, message: "timeout")), .failed("timeout"))
    }

    func testIgnoresEventsThatDoNotApply() {
        XCTAssertEqual(reduce(.checking, .startDownload), .checking)
        XCTAssertEqual(reduce(.done, .ollamaProbed(running: true, appInstalled: true)), .done)
        XCTAssertEqual(reduce(.ready, .pullFailed("x")), .ready)
        XCTAssertEqual(reduce(.ready, .retry), .ready)
        XCTAssertFalse(LocalModelSetupStep.ready.pollsForOllama)
    }

    func testUnsupportedIsTerminalFromAnyStep() {
        XCTAssertEqual(reduce(.checking, .unsupported(.notAppleSilicon)), .unsupported(.notAppleSilicon))
    }

    func testProviderConfigUsesOllamaPresetWithChosenModel() {
        let config = LocalModelSetupFlow.providerConfig(modelID: "gemma4:e2b")
        XCTAssertEqual(config.presetID, "ollama")
        XCTAssertEqual(config.type, .openAICompatible)
        XCTAssertEqual(config.baseURL, "http://localhost:11434/v1")
        XCTAssertEqual(config.model, "gemma4:e2b")
    }

    func testIsInstalledNormalizesLatestTagAndCase() {
        XCTAssertTrue(LocalModelSetupFlow.isInstalled("gemma4:e2b", installedModels: ["qwen3:8b", "gemma4:e2b"]))
        XCTAssertTrue(LocalModelSetupFlow.isInstalled("llama3", installedModels: ["llama3:latest"]))
        XCTAssertTrue(LocalModelSetupFlow.isInstalled("Gemma4:E2B", installedModels: ["gemma4:e2b"]))
        XCTAssertFalse(LocalModelSetupFlow.isInstalled("gemma4:e4b", installedModels: ["gemma4:e2b"]))
    }
}
