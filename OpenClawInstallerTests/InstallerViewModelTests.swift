import XCTest
@testable import OpenClawInstaller

@MainActor
final class InstallerViewModelTests: XCTestCase {

    var mock: MockShellExecutor!
    var vm: InstallerViewModel!

    override func setUp() {
        super.setUp()
        mock = MockShellExecutor()
        vm = InstallerViewModel(shell: mock)
    }

    override func tearDown() {
        mock = nil
        vm = nil
        super.tearDown()
    }

    // MARK: - A. State Initialization

    func testInitialStep() {
        XCTAssertEqual(vm.currentStep, .welcome)
    }

    func testInitialMethod() {
        XCTAssertEqual(vm.selectedMethod, .npm)
    }

    func testInitialInstallState() {
        XCTAssertTrue(vm.installLog.isEmpty)
        XCTAssertEqual(vm.installProgress, 0)
        XCTAssertFalse(vm.isInstalling)
        XCTAssertFalse(vm.installSucceeded)
        XCTAssertFalse(vm.installCancelled)
        XCTAssertNil(vm.installError)
    }

    func testDefaultOnboardState() {
        XCTAssertEqual(vm.onboardStep, .providerSelect)
        XCTAssertEqual(vm.workspacePath, "~/.openclaw/workspace")
        XCTAssertTrue(vm.enabledHooks.contains("session-memory"))
        XCTAssertTrue(vm.enabledHooks.contains("boot-md"))
        XCTAssertEqual(vm.enabledHooks.count, 2)
        XCTAssertTrue(vm.enableSkills)
        XCTAssertTrue(vm.selectedSkills.contains("github"))
        XCTAssertTrue(vm.selectedSkills.contains("weather"))
    }

    func testDefaultGatewayState() {
        XCTAssertEqual(vm.gatewayPort, "18789")
        XCTAssertEqual(vm.gatewayBindMode, .loopback)
        XCTAssertEqual(vm.gatewayAuthMode, .token)
        XCTAssertFalse(vm.tailscaleEnabled)
        XCTAssertFalse(vm.tailscaleResetOnExit)
        XCTAssertTrue(vm.gatewayToken.isEmpty)
        XCTAssertTrue(vm.gatewayPassword.isEmpty)
    }

    func testDefaultHatchMode() {
        XCTAssertEqual(vm.hatchMode, .tui)
    }

    func testTaglinesNotEmpty() {
        XCTAssertFalse(vm.taglines.isEmpty)
        XCTAssertFalse(vm.randomTagline.isEmpty)
    }

    func testDefaultProviderIsAnthropic() {
        XCTAssertEqual(vm.selectedProvider.id, "anthropic")
    }

    func testDefaultDaemonAndCompletion() {
        XCTAssertTrue(vm.installDaemon)
        XCTAssertTrue(vm.installShellCompletion)
    }

    // MARK: - B. Step Navigation

    func testGoToStep() {
        vm.goToStep(.dependencyCheck)
        XCTAssertEqual(vm.currentStep, .dependencyCheck)
    }

    func testNextStep() {
        XCTAssertEqual(vm.currentStep, .welcome)
        vm.nextStep()
        XCTAssertEqual(vm.currentStep, .methodSelection)
    }

    func testNextStepSequence() {
        let expected: [InstallStep] = [.welcome, .methodSelection, .dependencyCheck, .installing, .configuring, .completion]
        for i in 0..<expected.count {
            XCTAssertEqual(vm.currentStep, expected[i])
            if i < expected.count - 1 {
                vm.nextStep()
            }
        }
    }

    func testNextStepAtEnd() {
        vm.goToStep(.completion)
        vm.nextStep()
        XCTAssertEqual(vm.currentStep, .completion, "Should stay at completion")
    }

    func testPreviousStep() {
        vm.goToStep(.methodSelection)
        vm.previousStep()
        XCTAssertEqual(vm.currentStep, .welcome)
    }

