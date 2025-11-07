# swift-splat

[![CI](https://github.com/coenttb/swift-splat/workflows/CI/badge.svg)](https://github.com/coenttb/swift-splat/actions/workflows/ci.yml)
![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

A Swift macro that generates convenience initializers by "splatting" nested struct properties into individual parameters.

## Overview

`swift-splat` provides the `@Splat` macro that automatically generates convenience initializers for types containing nested argument structs. This pattern is common when using an Arguments struct for validation and composition, but you want to provide an ergonomic API that accepts individual parameters.

The macro preserves your existing initializer (which may contain validation logic) while generating a new initializer that accepts the struct's properties as individual parameters.

## Features

- Generates convenience initializers with individual parameters
- Preserves throwing and typed-throwing behavior
- Supports optional types
- Handles backticked identifiers for natural language parameter names
- Customizable struct and property names
- Zero runtime overhead (compile-time code generation)

## Installation

Add `swift-splat` to your Package.swift:

```swift
dependencies: [
    .package(url: "https://github.com/coenttb/swift-splat.git", from: "0.1.0")
]
```

Then add it to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "Splat", package: "swift-splat")
    ]
)
```

## Quick Start

```swift
import Splat

@Splat
struct Person {
    let arguments: Arguments

    init(_ arguments: Arguments) throws {
        // Your validation logic here
        guard !arguments.name.isEmpty else {
            throw ValidationError.emptyName
        }
        self.arguments = arguments
    }

    struct Arguments {
        let name: String
        let age: Int
    }
}

// Use the generated convenience initializer
let person = try Person(name: "Alice", age: 30)

// Or use the original Arguments-based initializer
let args = Person.Arguments(name: "Bob", age: 25)
let person2 = try Person(args)
```

## Usage Examples

### Basic Usage

The `@Splat` macro generates a convenience initializer that accepts individual parameters:

```swift
@Splat
struct Donor {
    let arguments: Arguments

    init(_ arguments: Arguments) throws {
        self.arguments = arguments
    }

    struct Arguments {
        let isAlive: Bool
        let age: Int
    }
}

// Generated convenience initializer:
// public init(isAlive: Bool, age: Int) throws {
//     try self.init(Arguments(isAlive: isAlive, age: age))
// }

// Usage
let donor = try Donor(isAlive: true, age: 30)
```

### With Typed Throws

The macro preserves typed throws (Swift 6.0+):

```swift
@Splat
struct Validator {
    let arguments: Arguments

    init(_ arguments: Arguments) throws(ValidationError) {
        guard arguments.isValid else {
            throw ValidationError.invalid
        }
        self.arguments = arguments
    }

    struct Arguments {
        let isValid: Bool
    }

    struct ValidationError: Error {
        case invalid
    }
}

// Generated with typed throws
let validator = try Validator(isValid: true)  // throws(ValidationError)
```

### With Optional Types

The macro correctly handles optional types:

```swift
@Splat
struct Config {
    let arguments: Arguments

    init(_ arguments: Arguments) {
        self.arguments = arguments
    }

    struct Arguments {
        let host: String?
        let port: Int?
    }
}

let config = Config(host: nil, port: 8080)
```

### Custom Struct Names

You can customize the struct and property names:

```swift
@Splat(propertyName: "state", structName: "State")
struct Machine {
    let state: State

    init(_ state: State) {
        self.state = state
    }

    struct State {
        let isActive: Bool
        let temperature: Double
    }
}

let machine = Machine(isActive: true, temperature: 72.5)
```

### With Natural Language Identifiers

The macro preserves backticked identifiers for natural language parameter names (useful for encoding statutes or domain-specific languages):

```swift
@Splat
struct Statute {
    let arguments: Arguments

    init(_ arguments: Arguments) throws {
        self.arguments = arguments
    }

    struct Arguments {
        let `is een levende persoon`: Bool
        let `is ouder dan 18 jaar`: Bool
    }
}

// Generated with natural language parameters
let statute = try Statute(
    `is een levende persoon`: true,
    `is ouder dan 18 jaar`: true
)
```

## How It Works

The `@Splat` macro is an attached member macro that:

1. Finds the target nested struct (default: `Arguments`)
2. Extracts all stored properties from that struct
3. Generates a public convenience initializer with those properties as parameters
4. Calls your original initializer, creating the struct instance
5. Preserves throwing/typed-throwing behavior from your original initializer

The generated initializer has the same effect specifiers (`throws`, `throws(ErrorType)`) as your original initializer.

## Design Rationale

The Arguments struct pattern is useful for:

- **Error reporting**: Storing the exact values that caused validation failure
- **Testing**: Creating reusable test fixtures
- **Composition**: Passing bundles of related parameters
- **Pattern matching**: Destructuring in switch statements

However, requiring explicit Arguments construction for every initialization is verbose. `@Splat` gives you the best of both worlds: keep the Arguments struct for its benefits, but provide ergonomic direct initialization for common cases.

## Requirements

- Swift 6.2+
- macOS 15.0+ / iOS 18.0+
- Uses Swift Macros (requires swift-syntax 600.0.0+)

## Related Packages

- [swift-macro-testing](https://github.com/pointfreeco/swift-macro-testing) - Point-Free's toolkit for testing Swift macros
- [swift-syntax](https://github.com/swiftlang/swift-syntax) - SwiftSyntax library for Swift AST manipulation

## License

This library is released under the Apache 2.0 License. See [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.
