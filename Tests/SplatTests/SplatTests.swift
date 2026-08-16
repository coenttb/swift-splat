import Splat
import Testing

@Suite
struct SplatTests {

    @Test func `basic splat works`() {
        @Splat
        struct Person: Sendable {
            let arguments: Arguments

            init(_ arguments: Arguments) {
                self.arguments = arguments
            }

            struct Arguments: Sendable {
                let name: String
                let age: Int
            }
        }

        // Test that the splatted initializer works
        let person = Person(name: "Alice", age: 30)
        #expect(person.arguments.name == "Alice")
        #expect(person.arguments.age == 30)
    }

    @Test func `splat with throws`() {
        @Splat
        struct Donor: Sendable {
            let arguments: Arguments

            init(_ arguments: Arguments) throws {
                guard arguments.isAlive else {
                    throw ValidationError()
                }
                self.arguments = arguments
            }

            struct Arguments: Sendable {
                let isAlive: Bool
            }

            struct ValidationError: Swift.Error {}
        }

        // Test successful case
        let donor = try? Donor(isAlive: true)
        #expect(donor != nil)
        #expect(donor?.arguments.isAlive == true)

        // Test failure case
        let failedDonor = try? Donor(isAlive: false)
        #expect(failedDonor == nil)
    }

    @Test func `splat with typed throws`() {
        @Splat
        struct Donor: Sendable {
            let arguments: Arguments

            init(_ arguments: Arguments) throws(ValidationError) {
                guard arguments.isAlive else {
                    throw ValidationError()
                }
                self.arguments = arguments
            }

            struct Arguments: Sendable {
                let isAlive: Bool
            }

            struct ValidationError: Swift.Error {}
        }

        // Test successful case
        do {
            let donor = try Donor(isAlive: true)
            #expect(donor.arguments.isAlive == true)
        } catch {
            Issue.record("Should not throw for valid input")
        }

        // Test failure case
        do {
            _ = try Donor(isAlive: false)
            Issue.record("Should throw for invalid input")
        } catch is Donor.ValidationError {
            // Expected
        } catch {
            Issue.record("Should throw ValidationError")
        }
    }

    @Test func `splat with optional types`() {
        @Splat
        struct Donor: Sendable {
            let arguments: Arguments

            init(_ arguments: Arguments) throws {
                guard arguments.isAlive == true || arguments.isDeceased == true else {
                    throw ValidationError()
                }
                self.arguments = arguments
            }

            struct Arguments: Sendable {
                let isAlive: Bool?
                let isDeceased: Bool?
            }

            struct ValidationError: Swift.Error {}
        }

        // Test with one option true
        let donor1 = try? Donor(isAlive: true, isDeceased: nil)
        #expect(donor1 != nil)

        // Test with other option true
        let donor2 = try? Donor(isAlive: nil, isDeceased: true)
        #expect(donor2 != nil)

        // Test with both false
        let donor3 = try? Donor(isAlive: false, isDeceased: false)
        #expect(donor3 == nil)
    }

    @Test func `splat with custom names`() {
        @Splat(propertyName: "state", structName: "State")
        struct Machine: Sendable {
            let state: State

            init(_ state: State) {
                self.state = state
            }

            struct State: Sendable {
                let isActive: Bool
            }
        }

        // Test that the splatted initializer works with custom names
        let machine = Machine(isActive: true)
        #expect(machine.state.isActive == true)
    }

    @Test func `splat preserves default parameter values`() {
        @Splat
        struct LegalArticle: Sendable {
            let arguments: Arguments

            init(_ arguments: Arguments) {
                self.arguments = arguments
            }

            struct Arguments: Sendable {
                let condition1: Bool?
                let condition2: Bool?
                let condition3: Bool?

                init(
                    condition1: Bool? = nil,
                    condition2: Bool? = nil,
                    condition3: Bool? = nil
                ) {
                    self.condition1 = condition1
                    self.condition2 = condition2
                    self.condition3 = condition3
                }
            }
        }

        // Test calling with all parameters omitted (all default to nil)
        let article1 = LegalArticle()
        #expect(article1.arguments.condition1 == nil)
        #expect(article1.arguments.condition2 == nil)
        #expect(article1.arguments.condition3 == nil)

        // Test calling with only some parameters (others default to nil)
        let article2 = LegalArticle(condition1: true)
        #expect(article2.arguments.condition1 == true)
        #expect(article2.arguments.condition2 == nil)
        #expect(article2.arguments.condition3 == nil)

        // Test calling with all parameters explicit
        let article3 = LegalArticle(condition1: true, condition2: false, condition3: nil)
        #expect(article3.arguments.condition1 == true)
        #expect(article3.arguments.condition2 == false)
        #expect(article3.arguments.condition3 == nil)
    }

    @Test func `splat preserves default values with throws`() {
        @Splat
        struct Checker: Sendable {
            let arguments: Arguments

            init(_ arguments: Arguments) throws(Error) {
                guard arguments.required == true else {
                    throw Error(arguments: arguments)
                }
                self.arguments = arguments
            }

            struct Arguments: Sendable {
                let required: Bool?
                let optional1: Bool?
                let optional2: Bool?

                init(
                    required: Bool? = nil,
                    optional1: Bool? = nil,
                    optional2: Bool? = nil
                ) {
                    self.required = required
                    self.optional1 = optional1
                    self.optional2 = optional2
                }
            }

            struct Error: Swift.Error, Sendable {
                let arguments: Arguments
            }
        }

        // Omit optional params — they default to nil
        let result = try? Checker(required: true)
        #expect(result != nil)
        #expect(result?.arguments.optional1 == nil)
        #expect(result?.arguments.optional2 == nil)

        // Omit everything — required defaults to nil, throws
        let failed = try? Checker()
        #expect(failed == nil)
    }

