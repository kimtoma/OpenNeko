import XCTest
@testable import OpenNekoKit

final class AgentTaskSessionTests: XCTestCase {
    private let npmTest = AgentPermissionRequest(toolName: "Bash", detail: "npm test")

    private func result(_ text: String = "ok", error: Bool = false, denials: [AgentPermissionRequest] = []) -> ClaudeTaskEvent {
        .finished(ClaudeTaskResult(text: text, isError: error, sessionID: "s1", denials: denials))
    }

    func testFirstRunArgumentsScopeToolsAndPutPromptLast() {
        let session = AgentTaskSession(prompt: "fix the tests", folder: "/p")
        let args = session.claudeArguments()
        XCTAssertEqual(Array(args.suffix(2)), ["-p", "fix the tests"])
        XCTAssertTrue(args.contains("acceptEdits"))
        XCTAssertFalse(args.contains("--resume"))
        XCTAssertFalse(args.contains("Bash"), "shell is never allowed up front")
        XCTAssertFalse(args.contains("bypassPermissions"))
        let allowedIndex = try? XCTUnwrap(args.firstIndex(of: "--allowedTools"))
        XCTAssertEqual(args[(allowedIndex ?? 0) + 1], "Read")
    }

    func testReadOnlyRunsGetNoEditToolsAndNoAutoAcceptedEdits() {
        let session = AgentTaskSession(prompt: "summarize", folder: "/p", readOnly: true)
        let args = session.claudeArguments()
        XCTAssertFalse(args.contains("acceptEdits"))
        XCTAssertTrue(args.contains("default"))
        for tool in ["Edit", "MultiEdit", "Write", "Bash"] {
            XCTAssertFalse(args.contains(tool), tool)
        }
        XCTAssertTrue(args.contains("Read"))
        XCTAssertTrue(args.contains { $0.contains("do not modify files") })
        XCTAssertEqual(Array(args.suffix(2)), ["-p", "summarize"])
    }

    func testDenialAsksApprovalThenResumesWithExactRule() {
        var session = AgentTaskSession(prompt: "run tests", folder: "/p")
        session.apply(.started(sessionID: "s1"))
        session.apply(result("need to run tests", denials: [npmTest, npmTest]))
        XCTAssertEqual(session.phase, .awaitingApproval([npmTest]))
        XCTAssertEqual(session.phase.catState, .hover)

        let followUp = session.approve()
        XCTAssertNotNil(followUp)
        XCTAssertEqual(session.phase, .running)
        XCTAssertEqual(session.approvedRules, ["Bash(npm test)"])

        let args = session.claudeArguments(followUp: followUp)
        XCTAssertTrue(args.contains("Bash(npm test)"))
        XCTAssertEqual(args[args.firstIndex(of: "--resume")! + 1], "s1")
        XCTAssertEqual(args.last, followUp)

        session.apply(result("All 12 tests pass."))
        XCTAssertEqual(session.phase, .finished("All 12 tests pass."))
        XCTAssertEqual(session.phase.catState, .success)
    }

    func testDenyStopsTask() {
        var session = AgentTaskSession(prompt: "x", folder: "/p")
        session.apply(.started(sessionID: "s1"))
        session.apply(.text("I want to delete build/"))
        session.apply(result(denials: [AgentPermissionRequest(toolName: "Bash", detail: "rm -rf build")]))
        session.deny()
        XCTAssertEqual(session.phase, .denied("I want to delete build/"))
        XCTAssertFalse(session.phase.isActive)
        XCTAssertNil(session.approve())
    }

    func testAlreadyApprovedDenialDoesNotLoop() {
        var session = AgentTaskSession(prompt: "x", folder: "/p")
        session.apply(.started(sessionID: "s1"))
        session.apply(result(denials: [npmTest]))
        _ = session.approve()
        session.apply(result("finished anyway", denials: [npmTest]))
        XCTAssertEqual(session.phase, .finished("finished anyway"))
    }

    func testApprovalRoundsAreCapped() {
        var session = AgentTaskSession(prompt: "x", folder: "/p")
        session.apply(.started(sessionID: "s1"))
        for round in 0..<AgentTaskSession.maxApprovalRounds {
            session.apply(result(denials: [AgentPermissionRequest(toolName: "Bash", detail: "step \(round)")]))
            XCTAssertNotNil(session.approve())
        }
        session.apply(result("gave up", denials: [AgentPermissionRequest(toolName: "Bash", detail: "one more")]))
        XCTAssertEqual(session.phase, .finished("gave up"))
    }

    func testErrorsAndCrashes() {
        var errored = AgentTaskSession(prompt: "x", folder: "/p")
        errored.apply(result("rate limited", error: true))
        XCTAssertEqual(errored.phase, .failed("rate limited"))

        var crashed = AgentTaskSession(prompt: "x", folder: "/p")
        crashed.processExited(status: 127, stderr: "env: claude: No such file or directory\n")
        XCTAssertEqual(crashed.phase, .failed("env: claude: No such file or directory"))

        var finished = AgentTaskSession(prompt: "x", folder: "/p")
        finished.apply(result("done"))
        finished.processExited(status: 0, stderr: "")
        XCTAssertEqual(finished.phase, .finished("done"))
    }

    func testEmptyResultFallsBackToLastText() {
        var session = AgentTaskSession(prompt: "x", folder: "/p")
        session.apply(.text("Renamed 3 files."))
        session.apply(result(""))
        XCTAssertEqual(session.phase, .finished("Renamed 3 files."))
    }
}
