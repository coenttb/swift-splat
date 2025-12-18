//
//  InitSyntaxTests.swift
//  swift-splat
//
//  Tests the difference between Type(args) and Type.init(args) syntax
//  with typed throws across modules.
//

import SplatTestFixtures
import Testing

@Suite
struct InitSyntaxTests {

    // MARK: - Regular name tests (typed throws)

    @Test
    func callableStyleTypedThrows() {
        // Using TypeName(args) syntax - the "callable" style
        do {
            _ = try TypedThrowsFixture(isValid: false)
            Issue.record("Should have thrown")
        } catch {
            // With typed throws, `error` is TypedThrowsFixture.Error, not `any Error`
            #expect(error.reason == "Validation failed: isValid was false")
        }
    }

    @Test
    func explicitInitTypedThrows() {
        // Using TypeName.init(args) syntax - explicit init
        do {
            _ = try TypedThrowsFixture.init(isValid: false)
            Issue.record("Should have thrown")
        } catch {
            #expect(error.reason == "Validation failed: isValid was false")
        }
    }

    // MARK: - Regular name tests (non-throwing)

    @Test
    func regularCallableStyle() {
        // Using RegularNamespace.Three10.One(args) syntax - callable style
        let result = RegularNamespace.Three10.One(conditionSatisfied: true)
        #expect(result.output == .valid)
    }

    @Test
    func regularExplicitInit() {
        // Using RegularNamespace.Three10.One.init(args) syntax - explicit init
        let result = RegularNamespace.Three10.One.init(conditionSatisfied: true)
        #expect(result.output == .valid)
    }

    // MARK: - Backtick-escaped name tests
    //
    // NOTE: There is a Swift compiler bug where callable syntax `Type(args)`
    // doesn't correctly resolve @Splat-generated initializers with backtick-escaped
    // parameter names (names containing spaces) across module boundaries.
    //
    // The workaround is to use explicit `.init` syntax:
    //   `Type`.init(`param with spaces`: value)  // Works
    //   `Type`(`param with spaces`: value)       // Fails - Swift bug
    //
    // The backtickExplicitInit test below is commented out because the
    // BacktickNamespace fixture also demonstrates this bug.
}
