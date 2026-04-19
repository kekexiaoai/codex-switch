import XCTest
@testable import CodexSwitchKit

final class ConfigTomlParserTests: XCTestCase {
    var parser: ConfigTomlParser!

    override func setUp() {
        super.setUp()
        parser = ConfigTomlParser()
    }

    // MARK: - Validate Provider ID Tests

    func testValidateProviderId_ValidIds() {
        XCTAssertTrue(parser.validateProviderId("openai"))
        XCTAssertTrue(parser.validateProviderId("anthropic"))
        XCTAssertTrue(parser.validateProviderId("custom-llm"))
        XCTAssertTrue(parser.validateProviderId("provider_123"))
        XCTAssertTrue(parser.validateProviderId("my.provider"))
        XCTAssertTrue(parser.validateProviderId("Provider-1.0"))
        XCTAssertTrue(parser.validateProviderId("a"))
        XCTAssertTrue(parser.validateProviderId("ABC123"))
    }

    func testValidateProviderId_InvalidIds() {
        XCTAssertFalse(parser.validateProviderId(""))
        XCTAssertFalse(parser.validateProviderId("my provider"))
        XCTAssertFalse(parser.validateProviderId("provider@123"))
        XCTAssertFalse(parser.validateProviderId("provider#test"))
        XCTAssertFalse(parser.validateProviderId("provider/test"))
        XCTAssertFalse(parser.validateProviderId("provider\\test"))
        XCTAssertFalse(parser.validateProviderId("provider:test"))
        XCTAssertFalse(parser.validateProviderId("provider*test"))
        XCTAssertFalse(parser.validateProviderId("provider?test"))
        XCTAssertFalse(parser.validateProviderId("provider!"))
    }

    // MARK: - Add Provider Tests

    func testAddProvider_ToEmptyConfig() {
        let config = ""
        let result = parser.addProvider(in: config, providerId: "anthropic")

        XCTAssertTrue(result.contains("[model_providers.anthropic]"))
    }

    func testAddProvider_ToExistingConfig() {
        let config = """
        model_provider = "openai"

        [model_providers.openai]
        """

        let result = parser.addProvider(in: config, providerId: "anthropic")

        XCTAssertTrue(result.contains("[model_providers.openai]"))
        XCTAssertTrue(result.contains("[model_providers.anthropic]"))
    }

    func testAddProvider_PreservesExistingContent() {
        let config = """
        model_provider = "openai"
        # This is a comment

        [model_providers.openai]
        api_key = "test"
        """

        let result = parser.addProvider(in: config, providerId: "anthropic")

        XCTAssertTrue(result.contains("model_provider = \"openai\""))
        XCTAssertTrue(result.contains("# This is a comment"))
        XCTAssertTrue(result.contains("api_key = \"test\""))
        XCTAssertTrue(result.contains("[model_providers.anthropic]"))
    }

    func testAddProvider_DuplicateProvider_NoChange() {
        let config = """
        [model_providers.openai]
        [model_providers.anthropic]
        """

        let result = parser.addProvider(in: config, providerId: "anthropic")

        XCTAssertEqual(config, result)
    }

    func testAddProvider_InvalidId_NoChange() {
        let config = "model_provider = \"openai\""
        let result = parser.addProvider(in: config, providerId: "invalid provider")

        XCTAssertEqual(config, result)
    }

    func testAddProvider_PreservesNewlineAtEnd() {
        let config = "model_provider = \"openai\"\n"
        let result = parser.addProvider(in: config, providerId: "anthropic")

        XCTAssertTrue(result.hasSuffix("\n"))
    }

    // MARK: - Remove Provider Tests

    func testRemoveProvider_RemovesSection() {
        let config = """
        model_provider = "openai"

        [model_providers.openai]
        [model_providers.anthropic]
        api_key = "test"
        """

        let result = parser.removeProvider(in: config, providerId: "anthropic")

        XCTAssertTrue(result.contains("[model_providers.openai]"))
        XCTAssertFalse(result.contains("[model_providers.anthropic]"))
        XCTAssertFalse(result.contains("api_key = \"test\""))
    }