    func testPreviousStepAtStart() {
        vm.previousStep()
        XCTAssertEqual(vm.currentStep, .welcome, "Should stay at welcome")
    }

    func testEnterConfigMode() {
        vm.enterConfigMode()
        XCTAssertEqual(vm.currentStep, .configuring)
        XCTAssertEqual(vm.onboardStep, .providerSelect)
        XCTAssertFalse(vm.onboardingComplete)
        XCTAssertNil(vm.onboardingError)
        XCTAssertTrue(vm.onboardingLog.isEmpty)
    }

    // MARK: - C. Onboard Step Navigation

    func testNextOnboardStep() {
        vm.onboardStep = .providerSelect
        vm.nextOnboardStep()
        XCTAssertEqual(vm.onboardStep, .modelConfig)
    }

    func testPreviousOnboardStep() {
        vm.onboardStep = .workspace
        vm.previousOnboardStep()
        XCTAssertEqual(vm.onboardStep, .modelConfig)
    }

    func testSkipChannelConfigWhenNoChannels() {
        vm.selectedChannels = []
        vm.onboardStep = .channels
        vm.nextOnboardStep()
        XCTAssertEqual(vm.onboardStep, .webSearch, "Should skip channelConfig when no channels selected")
    }

    func testChannelConfigNotSkippedWithChannels() {
        vm.selectedChannels = [.telegram]
        vm.onboardStep = .channels
        vm.nextOnboardStep()
        XCTAssertEqual(vm.onboardStep, .channelConfig)
    }

    func testOnboardStepAtEnd() {
        vm.onboardStep = .hatchBot
        vm.nextOnboardStep()
        XCTAssertEqual(vm.onboardStep, .hatchBot, "Should stay at last step")
    }

    func testOnboardStepAtStart() {
        vm.onboardStep = .providerSelect
        vm.previousOnboardStep()
        XCTAssertEqual(vm.onboardStep, .providerSelect, "Should stay at first step")
    }

    // MARK: - D. System Detection

    func testDetectSystemArchARM() async {
        mock.addResponse(for: "uname -m", output: "arm64")
        mock.addResponse(for: "which openclaw", output: "", exitCode: 1)
        // Config check
        mock.defaultResult = ShellResult(output: "", errorOutput: "", exitCode: 1)

        await vm.detectSystem()

        XCTAssertEqual(vm.systemArch, "arm64")
        XCTAssertNil(vm.existingInstall)
        XCTAssertFalse(vm.isDetecting)
    }

    func testDetectSystemArchIntel() async {
        mock.addResponse(for: "uname -m", output: "x86_64")
        mock.addResponse(for: "which openclaw", output: "", exitCode: 1)
        mock.defaultResult = ShellResult(output: "", errorOutput: "", exitCode: 1)

        await vm.detectSystem()

        XCTAssertEqual(vm.systemArch, "x86_64")
    }

    func testDetectExistingNpmInstall() async {
        mock.addResponse(for: "uname -m", output: "arm64")
        mock.addResponse(for: "which openclaw", output: "/opt/homebrew/bin/openclaw")
        mock.addResponse(for: "openclaw --version", output: "1.2.3")
        mock.defaultResult = ShellResult(output: "", errorOutput: "", exitCode: 1)

        await vm.detectSystem()

        XCTAssertNotNil(vm.existingInstall)
        XCTAssertEqual(vm.existingInstall?.version, "1.2.3")
        XCTAssertEqual(vm.existingInstall?.method, "npm")
    }

    func testDetectExistingGitInstall() async {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        mock.addResponse(for: "uname -m", output: "arm64")
        mock.addResponse(for: "which openclaw", output: "\(home)/.local/bin/openclaw")
        mock.addResponse(for: "openclaw --version", output: "2.0.0")
        mock.defaultResult = ShellResult(output: "", errorOutput: "", exitCode: 1)

        await vm.detectSystem()

        XCTAssertNotNil(vm.existingInstall)
        XCTAssertEqual(vm.existingInstall?.method, "git")
    }

