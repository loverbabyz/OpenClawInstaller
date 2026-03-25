import XCTest
@testable import OpenClawInstaller

final class ModelProviderTests: XCTestCase {

    // MARK: - Provider Data Integrity

    func testAllProvidersHaveUniqueIds() {
        let ids = ModelProvider.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "Provider IDs must be unique")
    }

    func testAllProvidersHaveNonEmptyFields() {
        for p in ModelProvider.all {
            XCTAssertFalse(p.id.isEmpty, "Provider id should not be empty")
            XCTAssertFalse(p.title.isEmpty, "\(p.id) should have a title")
            XCTAssertFalse(p.description.isEmpty, "\(p.id) should have a description")
            XCTAssertFalse(p.icon.isEmpty, "\(p.id) should have an icon")
        }
    }

    func testProviderCount() {
        // Ensure we know the full count — update if providers are added/removed
        XCTAssertGreaterThanOrEqual(ModelProvider.all.count, 30, "Should have at least 30 providers")
    }

    // MARK: - Provider Groups

    func testPopularGroupContents() {
        let popular = ModelProvider.providers(in: .popular)
        let ids = Set(popular.map(\.id))
        XCTAssertTrue(ids.contains("anthropic"), "Popular should contain Anthropic")
        XCTAssertTrue(ids.contains("openai"), "Popular should contain OpenAI")
        XCTAssertTrue(ids.contains("gemini"), "Popular should contain Gemini")
        XCTAssertTrue(ids.contains("openrouter"), "Popular should contain OpenRouter")
        XCTAssertEqual(popular.count, 4, "Popular group should have exactly 4 providers")
    }

    func testAllGroupsHaveProviders() {
        for group in ModelProvider.ProviderGroup.allCases {
            let providers = ModelProvider.providers(in: group)
            XCTAssertFalse(providers.isEmpty, "\(group) should have at least one provider")
        }
    }

    func testProviderFilterByGroupMatchesAll() {
        for group in ModelProvider.ProviderGroup.allCases {
            let providers = ModelProvider.providers(in: group)
            for p in providers {
                XCTAssertEqual(p.group, group, "\(p.id) should be in group \(group)")
            }
        }
    }

    // MARK: - Local Providers

    func testLocalProvidersNeedModelId() {
        let local = ModelProvider.providers(in: .local)
        for p in local {
            XCTAssertTrue(p.needsModelId, "\(p.id) (local) should need modelId")
        }
    }

    func testVllmAndSglangNeedBaseURL() {
        let vllm = ModelProvider.all.first { $0.id == "vllm" }!
        let sglang = ModelProvider.all.first { $0.id == "sglang" }!
        XCTAssertTrue(vllm.needsBaseURL, "vLLM should need baseURL")
        XCTAssertTrue(sglang.needsBaseURL, "SGLang should need baseURL")
    }

    func testOllamaDoesNotNeedBaseURL() {
        let ollama = ModelProvider.all.first { $0.id == "ollama" }!
        XCTAssertFalse(ollama.needsBaseURL, "Ollama should not need baseURL")
        XCTAssertTrue(ollama.needsModelId, "Ollama should need modelId")
        XCTAssertTrue(ollama.authChoices.isEmpty, "Ollama should have no auth choices")
    }

    // MARK: - Auth Choices

    func testAnthropicHasTwoAuthChoices() {
        let anthropic = ModelProvider.all.first { $0.id == "anthropic" }!
        XCTAssertEqual(anthropic.authChoices.count, 2)
        XCTAssertEqual(anthropic.authChoices[0].type, .apiKey)
        XCTAssertEqual(anthropic.authChoices[1].type, .token)
    }

    func testGeminiHasOAuthChoice() {
        let gemini = ModelProvider.all.first { $0.id == "gemini" }!
        XCTAssertEqual(gemini.authChoices.count, 2)
        XCTAssertEqual(gemini.authChoices[1].type, .oauth)
    }

    func testGitHubCopilotHasDeviceFlow() {
        let copilot = ModelProvider.all.first { $0.id == "github-copilot" }!
        XCTAssertEqual(copilot.authChoices.count, 1)
        XCTAssertEqual(copilot.authChoices[0].type, .deviceFlow)
    }

    func testCustomProviderNeedsBaseURLAndModelId() {
        let custom = ModelProvider.all.first { $0.id == "custom" }!
        XCTAssertTrue(custom.needsBaseURL)
        XCTAssertTrue(custom.needsModelId)
    }

    // MARK: - Default Models

    func testPopularProvidersHaveDefaultModels() {
        let popular = ModelProvider.providers(in: .popular)
        for p in popular {
            XCTAssertFalse(p.defaultModel.isEmpty, "\(p.id) should have a default model")
        }
    }

    func testAnthropicModelsContainClaudeSonnet() {
        let anthropic = ModelProvider.all.first { $0.id == "anthropic" }!
        XCTAssertTrue(anthropic.models.contains { $0.contains("claude-sonnet") }, "Anthropic should include Claude Sonnet")
    }

    // MARK: - Web Search Providers

    func testWebSearchProviderCount() {
        XCTAssertEqual(WebSearchProvider.all.count, 5)
    }

    func testWebSearchProviderUniqueIds() {
        let ids = WebSearchProvider.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "Web search provider IDs must be unique")
    }

    func testWebSearchProviderEnvKeys() {
        for p in WebSearchProvider.all {
            XCTAssertFalse(p.envKey.isEmpty, "\(p.id) should have an envKey")
            XCTAssertFalse(p.title.isEmpty, "\(p.id) should have a title")
        }
    }

    // MARK: - Bundled Hooks

    func testBundledHookCount() {
        XCTAssertEqual(BundledHook.all.count, 4)
    }

    func testBundledHooksHaveUniqueIds() {
        let ids = BundledHook.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "Hook IDs must be unique")
    }

    func testBundledHooksHaveNonEmptyFields() {
        for h in BundledHook.all {
            XCTAssertFalse(h.title.isEmpty, "\(h.id) should have a title")
            XCTAssertFalse(h.description.isEmpty, "\(h.id) should have a description")
            XCTAssertFalse(h.icon.isEmpty, "\(h.id) should have an icon")
        }
    }

    // MARK: - Bundled Skills

    func testBundledSkillCount() {
        XCTAssertEqual(BundledSkill.popular.count, 14)
    }

    func testBundledSkillsHaveUniqueIds() {
        let ids = BundledSkill.popular.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "Skill IDs must be unique")
    }

    func testBundledSkillsHaveNonEmptyFields() {
        for s in BundledSkill.popular {
            XCTAssertFalse(s.title.isEmpty, "\(s.id) should have a title")
            XCTAssertFalse(s.description.isEmpty, "\(s.id) should have a description")
            XCTAssertFalse(s.emoji.isEmpty, "\(s.id) should have an emoji")
        }
    }

    func testSkillsWithBrewInstallHaveLabels() {
        for s in BundledSkill.popular where s.installKind == .brew {
            XCTAssertFalse(s.installLabel.isEmpty, "\(s.id) (brew) should have an installLabel")
            XCTAssertTrue(s.installLabel.hasPrefix("brew install"), "\(s.id) should start with 'brew install'")
        }
    }

    // MARK: - Channel Config Fields

    func testTelegramHasConfigFields() {
        let fields = ChannelType.telegram.configFields
        XCTAssertEqual(fields.count, 1)
        XCTAssertEqual(fields[0].id, "botToken")
        XCTAssertTrue(fields[0].sensitive)
    }

    func testDiscordHasConfigFields() {
        let fields = ChannelType.discord.configFields
        XCTAssertEqual(fields.count, 1)
        XCTAssertEqual(fields[0].id, "token")
    }

    func testWhatsAppHasNoConfigFields() {
        XCTAssertTrue(ChannelType.whatsapp.configFields.isEmpty)
        XCTAssertNotNil(ChannelType.whatsapp.setupHint)
    }

    func testSlackHasTwoConfigFields() {
        let fields = ChannelType.slack.configFields
        XCTAssertEqual(fields.count, 2)
        XCTAssertEqual(fields[0].id, "botToken")
        XCTAssertEqual(fields[1].id, "appToken")
    }
}