    func testRemoveProvider_PreservesOtherSections() {
        let config = """
        model_provider = "openai"

        [model_providers.openai]
        key1 = "value1"

        [model_providers.anthropic]
        key2 = "value2"

        [model_providers.custom]
        key3 = "value3"
        """

        let result = parser.removeProvider(in: config, providerId: "anthropic")

        XCTAssertTrue(result.contains("[model_providers.openai]"))
        XCTAssertTrue(result.contains("key1 = \"value1\""))
        XCTAssertFalse(result.contains("[model_providers.anthropic]"))
        XCTAssertFalse(result.contains("key2 = \"value2\""))
        XCTAssertTrue(result.contains("[model_providers.custom]"))
        XCTAssertTrue(result.contains("key3 = \"value3\""))
    }

    func testRemoveProvider_NonexistentProvider_NoChange() {
        let config = """
        [model_providers.openai]
        """

        let result = parser.removeProvider(in: config, providerId: "nonexistent")

        XCTAssertEqual(config, result)
    }

    func testRemoveProvider_PreservesRootConfig() {
        let config = """
        model_provider = "openai"
        # Important comment

        [model_providers.anthropic]
        """

        let result = parser.removeProvider(in: config, providerId: "anthropic")

        XCTAssertTrue(result.contains("model_provider = \"openai\""))
        XCTAssertTrue(result.contains("# Important comment"))
        XCTAssertFalse(result.contains("[model_providers.anthropic]"))
    }

    func testRemoveProvider_LastSection() {
        let config = """
        [model_providers.openai]

        [model_providers.anthropic]
        key = "value"
        """

        let result = parser.removeProvider(in: config, providerId: "anthropic")

        XCTAssertTrue(result.contains("[model_providers.openai]"))
        XCTAssertFalse(result.contains("[model_providers.anthropic]"))
        XCTAssertFalse(result.contains("key = \"value\""))
    }

    // MARK: - List Configured Providers Tests

    func testListConfiguredProviderIds_IncludesDefault() {
        let config = ""
        let providers = parser.listConfiguredProviderIds(from: config)

        XCTAssertTrue(providers.contains("openai"))
    }

    func testListConfiguredProviderIds_MultipleProviders() {
        let config = """
        [model_providers.openai]
        [model_providers.anthropic]
        [model_providers.custom-llm]
        """

        let providers = parser.listConfiguredProviderIds(from: config)

        XCTAssertEqual(providers.count, 3)
        XCTAssertTrue(providers.contains("openai"))
        XCTAssertTrue(providers.contains("anthropic"))
        XCTAssertTrue(providers.contains("custom-llm"))
    }

    func testListConfiguredProviderIds_Sorted() {
        let config = """
        [model_providers.zebra]
        [model_providers.alpha]
        [model_providers.beta]
        """

        let providers = parser.listConfiguredProviderIds(from: config)

        XCTAssertEqual(providers, ["alpha", "beta", "openai", "zebra"])
    }

    // MARK: - Read Current Provider Tests

    func testReadCurrentProvider_Explicit() {
        let config = """
        model_provider = "anthropic"

        [model_providers.anthropic]
        """

        let result = parser.readCurrentProvider(from: config)

        XCTAssertEqual(result.provider, "anthropic")
        XCTAssertFalse(result.implicit)
    }

    func testReadCurrentProvider_Implicit() {
        let config = """
        [model_providers.openai]
        """

        let result = parser.readCurrentProvider(from: config)

        XCTAssertEqual(result.provider, "openai")
        XCTAssertTrue(result.implicit)
    }

    // MARK: - Set Root Provider Tests

    func testSetRootProvider_UpdatesExisting() {
        let config = """
        model_provider = "openai"

        [model_providers.openai]
        """

        let result = parser.setRootProvider(in: config, provider: "anthropic")

        XCTAssertTrue(result.contains("model_provider = \"anthropic\""))
        XCTAssertFalse(result.contains("model_provider = \"openai\""))
    }

    func testSetRootProvider_AddsIfMissing() {
        let config = """
        [model_providers.openai]
        """

        let result = parser.setRootProvider(in: config, provider: "anthropic")

        XCTAssertTrue(result.contains("model_provider = \"anthropic\""))
    }
}