    func testDetectExistingPnpmInstall() async {
        mock.addResponse(for: "uname -m", output: "arm64")
        mock.addResponse(for: "which openclaw", output: "/some/.pnpm/openclaw")
        mock.addResponse(for: "openclaw --version", output: "1.5.0")
        mock.defaultResult = ShellResult(output: "", errorOutput: "", exitCode: 1)

        await vm.detectSystem()

        XCTAssertNotNil(vm.existingInstall)
        XCTAssertEqual(vm.existingInstall?.method, "pnpm")
    }

    // MARK: - E. Dependency Checking

    func testCheckDependenciesNpmMethod() async {
        vm.selectedMethod = .npm
        mock.addResponse(for: "which brew", output: "/opt/homebrew/bin/brew")
        mock.addResponse(for: "which node", output: "/opt/homebrew/bin/node")
        mock.addResponse(for: "which git", output: "/usr/bin/git")
        mock.addResponse(for: "which npm", output: "/opt/homebrew/bin/npm")
        mock.addResponse(for: "brew --version", output: "Homebrew 4.2.0")
        mock.addResponse(for: "node --version", output: "v22.1.0")
        mock.addResponse(for: "git --version", output: "git version 2.44.0")
        mock.addResponse(for: "npm --version", output: "10.5.0")

        await vm.checkDependencies()

        XCTAssertEqual(vm.dependencies.count, 4)
        XCTAssertEqual(vm.dependencies[0].name, "Homebrew")
        XCTAssertEqual(vm.dependencies[3].name, "npm")
        XCTAssertTrue(vm.allDepsReady)
    }

    func testCheckDependenciesGitMethod() async {
        vm.selectedMethod = .git
        mock.addResponse(for: "which brew", output: "/opt/homebrew/bin/brew")
        mock.addResponse(for: "which node", output: "/opt/homebrew/bin/node")
        mock.addResponse(for: "which git", output: "/usr/bin/git")
        mock.addResponse(for: "which pnpm", output: "/opt/homebrew/bin/pnpm")
        mock.addResponse(for: "brew --version", output: "Homebrew 4.2.0")
        mock.addResponse(for: "node --version", output: "v22.1.0")
        mock.addResponse(for: "git --version", output: "git version 2.44.0")
        mock.addResponse(for: "pnpm --version", output: "9.0.0")

        await vm.checkDependencies()

        XCTAssertEqual(vm.dependencies.count, 4)
        XCTAssertEqual(vm.dependencies[3].name, "pnpm")
        XCTAssertTrue(vm.allDepsReady)
    }

    func testNodeVersionTooLow() async {
        vm.selectedMethod = .npm
        mock.addResponse(for: "which brew", output: "/opt/homebrew/bin/brew")
        mock.addResponse(for: "which node", output: "/opt/homebrew/bin/node")
        mock.addResponse(for: "which git", output: "/usr/bin/git")
        mock.addResponse(for: "which npm", output: "/opt/homebrew/bin/npm")
        mock.addResponse(for: "brew --version", output: "Homebrew 4.2.0")
        mock.addResponse(for: "node --version", output: "v18.12.0")
        mock.addResponse(for: "git --version", output: "git version 2.44.0")
        mock.addResponse(for: "npm --version", output: "10.5.0")

        await vm.checkDependencies()

        XCTAssertFalse(vm.dependencies[1].isInstalled, "Node v18 should not satisfy v22+ requirement")
        XCTAssertFalse(vm.allDepsReady)
    }

