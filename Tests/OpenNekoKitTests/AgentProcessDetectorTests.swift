import XCTest
@testable import OpenNekoKit

final class AgentProcessDetectorTests: XCTestCase {
    func testDetectsKnownAgentProcessesAndKeepsMaxCPU() {
        let ps = """
          0.0 /Applications/Cursor.app/Contents/MacOS/Cursor
          3.4 /Users/me/.npm/_npx/123/node_modules/.bin/codex exec
          1.2 Codex Helper
          6.7 /opt/homebrew/bin/claude -p hello
          0.2 /opt/homebrew/bin/claude idle
        """

        let activities = AgentProcessDetector.detect(psOutput: ps)

        XCTAssertEqual(activities.first?.source, "claude")
        XCTAssertEqual(activities.first?.cpu, 6.7)
        XCTAssertTrue(activities.contains(AgentProcessActivity(source: "cursor", label: "Cursor", cpu: 0.0)))
        XCTAssertTrue(activities.contains(AgentProcessActivity(source: "codex-cli", label: "Codex CLI", cpu: 3.4)))
        XCTAssertTrue(activities.contains(AgentProcessActivity(source: "codex-app", label: "Codex App", cpu: 1.2)))
    }

    func testCodexCLIAndCodexAppAreSeparate() {
        let ps = """
          4.2 /opt/homebrew/bin/codex exec
          0.8 /Applications/Codex.app/Contents/MacOS/Codex
          3.6 /Applications/Codex.app/Contents/Resources/codex app-server --analytics-default-enabled
        """

        let activities = AgentProcessDetector.detect(psOutput: ps)

        XCTAssertEqual(activities.first { $0.source == "codex-cli" }?.cpu, 4.2)
        XCTAssertEqual(activities.first { $0.source == "codex-app" }?.cpu, 0.8)
        XCTAssertEqual(activities.first { $0.source == "codex-app-agent" }?.cpu, 3.6)
        XCTAssertEqual(
            AgentProcessDetector.topBusyActivity(in: activities),
            AgentProcessActivity(source: "codex-cli", label: "Codex CLI", cpu: 4.2)
        )
    }

    func testCodexAppGUIActivityDoesNotBecomeBusyByItself() {
        let activities = [
            AgentProcessActivity(source: "codex-app", label: "Codex App", cpu: 24.0),
            AgentProcessActivity(source: "claude", label: "Claude", cpu: 0.6),
        ]

        XCTAssertNil(AgentProcessDetector.topBusyActivity(in: activities))
    }

    func testCodexAppServerCanBecomeBusy() {
        let ps = """
          0.0 /Applications/Codex.app/Contents/MacOS/Codex
          8.4 /Applications/Codex.app/Contents/Resources/codex app-server --analytics-default-enabled
        """

        let activities = AgentProcessDetector.detect(psOutput: ps)

        XCTAssertEqual(
            AgentProcessDetector.topBusyActivity(in: activities),
            AgentProcessActivity(source: "codex-app-agent", label: "Codex App", cpu: 8.4)
        )
    }

    func testCodexCLICanStillBecomeBusy() {
        let activities = [
            AgentProcessActivity(source: "codex-app", label: "Codex App", cpu: 24.0),
            AgentProcessActivity(source: "codex-cli", label: "Codex CLI", cpu: 2.6),
        ]

        XCTAssertEqual(
            AgentProcessDetector.topBusyActivity(in: activities),
            AgentProcessActivity(source: "codex-cli", label: "Codex CLI", cpu: 2.6)
        )
    }

    func testIgnoresCodexAppRendererAndGPUHelperNoise() {
        let ps = """
          17.9 /Applications/Codex.app/Contents/Frameworks/Codex Framework.framework/Versions/1/Helpers/Codex (Service).app/Contents/MacOS/Codex (Service) --type=gpu-process
           7.8 /Applications/Codex.app/Contents/Frameworks/Codex Framework.framework/Versions/1/Helpers/Codex (Renderer).app/Contents/MacOS/Codex (Renderer) --type=renderer
           3.2 /Applications/Codex.app/Contents/Frameworks/Codex Framework.framework/Versions/1/Helpers/browser_crashpad_handler
          0.0 /Applications/Codex.app/Contents/MacOS/Codex
        """

        let activities = AgentProcessDetector.detect(psOutput: ps)

        XCTAssertEqual(activities.first { $0.source == "codex-app" }?.cpu, 0.0)
        XCTAssertNil(AgentProcessDetector.topBusyActivity(in: activities))
    }

    func testDoesNotTreatCodexComputerUseAsCodexApp() {
        let ps = """
          12.0 /Users/me/.codex/computer-use/Codex Computer Use.app/Contents/MacOS/SkyComputerUseService
           2.0 ./Codex Computer Use.app/Contents/SharedSupport/SkyComputerUseClient.app/Contents/MacOS/SkyComputerUseClient mcp
        """

        let activities = AgentProcessDetector.detect(psOutput: ps)

        XCTAssertFalse(activities.contains { $0.source == "codex-app" })
        XCTAssertNil(AgentProcessDetector.topBusyActivity(in: activities))
    }

    func testIgnoresPassiveClaudeBackgroundSessions() {
        let ps = """
          18.0 /Applications/CodexBar.app/Contents/Helpers/CodexBarClaudeWatchdog -- /Users/me/.local/bin/claude --allowed-tools
          16.3 /Users/me/.local/bin/claude --allowed-tools
           8.4 /Users/me/.local/bin/claude --resume 29de09cb-e5fa --dangerously-skip-permissions
           5.1 /Users/me/.local/bin/claude --settings {"hooks":{}} --session-id c50887bb-eefd
           3.2 /Users/me/.local/bin/claude -p hello
        """

        let activities = AgentProcessDetector.detect(psOutput: ps)

        XCTAssertEqual(activities, [
            AgentProcessActivity(source: "claude", label: "Claude", cpu: 3.2),
        ])
        XCTAssertEqual(
            AgentProcessDetector.topBusyActivity(in: activities),
            AgentProcessActivity(source: "claude", label: "Claude", cpu: 3.2)
        )
    }

    func testDefaultBusyThresholdIgnoresLowCPUBackgroundNoise() {
        let activities = [
            AgentProcessActivity(source: "claude", label: "Claude", cpu: 1.4),
            AgentProcessActivity(source: "codex-app", label: "Codex App", cpu: 0.1),
        ]

        XCTAssertNil(AgentProcessDetector.topBusyActivity(in: activities))
    }

    func testTopBusyActivityUsesThreshold() {
        let activities = [
            AgentProcessActivity(source: "cursor", label: "Cursor", cpu: 0.9),
            AgentProcessActivity(source: "gemini", label: "Gemini", cpu: 1.1),
        ]

        XCTAssertEqual(
            AgentProcessDetector.topBusyActivity(in: activities, threshold: 1.0),
            AgentProcessActivity(source: "gemini", label: "Gemini", cpu: 1.1)
        )
        XCTAssertNil(AgentProcessDetector.topBusyActivity(in: activities, threshold: 2.0))
    }
}
