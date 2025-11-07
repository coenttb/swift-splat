/// A macro that generates a convenience initializer by "splatting" the properties
/// of a nested struct into the containing type's initializer parameters.
///
/// Apply this macro to a type that:
/// 1. Contains a stored property of the specified struct type
/// 2. Has a nested struct with public stored properties
/// 3. Has an initializer that accepts the struct value
///
/// The macro generates a convenience initializer that accepts the struct properties
/// as individual parameters and calls the struct-based initializer internally.
///
/// ## Example
///
/// ```swift
/// @Splat
/// struct Donor {
///     let arguments: Arguments
///
///     init(_ arguments: Arguments) throws {
///         self.arguments = arguments
///     }
///
///     struct Arguments {
///         let isAlive: Bool
///         let age: Int
///     }
/// }
///
/// // Or with a custom struct name:
/// @Splat(propertyName: "state", structName: "State")
/// struct Machine {
///     let state: State
///
///     init(_ state: State) {
///         self.state = state
///     }
///
///     struct State {
///         let isActive: Bool
///     }
/// }
///
/// // Generated:
/// // init(isAlive: Bool, age: Int) throws {
/// //     try self.init(Arguments(isAlive: isAlive, age: age))
/// // }
///
/// // Usage:
/// let donor = try Donor(isAlive: true, age: 30)
/// let machine = Machine(isActive: true)
/// ```
///
/// ## Requirements
///
/// For `@Splat` to work correctly, your type must:
///
/// 1. Have a stored property of the specified struct type (default: `arguments` of type `Arguments`)
/// 2. Have a nested struct with stored properties (default: `Arguments`)
/// 3. Have an initializer that accepts the struct value
///
/// - Parameters:
///   - propertyName: The name of the property to splat from (default: "arguments")
///   - structName: The name of the nested struct to splat (default: "Arguments")
@attached(member, names: arbitrary)
public macro Splat(
    propertyName: String = "arguments",
    structName: String = "Arguments"
) = #externalMacro(module: "SplatPlugin", type: "SplatMacro")