    func testNodeVersionOK() async {
        vm.selectedMethod = .npm
        mock.addResponse(for: "which brew", output: "/opt/homebrew/bin/brew")
        mock.addResponse(for: "which node", output: "/opt/homebrew/bin/node")
        mock.addResponse(for: "which git", output: "/usr/bin/git")
        mock.addResponse(for: "which npm", output: "/opt/homebrew/bin/npm")
        mock.addResponse(for: "brew --version", output: "Homebrew 4.2.0")
        mock.addResponse(for: "node --version", output: "v22.0.0")
        mock.addResponse(for: "git --version", output: "git version 2.44.0")
        mock.addResponse(for: "npm --version", output: "10.5.0")

        await vm.checkDependencies()

        XCTAssertTrue(vm.dependencies[1].isInstalled, "Node v22 should satisfy requirement")
    }

    func testMissingDependency() async {
        vm.selectedMethod = .npm
        mock.addResponse(for: "which brew", output: "", exitCode: 1)
        mock.addResponse(for: "which node", output: "/opt/homebrew/bin/node")
        mock.addResponse(for: "which git", output: "/usr/bin/git")
        mock.addResponse(for: "which npm", output: "/opt/homebrew/bin/npm")
        mock.addResponse(for: "node --version", output: "v22.1.0")
        mock.addResponse(for: "git --version", output: "git version 2.44.0")
        mock.addResponse(for: "npm --version", output: "10.5.0")

        await vm.checkDependencies()

        XCTAssertFalse(vm.dependencies[0].isInstalled, "Homebrew should not be installed")
        XCTAssertFalse(vm.allDepsReady)
    }

    func testInstallAllMissingStopsOnFailure() async {
        vm.selectedMethod = .npm
        // Set up deps first
        mock.addResponse(for: "which brew", output: "", exitCode: 1)
        mock.addResponse(for: "which node", output: "", exitCode: 1)
        mock.addResponse(for: "which git", output: "", exitCode: 1)
        mock.addResponse(for: "which npm", output: "", exitCode: 1)
        await vm.checkDependencies()

        // Now mock brew install as failing
        mock.addResponse(for: "NONINTERACTIVE=1", output: "", exitCode: 1)

        await vm.installAllMissing()

        // Should have attempted brew install but not node/git since brew failed
        XCTAssertFalse(vm.dependencies[0].isInstalled, "Brew install should have failed")
        let nodeInstallAttempts = mock.commandsContaining("brew install node")
        XCTAssertTrue(nodeInstallAttempts.isEmpty, "Should not attempt node install when brew failed")
    }

    // MARK: - F. Installation Flow

    func testCancelInstallation() {
        vm.startInstallation()
        vm.cancelInstallation()

        XCTAssertTrue(vm.installCancelled)
        XCTAssertFalse(vm.isInstalling)
    }

    // MARK: - G. Provider and Auth Management

    func testOnProviderChanged() {
        let openai = ModelProvider.all.first { $0.id == "openai" }!
        vm.selectedProvider = openai
        vm.onProviderChanged()

        XCTAssertEqual(vm.apiKey, "")
        XCTAssertEqual(vm.setupToken, "")
        XCTAssertEqual(vm.selectedAuthChoice.type, .apiKey)
        XCTAssertEqual(vm.selectedModel, "openai/gpt-4o")
        XCTAssertFalse(vm.oauthInProgress)
        XCTAssertFalse(vm.oauthSuccess)
        XCTAssertNil(vm.oauthError)
    }

    func testProviderGroupsPopular() {
        let popular = ModelProvider.providers(in: .popular)
        XCTAssertEqual(popular.count, 4)
        let ids = popular.map(\.id)
        XCTAssertEqual(ids, ["anthropic", "openai", "gemini", "openrouter"])
    }

    func testProviderWithOAuth() {
        let gemini = ModelProvider.all.first { $0.id == "gemini" }!
        vm.selectedProvider = gemini
        XCTAssertEqual(gemini.authChoices.count, 2)
        XCTAssertEqual(gemini.authChoices[1].type, .oauth)
    }

    func testProviderWithDeviceFlow() {
        let copilot = ModelProvider.all.first { $0.id == "github-copilot" }!
        vm.selectedProvider = copilot
        XCTAssertEqual(copilot.authChoices.count, 1)
        XCTAssertEqual(copilot.authChoices[0].type, .deviceFlow)
    }

