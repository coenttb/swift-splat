# Swift Compiler Bug: Callable Syntax Fails to Resolve Initializers with Backtick-Escaped Parameter Names Across Modules

## Summary

When calling an initializer with backtick-escaped parameter names (e.g., `` `parameter with spaces` ``) from a different module, Swift's callable syntax `Type(args)` fails to resolve the correct initializer overload. The explicit `.init(args)` syntax works correctly.

## Environment

- Swift version: 6.2 (swiftlang-6.2.0.4.60 clang-1700.3.3.60)
- Platform: macOS 15.2 (Darwin 25.0.0)
- Xcode: 26.0 beta

## Description

When a struct has multiple initializers including one with backtick-escaped parameter names (names containing spaces), the callable syntax `Type(paramWithSpaces: value)` incorrectly matches a different initializer instead of the one with the matching parameter label.

The explicit `.init` syntax `Type.init(paramWithSpaces: value)` correctly resolves to the expected initializer.

## Steps to Reproduce

1. Create a module with this struct:

```swift
// In Module A
public struct Example: Sendable {
    public let arguments: Arguments

    // Initializer 1: Takes Arguments struct
    public init(_ arguments: Arguments) {
        self.arguments = arguments
    }

    // Initializer 2: Takes labeled parameter with spaces
    public init(`the condition is satisfied`: Bool?) {
        self.arguments = Arguments(`the condition is satisfied`: `the condition is satisfied`)
    }

    public struct Arguments: Sendable {
        public let `the condition is satisfied`: Bool?

        public init(`the condition is satisfied`: Bool? = nil) {
            self.`the condition is satisfied` = `the condition is satisfied`
        }
    }
}
```

2. In a different module, try to call the labeled initializer:

```swift
// In Module B
import ModuleA

// This FAILS - Swift matches init(_ arguments:) instead
let example1 = Example(`the condition is satisfied`: true)
// Error: cannot convert value of type 'Bool' to expected argument type 'Example.Arguments'

// This WORKS correctly
let example2 = Example.init(`the condition is satisfied`: true)
```

## Expected Behavior

Both `Example(`the condition is satisfied`: true)` and `Example.init(`the condition is satisfied`: true)` should resolve to `init(`the condition is satisfied`: Bool?)` since that's the only initializer with a matching parameter label.

## Actual Behavior

- `Example.init(`the condition is satisfied`: true)` → ✅ Correctly resolves to `init(`the condition is satisfied`: Bool?)`
- `Example(`the condition is satisfied`: true)` → ❌ Incorrectly tries to match `init(_ arguments: Arguments)`, producing a type mismatch error

## Impact

This bug affects projects using macros (like Swift's `@Splat`) that generate initializers with backtick-escaped parameter names for domain-specific use cases. The workaround is to always use explicit `.init` syntax, which is less elegant and inconsistent with Swift's design.

## Additional Context

The bug appears to be specific to:
1. Cross-module calls (within the same module, overload resolution works)
2. Parameter names with spaces (regular identifiers work with callable syntax)
3. The presence of multiple initializer overloads

## Workaround

Use explicit `.init` syntax instead of callable syntax:

```swift
// Instead of:
let example = Example(`parameter with spaces`: value)

// Use:
let example = Example.init(`parameter with spaces`: value)
```

## Related

This was discovered while using the `@Splat` macro which generates convenience initializers that "splat" struct members into labeled parameters. The macro correctly generates the initializer, but Swift's callable syntax resolution fails to find it across modules when parameter names contain spaces.
