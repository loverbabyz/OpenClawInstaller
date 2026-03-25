import XCTest
@testable import OpenClawInstaller

final class EnumTests: XCTestCase {

    // MARK: - InstallStep

    func testInstallStepCaseCount() {
        XCTAssertEqual(InstallStep.allCases.count, 6)
    }

    func testInstallStepRawValues() {
        let expected: [(InstallStep, Int)] = [
            (.welcome, 0), (.methodSelection, 1), (.dependencyCheck, 2),
            (.installing, 3), (.configuring, 4), (.completion, 5),
        ]
        for (step, raw) in expected {
            XCTAssertEqual(step.rawValue, raw, "\(step) should have rawValue \(raw)")
        }
    }

    // MARK: - InstallMethod

    func testInstallMethodCaseCount() {
        XCTAssertEqual(InstallMethod.allCases.count, 2)
    }

    func testInstallMethodProperties() {
        for method in InstallMethod.allCases {
            XCTAssertFalse(method.title.isEmpty, "\(method) should have a title")
            XCTAssertFalse(method.description.isEmpty, "\(method) should have a description")
            XCTAssertFalse(method.icon.isEmpty, "\(method) should have an icon")
        }
    }

    // MARK: - OnboardStep

    func testOnboardStepCaseCount() {
        XCTAssertEqual(OnboardStep.allCases.count, 12)
    }

    func testOnboardStepSequentialRawValues() {
        for (index, step) in OnboardStep.allCases.enumerated() {
            XCTAssertEqual(step.rawValue, index, "\(step) should have rawValue \(index)")
        }
    }

    func testOnboardStepAllHaveTitles() {
        for step in OnboardStep.allCases {
            XCTAssertFalse(step.title.isEmpty, "\(step) should have a non-empty title")
        }
    }

    func testOnboardStepAllHaveIcons() {
        for step in OnboardStep.allCases {
            XCTAssertFalse(step.icon.isEmpty, "\(step) should have a non-empty icon")
        }
    }

    // MARK: - AuthType

    func testAuthTypeCaseCount() {
        let allCases: [AuthType] = [.apiKey, .oauth, .token, .deviceFlow]
        XCTAssertEqual(allCases.count, 4)
    }

    func testAuthTypeRawValues() {
        XCTAssertEqual(AuthType.apiKey.rawValue, "api-key")
        XCTAssertEqual(AuthType.oauth.rawValue, "oauth")
        XCTAssertEqual(AuthType.token.rawValue, "token")
        XCTAssertEqual(AuthType.deviceFlow.rawValue, "device-flow")
    }

    // MARK: - GatewayAuthMode

    func testGatewayAuthModeCaseCount() {
        XCTAssertEqual(GatewayAuthMode.allCases.count, 3)
    }

    func testGatewayAuthModeAllHaveTitles() {
        for mode in GatewayAuthMode.allCases {
            XCTAssertFalse(mode.title.isEmpty, "\(mode) should have a title")
        }
    }

    func testGatewayAuthModeRawValues() {
        XCTAssertEqual(GatewayAuthMode.token.rawValue, "token")
        XCTAssertEqual(GatewayAuthMode.password.rawValue, "password")
        XCTAssertEqual(GatewayAuthMode.none.rawValue, "none")
    }

    // MARK: - GatewayBindMode

    func testGatewayBindModeCaseCount() {
        XCTAssertEqual(GatewayBindMode.allCases.count, 4)
    }

    func testGatewayBindModeAllHaveTitlesAndSubtitles() {
        for mode in GatewayBindMode.allCases {
            XCTAssertFalse(mode.title.isEmpty, "\(mode) should have a title")
            XCTAssertFalse(mode.subtitle.isEmpty, "\(mode) should have a subtitle")
        }
    }

    // MARK: - ChannelType

    func testChannelTypeCaseCount() {
        XCTAssertEqual(ChannelType.allCases.count, 22)
    }

    func testChannelTypeAllHaveTitlesAndIcons() {
        for ch in ChannelType.allCases {
            XCTAssertFalse(ch.title.isEmpty, "\(ch) should have a title")
            XCTAssertFalse(ch.icon.isEmpty, "\(ch) should have an icon")
        }
    }

    func testChannelTypeIdEqualsRawValue() {
        for ch in ChannelType.allCases {
            XCTAssertEqual(ch.id, ch.rawValue)
        }
    }

    func testCoreChannelGroup() {
        let expected: [ChannelType] = [.telegram, .whatsapp, .discord, .irc, .googlechat, .slack, .signal, .imessage, .line]
        for ch in expected {
            XCTAssertEqual(ch.group, .core, "\(ch) should be in core group")
        }
    }

    func testPluginChannelGroup() {
        let plugin: [ChannelType] = [.bluebubbles, .mattermost, .matrix, .msteams, .nextcloudTalk, .nostr, .synologyChat, .tlon, .twitch, .zalo, .zalouser, .feishu, .webchat]
        for ch in plugin {
            XCTAssertEqual(ch.group, .plugin, "\(ch) should be in plugin group")
        }
    }

    // MARK: - ChannelGroup

    func testChannelGroupCaseCount() {
        XCTAssertEqual(ChannelGroup.allCases.count, 2)
    }

    // MARK: - HatchMode

    func testHatchModeCaseCount() {
        XCTAssertEqual(HatchMode.allCases.count, 3)
    }

    func testHatchModeAllHaveProperties() {
        for mode in HatchMode.allCases {
            XCTAssertFalse(mode.title.isEmpty, "\(mode) should have a title")
            XCTAssertFalse(mode.subtitle.isEmpty, "\(mode) should have a subtitle")
            XCTAssertFalse(mode.icon.isEmpty, "\(mode) should have an icon")
        }
    }

    func testHatchModeRawValues() {
        XCTAssertEqual(HatchMode.tui.rawValue, "tui")
        XCTAssertEqual(HatchMode.webUI.rawValue, "web")
        XCTAssertEqual(HatchMode.later.rawValue, "later")
    }

    // MARK: - SkillInstallKind

    func testSkillInstallKindRawValues() {
        XCTAssertEqual(SkillInstallKind.brew.rawValue, "brew")
        XCTAssertEqual(SkillInstallKind.node.rawValue, "node")
        XCTAssertEqual(SkillInstallKind.uv.rawValue, "uv")
        XCTAssertEqual(SkillInstallKind.go.rawValue, "go")
        XCTAssertEqual(SkillInstallKind.none.rawValue, "none")
    }
}
