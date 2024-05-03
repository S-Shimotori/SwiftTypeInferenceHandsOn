import SwiftcType

/// A potential binding from the type variable to a particular type,
/// along with information that can be used to construct related
/// bindings, e.g., the supertypes of a given type. \
/// ref: PotentialBinding at [CSBindings.h](https://github.com/apple/swift/blob/main/include/swift/Sema/CSBindings.h)
public struct PotentialBinding : CustomStringConvertible {
    /// The kind of bindings that are permitted. \
    /// ref: AllowedBindingKind at [CSBindings.h](https://github.com/apple/swift/blob/main/include/swift/Sema/CSBindings.h)
    public enum Kind {
        /// Only the exact type.
        case exact
        /// Supertypes of the specified type.
        case supertype
        /// Subtypes of the specified type.
        case subtype
    }

    /// The kind of bindings permitted.
    public var kind: Kind
    /// The type to which the type variable can be bound.
    public var type: Type
    public var source: Constraint.Kind
    
    public init(kind: Kind,
                type: Type,
                source: Constraint.Kind)
    {
        self.kind = kind
        self.type = type
        self.source = source
    }
    
    public var description: String {
        func kindStr() -> String {
            switch kind {
            case .exact: return "exact"
            case .subtype: return "subtype of"
            case .supertype: return "supertype of"
            }
        }
        
        return "\(kindStr()) \(type)"
    }
    
}
