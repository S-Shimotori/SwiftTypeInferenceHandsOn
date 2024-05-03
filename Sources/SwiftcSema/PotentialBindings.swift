import SwiftcType

/// ref: PotentialBindings at [CSBindings.h](https://github.com/apple/swift/blob/main/include/swift/Sema/CSBindings.h)
public struct PotentialBindings : CustomStringConvertible {
    public var typeVariable: TypeVariable
    /// The set of potential bindings.
    public var bindings: [PotentialBinding]
    public var sources: [Constraint]
    
    public init(typeVariable: TypeVariable,
                bindings: [PotentialBinding] = [],
                sources: [Constraint] = [])
    {
        self.typeVariable = typeVariable
        self.bindings = bindings
        self.sources = sources
    }
    
    public var description: String {
        let bindingsStr: String =
            "[" + bindings.map { $0.description }.joined(separator: ", ") + "]"
    
        return "\(typeVariable) <- \(bindingsStr)"
    }
    
    // allowJoinMeet should be attributed in each PB?
    /// - Parameters:
    ///   - binding:
    ///
    /// Add a potential binding to the list of bindings, coalescing supertype bounds when we are able to compute the meet. \
    /// ref: addPotentialBinding at [CSBindings.cpp](https://github.com/apple/swift/blob/main/lib/Sema/CSBindings.cpp)
    ///
    /// supertype境界のjoin \
    /// 変換の型境界を列挙する再、supertype境界同士はjoinされて、共通のsupertypeの境界に丸められる。 \
    /// [Swiftの型推論アルゴリズム(1)](https://speakerdeck.com/omochi/swiftfalsexing-tui-lun-arugorizumu-1)
    public mutating func add(_ binding: PotentialBinding) {
        let bindTy = binding.type
        // unresolved type, unbound generic type, allowJoinMeet...
        if binding.kind == .supertype,
            bindTy.typeVariables.isEmpty
        {
            if let index = (bindings.firstIndex { $0.kind == .supertype }) {
                var lastBinding = bindings[index]
                if let joinedTy = lastBinding.type.join(bindTy),
                    !(joinedTy is TopAnyType)
                {
                    var does = true
                    if let optTy = joinedTy as? OptionalType,
                        optTy.wrapped is TopAnyType
                    {
                        does = false
                    }
                    
                    if does {
                        lastBinding.type = joinedTy
                        bindings[index] = lastBinding
                        return
                    }
                }
            }
        }
        
        // lvalue
        
        guard isViableBinding(binding) else {
            return
        }
        
        bindings.append(binding)
    }
    
    private func isViableBinding(_ binding: PotentialBinding) -> Bool {
        // I still have a question
        // https://github.com/apple/swift/pull/19076
        return true
    }
}
