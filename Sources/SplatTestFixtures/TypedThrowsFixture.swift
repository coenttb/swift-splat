//
//  TypedThrowsFixture.swift
//  swift-splat
//
//  Test fixture for cross-module typed throws testing
//

import Splat

/// A fixture struct that uses @Splat with typed throws.
/// Used to test that typed throws propagates correctly across module boundaries.
@Splat
public struct TypedThrowsFixture: Sendable {
    public let arguments: Arguments

    public init(_ arguments: Arguments) throws(Error) {
        guard arguments.isValid else {
            throw Error(reason: "Validation failed: isValid was false")
        }
        self.arguments = arguments
    }

    public struct Arguments: Sendable {
        public let isValid: Bool

        public init(isValid: Bool) {
            self.isValid = isValid
        }
    }

    public struct Error: Swift.Error, Sendable {
        public let reason: String

        public init(reason: String) {
            self.reason = reason
        }
    }
}

// MARK: - Non-throwing fixture for comparison

public enum RegularNamespace {
    public enum Three10 {
        @Splat
        public struct One: Sendable {
            public let arguments: Arguments
            public let output: Output

            public enum Output: Sendable, Equatable {
                case valid
                case invalid
            }

            public init(_ arguments: Arguments) {
                self.arguments = arguments
                self.output = arguments.conditionSatisfied == true ? .valid : .invalid
            }

            public struct Arguments: Sendable {
                public let conditionSatisfied: Bool?

                public init(conditionSatisfied: Bool? = nil) {
                    self.conditionSatisfied = conditionSatisfied
                }
            }
        }
    }
}

// MARK: - Note on Backtick Parameter Names
//
// There is a Swift compiler bug where callable syntax `Type(args)` doesn't
// correctly resolve @Splat-generated initializers with backtick-escaped
// parameter names (names containing spaces) across module boundaries.
//
// Example of the bug:
//   `SomeType`(`param with spaces`: value)  // FAILS - wrong init matched
//   `SomeType`.init(`param with spaces`: value)  // WORKS
//
// The workaround is to always use explicit `.init` syntax when parameter
// names contain spaces.
