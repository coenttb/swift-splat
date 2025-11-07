@testable import Splat
import Testing

@Test func `verify DocC comment generation`() throws {
    @Splat
    struct Example: Sendable {
        let arguments: Arguments

        struct Arguments: Sendable {
            /// The person's name
            let name: String

            /// The person's age
            let age: Int

            /// Whether the person is active
            let isActive: Bool
        }

        init(_ arguments: Arguments) throws {
            guard arguments.isActive else {
                throw ValidationError()
            }
            self.arguments = arguments
        }

        struct ValidationError: Error {}
    }

    // Test that it compiles and works
    let example = try Example(name: "Test", age: 25, isActive: true)
    #expect(example.arguments.name == "Test")
    #expect(example.arguments.age == 25)
    #expect(example.arguments.isActive == true)
}
