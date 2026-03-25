import XCTest
@testable import OpenClawInstaller

final class ShellExecutorTests: XCTestCase {

    let shell = ShellExecutor.shared

    // MARK: - Basic Execution

    func testRunEchoCommand() async {
        let result = await shell.run("echo hello")
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.output, "hello")
    }

    func testRunFailingCommand() async {
        let result = await shell.run("false")
        XCTAssertNotEqual(result.exitCode, 0)
    }

    func testRunCommandWithOutput() async {
        let result = await shell.run("echo -n 'test output'")
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.output, "test output")
    }

    // MARK: - commandExists

    func testCommandExistsForBash() async {
        let exists = await shell.commandExists("bash")
        XCTAssertTrue(exists, "bash should exist on macOS")
    }

    func testCommandExistsForNonexistent() async {
        let exists = await shell.commandExists("zzz_no_such_cmd_1234567890")
        XCTAssertFalse(exists, "Non-existent command should return false")
    }

    // MARK: - getCommandVersion

    func testGetCommandVersionBash() async {
        let version = await shell.getCommandVersion("bash")
        XCTAssertNotNil(version, "bash --version should return output")
        XCTAssertFalse(version!.isEmpty, "bash version should not be empty")
    }

    func testGetCommandVersionNonexistent() async {
        let version = await shell.getCommandVersion("zzz_no_such_cmd_1234567890")
        XCTAssertNil(version, "Non-existent command version should be nil")
    }

    // MARK: - PATH

    func testPathContainsHomebrew() async {
        let result = await shell.run("echo $PATH")
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.output.contains("/opt/homebrew/bin"), "PATH should include Homebrew")
    }

    func testPathContainsUsrBin() async {
        let result = await shell.run("echo $PATH")
        XCTAssertTrue(result.output.contains("/usr/bin"), "PATH should include /usr/bin")
    }

    // MARK: - Streaming

    func testRunStreamingOutput() async {
        var captured: [String] = []
        let exitCode = await shell.runStreaming("echo 'streaming_test'") { output in
            captured.append(output)
        }
        XCTAssertEqual(exitCode, 0)
        let joined = captured.joined()
        XCTAssertTrue(joined.contains("streaming_test"), "Streaming output should contain 'streaming_test'")
    }

    func testRunStreamingExitCode() async {
        let exitCode = await shell.runStreaming("exit 42") { _ in }
        XCTAssertEqual(exitCode, 42)
    }

    // MARK: - Environment

    func testRunWithCustomEnvironment() async {
        let result = await shell.run("echo $MY_TEST_VAR", environment: ["MY_TEST_VAR": "hello_from_test"])
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.output, "hello_from_test")
    }
}
