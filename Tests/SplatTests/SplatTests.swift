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

            struct ValidationError: Error {}
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

            struct ValidationError: Error {}
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

            struct ValidationError: Error {}
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