    func testLocalProviderNoAuth() {
        let ollama = ModelProvider.all.first { $0.id == "ollama" }!
        vm.selectedProvider = ollama
        XCTAssertTrue(ollama.authChoices.isEmpty)
        XCTAssertTrue(ollama.needsModelId)
    }

    func testOnProviderChangedResetsOAuthState() {
        vm.oauthInProgress = true
        vm.oauthSuccess = true
        vm.oauthError = "some error"
        vm.oauthLog = ["log1"]
        vm.apiKey = "old-key"

        let openai = ModelProvider.all.first { $0.id == "openai" }!
        vm.selectedProvider = openai
        vm.onProviderChanged()

        XCTAssertFalse(vm.oauthInProgress)
        XCTAssertFalse(vm.oauthSuccess)
        XCTAssertNil(vm.oauthError)
        XCTAssertEqual(vm.apiKey, "")
    }

    // MARK: - H. Gateway Token Generation

    func testGenerateGatewayToken() {
        vm.generateGatewayToken()

        XCTAssertEqual(vm.gatewayToken.count, 32)
        // All lowercase hex
        let hexCharSet = CharacterSet(charactersIn: "0123456789abcdef")
        XCTAssertTrue(vm.gatewayToken.unicodeScalars.allSatisfy { hexCharSet.contains($0) },
                      "Token should be all lowercase hex")
    }

    func testGenerateGatewayTokenUnique() {
        vm.generateGatewayToken()
        let first = vm.gatewayToken

        vm.generateGatewayToken()
        let second = vm.gatewayToken

        XCTAssertNotEqual(first, second, "Two generated tokens should be different")
    }

    // MARK: - I. Channel Credential Binding

    func testChannelCredentialBindingGet() {
        vm.channelCredentials["telegram"] = ["botToken": "abc123"]
        let binding = vm.channelCredentialBinding(channel: .telegram, field: "botToken")
        XCTAssertEqual(binding.wrappedValue, "abc123")
    }

    func testChannelCredentialBindingSet() {
        let binding = vm.channelCredentialBinding(channel: .telegram, field: "botToken")
        binding.wrappedValue = "xyz789"
        XCTAssertEqual(vm.channelCredentials["telegram"]?["botToken"], "xyz789")
    }

    func testChannelCredentialBindingEmpty() {
        let binding = vm.channelCredentialBinding(channel: .discord, field: "token")
        XCTAssertEqual(binding.wrappedValue, "", "Should return empty string for unconfigured channel")
    }

    func testChannelCredentialBindingCreatesDictIfNeeded() {
        XCTAssertNil(vm.channelCredentials["slack"])
        let binding = vm.channelCredentialBinding(channel: .slack, field: "botToken")
        binding.wrappedValue = "xoxb-test"
        XCTAssertEqual(vm.channelCredentials["slack"]?["botToken"], "xoxb-test")
    }

    // MARK: - J. Config Generation

    func testConfigGatewayModeMapping() {
        // loopback -> local
        XCTAssertEqual(GatewayBindMode.loopback.rawValue, "loopback")
        // lan -> network (tested via rawValue)
        XCTAssertEqual(GatewayBindMode.lan.rawValue, "lan")
        XCTAssertEqual(GatewayBindMode.auto.rawValue, "auto")
        XCTAssertEqual(GatewayBindMode.custom.rawValue, "custom")
    }