    @Test func `allCases generates exhaustive Bool? combinations`() {
        @Splat
        struct Rule: Sendable {
            let arguments: Arguments

            init(_ arguments: Arguments) {
                self.arguments = arguments
            }

            struct Arguments: Sendable {
                let a: Bool?
                let b: Bool?

                init(
                    a: Bool? = nil,
                    b: Bool? = nil
                ) {
                    self.a = a
                    self.b = b
                }
            }
        }

        // 3^2 = 9 combinations
        #expect(Rule.allCases.count == 9)

        // Verify all combinations present
        let values: [Bool?] = [true, false, nil]
        for v0 in values {
            for v1 in values {
                let found = Rule.allCases.contains { args in
                    args.a == v0 && args.b == v1
                }
                #expect(
                    found,
                    "Missing combination a=\(String(describing: v0)), b=\(String(describing: v1))"
                )
            }
        }
    }

    @Test func `allCases with single Bool? property`() {
        @Splat
        struct Flag: Sendable {
            let arguments: Arguments

            init(_ arguments: Arguments) {
                self.arguments = arguments
            }

            struct Arguments: Sendable {
                let isSet: Bool?

                init(isSet: Bool? = nil) {
                    self.isSet = isSet
                }
            }
        }

        #expect(Flag.allCases.count == 3)

        let hasTrue = Flag.allCases.contains { $0.isSet == true }
        let hasFalse = Flag.allCases.contains { $0.isSet == false }
        let hasNil = Flag.allCases.contains { $0.isSet == nil }
        #expect(hasTrue)
        #expect(hasFalse)
        #expect(hasNil)
    }

    @Test func `allCases with three Bool? properties`() {
        @Splat
        struct Check: Sendable {
            let arguments: Arguments

            init(_ arguments: Arguments) {
                self.arguments = arguments
            }

            struct Arguments: Sendable {
                let x: Bool?
                let y: Bool?
                let z: Bool?

                init(
                    x: Bool? = nil,
                    y: Bool? = nil,
                    z: Bool? = nil
                ) {
                    self.x = x
                    self.y = y
                    self.z = z
                }
            }
        }

        // 3^3 = 27 combinations
        #expect(Check.allCases.count == 27)
    }

    @Test func `splat with backtick-space property names`() {
        @Splat
        struct Lid: Sendable {
            let arguments: Arguments

            init(_ arguments: Arguments) {
                self.arguments = arguments
            }

            struct Arguments: Sendable {
                let `betreft het de staat`: Bool?
                let `betreft het een provincie`: Bool?

                init(
                    `betreft het de staat`: Bool? = nil,
                    `betreft het een provincie`: Bool? = nil
                ) {
                    self.`betreft het de staat` = `betreft het de staat`
                    self.`betreft het een provincie` = `betreft het een provincie`
                }
            }
        }

        // Test splatted init works with backtick-space names
        let lid = Lid(`betreft het de staat`: true, `betreft het een provincie`: false)
        #expect(lid.arguments.`betreft het de staat` == true)
        #expect(lid.arguments.`betreft het een provincie` == false)

        // Test allCases: 3^2 = 9 combinations
        #expect(Lid.allCases.count == 9)
    }

    @Test func `allCases skipped for non-Bool? types`() {
        @Splat
        struct Person: Sendable {
            let arguments: Arguments

            init(_ arguments: Arguments) {
                self.arguments = arguments
            }

            struct Arguments: Sendable {
                let name: String
                let age: Int
            }
        }

        // Person should not have allCases — this is a compile-time check.
        // If allCases were generated for non-Bool? types, this test file
        // would fail to compile due to type mismatch. The fact that
        // Person(name:age:) works but Person.allCases doesn't exist
        // is verified by the compiler.
        let person = Person(name: "Alice", age: 30)
        #expect(person.arguments.name == "Alice")
    }

    @Test func `splat with nested Arguments`() {
        @Splat
        struct Article: Sendable {
            let arguments: Arguments

            init(_ arguments: Arguments) {
                self.arguments = arguments
            }

            struct Arguments: Sendable {
                let lid1: Lid1.Arguments
                let lid2: Lid2.Arguments
            }

            // Nested struct definitions that Arguments references
            struct Lid1 {
                struct Arguments: Sendable {
                    let condition1: Bool
                    let condition2: Bool
                }
            }

            struct Lid2 {
                struct Arguments: Sendable {
                    let exception1: Bool
                    let exception2: Bool
                }
            }
        }

        // Test flattened initializer - all 4 parameters in one call
        let article = Article(
            condition1: true,
            condition2: false,
            exception1: false,
            exception2: true
        )

        // Verify nested structure was constructed correctly
        #expect(article.arguments.lid1.condition1 == true)
        #expect(article.arguments.lid1.condition2 == false)
        #expect(article.arguments.lid2.exception1 == false)
        #expect(article.arguments.lid2.exception2 == true)
    }
}