    func testRunOnboardingCreatesDirectories() async {
        // Set up minimal config
        vm.selectedProvider = ModelProvider.all.first { $0.id == "anthropic" }!
        vm.apiKey = "sk-ant-test"
        vm.selectedModel = "anthropic/claude-sonnet-4-5-20250514"
        vm.installDaemon = false
        vm.installShellCompletion = false
        vm.enableSkills = false
        vm.selectedChannels = []

        mock.defaultResult = ShellResult(output: "", errorOutput: "", exitCode: 0)
        mock.addResponse(for: "openclaw --version", output: "1.0.0")
        mock.addResponse(for: "openclaw doctor", output: "All checks passed")

        await vm.runOnboarding()

        // Verify mkdir was called for config dir and workspace
        let mkdirCmds = mock.commandsContaining("mkdir -p")
        XCTAssertFalse(mkdirCmds.isEmpty, "Should have created directories")

        // Verify doctor was run
        let doctorCmds = mock.commandsContaining("openclaw doctor")
        XCTAssertFalse(doctorCmds.isEmpty, "Should have run doctor")

        XCTAssertTrue(vm.onboardingComplete)
        XCTAssertNil(vm.onboardingError)
    }

    func testRunOnboardingWithDaemon() async {
        vm.selectedProvider = ModelProvider.all.first { $0.id == "openai" }!
        vm.apiKey = "sk-test"
        vm.selectedModel = "openai/gpt-4o"
        vm.installDaemon = true
        vm.installShellCompletion = false
        vm.enableSkills = false
        vm.selectedChannels = []
        vm.gatewayPort = "18789"
        vm.gatewayAuthMode = .token
        vm.gatewayToken = "abcd1234abcd1234abcd1234abcd1234"

        mock.defaultResult = ShellResult(output: "", errorOutput: "", exitCode: 0)
        mock.addResponse(for: "openclaw --version", output: "1.0.0")
        mock.addResponse(for: "openclaw doctor", output: "ok")
        mock.addResponse(for: "openclaw health", output: "healthy")
        mock.addResponse(for: "openclaw gateway install", output: "installed")

        await vm.runOnboarding()

        let gatewayCmds = mock.commandsContaining("gateway install")
        XCTAssertFalse(gatewayCmds.isEmpty, "Should have installed gateway daemon")
        XCTAssertTrue(vm.onboardingComplete)
    }

    func testRunOnboardingWithShellCompletion() async {
        vm.selectedProvider = ModelProvider.all.first { $0.id == "anthropic" }!
        vm.apiKey = "sk-ant-test"
        vm.installDaemon = false
        vm.installShellCompletion = true
        vm.enableSkills = false
        vm.selectedChannels = []

        mock.defaultResult = ShellResult(output: "", errorOutput: "", exitCode: 0)
        mock.addResponse(for: "openclaw --version", output: "1.0.0")
        mock.addResponse(for: "openclaw doctor", output: "ok")

        await vm.runOnboarding()

        let completionCmds = mock.commandsContaining("openclaw completion")
        XCTAssertFalse(completionCmds.isEmpty, "Should have installed shell completions")
    }

    // MARK: - K. Uninstall

    func testUninstallNpmWithBackup() async {
        vm.backupConfig = true
        vm.existingInstall = ExistingInstall(version: "1.0.0", path: "/opt/homebrew/bin/openclaw", method: "npm", hasConfig: true, hasWorkspace: true)

        mock.defaultResult = ShellResult(output: "", errorOutput: "", exitCode: 0)

        await vm.uninstall()

        let backupCmds = mock.commandsContaining("cp -R")
        XCTAssertFalse(backupCmds.isEmpty, "Should have backed up config")

        let npmCmds = mock.commandsContaining("npm rm -g openclaw")
        XCTAssertFalse(npmCmds.isEmpty, "Should have uninstalled via npm")

        XCTAssertTrue(vm.uninstallComplete)
        XCTAssertNil(vm.existingInstall)
        XCTAssertNotNil(vm.lastBackupPath)
    }

    func testUninstallGitMethod() async {
        vm.backupConfig = false
        vm.existingInstall = ExistingInstall(version: "2.0.0", path: "~/.local/bin/openclaw", method: "git", hasConfig: false, hasWorkspace: false)

        mock.defaultResult = ShellResult(output: "", errorOutput: "", exitCode: 0)

        await vm.uninstall()

        let rmLocalBin = mock.commandsContaining("rm -f").filter { $0.contains(".local/bin/openclaw") }
        XCTAssertFalse(rmLocalBin.isEmpty, "Should remove git CLI entry")

        let rmCloneDir = mock.commandsContaining("rm -rf").filter { $0.contains("/openclaw") && !$0.contains(".openclaw") }
        XCTAssertFalse(rmCloneDir.isEmpty, "Should remove clone directory")

        XCTAssertTrue(vm.uninstallComplete)
    }

    func testUninstallPnpmMethod() async {
        vm.backupConfig = false
        vm.existingInstall = ExistingInstall(version: "1.0.0", path: "/some/path", method: "pnpm", hasConfig: false, hasWorkspace: false)

        mock.defaultResult = ShellResult(output: "", errorOutput: "", exitCode: 0)

        await vm.uninstall()

        let pnpmCmds = mock.commandsContaining("pnpm remove -g openclaw")
        XCTAssertFalse(pnpmCmds.isEmpty, "Should have uninstalled via pnpm")
    }

    func testUninstallCleansShellRC() async {
        vm.backupConfig = false
        vm.existingInstall = ExistingInstall(version: "1.0.0", path: "/usr/local/bin/openclaw", method: "npm", hasConfig: false, hasWorkspace: false)

        mock.defaultResult = ShellResult(output: "", errorOutput: "", exitCode: 0)

        await vm.uninstall()

        let sedCmds = mock.commandsContaining("sed")
        XCTAssertGreaterThanOrEqual(sedCmds.count, 2, "Should clean both .zshrc and .bashrc")
    }

    func testUninstallNoBackupWhenDisabled() async {
        vm.backupConfig = false
        vm.existingInstall = ExistingInstall(version: "1.0.0", path: "/opt/homebrew/bin/openclaw", method: "npm", hasConfig: true, hasWorkspace: true)

        mock.defaultResult = ShellResult(output: "", errorOutput: "", exitCode: 0)

        await vm.uninstall()

        let backupCmds = mock.commandsContaining("cp -R")
        XCTAssertTrue(backupCmds.isEmpty, "Should not backup when disabled")
        XCTAssertNil(vm.lastBackupPath)
    }

    // MARK: - L. Doctor

    func testRunDoctor() async {
        mock.addStreamingResponse(for: "openclaw doctor", output: "All checks passed", exitCode: 0)

        vm.runDoctor()

        // Wait for async task to complete
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertFalse(vm.doctorRunning)
        XCTAssertEqual(vm.doctorExitCode, 0)
    }

    func testRunDoctorFix() async {
        mock.addStreamingResponse(for: "openclaw doctor --fix", output: "Fixed issues", exitCode: 0)

        vm.runDoctorFix()

        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertFalse(vm.doctorFixRunning)
        XCTAssertTrue(vm.doctorFixDone)
        XCTAssertEqual(vm.doctorFixExitCode, 0)
    }

    func testDoctorExitCodeCapture() async {
        mock.addStreamingResponse(for: "openclaw doctor", output: "Issues found", exitCode: 1)

        vm.runDoctor()

        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(vm.doctorExitCode, 1)
    }

    // MARK: - M. Miscellaneous

    func testSelectedChannelsInitiallyEmpty() {
        XCTAssertTrue(vm.selectedChannels.isEmpty)
    }

    func testChannelCredentialsInitiallyEmpty() {
        XCTAssertTrue(vm.channelCredentials.isEmpty)
    }

    func testWebSearchInitiallyEmpty() {
        XCTAssertTrue(vm.selectedWebSearchProvider.isEmpty)
        XCTAssertTrue(vm.webSearchApiKey.isEmpty)
    }

    func testSkillsNodeManagerDefault() {
        XCTAssertEqual(vm.skillsNodeManager, "npm")
    }

    func testDefaultSelectedSkills() {
        let expected: Set<String> = ["github", "weather", "coding-agent", "canvas", "session-logs"]
        XCTAssertEqual(vm.selectedSkills, expected)
    }
}
