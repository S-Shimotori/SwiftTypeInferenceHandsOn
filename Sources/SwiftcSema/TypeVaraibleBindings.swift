import SwiftcType

/// A set of bindings applied to type variables.
public struct TypeVariableBindings {
    /**
     自分が代表の場合free, fixed、代表転送を持つ場合はtransfer
     */
    public enum Binding : Equatable {
        case free
        case fixed(Type)
        case transfer(TypeVariable)
        
        public static func ==(a: Binding, b: Binding) -> Bool {
            switch (a, b) {
            case (.free, .free): return true
            case (.free, _): return false
            case (.fixed(let a), .fixed(let b)): return a == b
            case (.fixed, _): return false
            case (.transfer(let a), .transfer(let b)): return a == b
            case (.transfer, _): return false
            }
        }
    }
    
    /// - Note: 型推論（type inference）とは、型（type）に型変数（type variable）を加えた上で、
    ///         全ての制約（constraint）を満たす型の置換表（substitution map）を求めることである。 \
    ///         [Swiftの型推論アルゴリズム(1)](https://speakerdeck.com/omochi/swiftfalsexing-tui-lun-arugorizumu-1?slide=20)
    public private(set) var map: [TypeVariable: Binding] = [:]

    public init() {}
    
    /// Returns a binding applied to a given type variable, or ``Binding/free`` if the type variable is not registered to ``map`` .
    public func binding(for variable: TypeVariable) -> Binding {
        map[variable] ?? .free
    }
    public mutating func setBinding(for variable: TypeVariable, _ binding: Binding) {
        map[variable] = binding
    }
    
    /// Merges two given type variables into the one whose ID is smaller.
    ///
    /// > 型変数と型変数の割当:
    /// > `typevar1` \<bind> `typevar2` >> \
    /// > `merge(typevar1, typevar2)` \
    /// > `typevar2` の置換先を `typevar1` にする。 \
    /// > 代表型変数のグループが統合される。 \
    /// > 便宜上、若い番号に代表を寄せていくことにする。 \
    /// > [Swiftの型推論アルゴリズム(1)](https://speakerdeck.com/omochi/swiftfalsexing-tui-lun-arugorizumu-1?slide=33)
    public mutating func merge(type1: TypeVariable,
                               type2: TypeVariable)
    {
        precondition(type1.isRepresentative(bindings: self))
        precondition(type1.fixedType(bindings: self) == nil)
        precondition(type2.isRepresentative(bindings: self))
        precondition(type2.fixedType(bindings: self) == nil)
        
        if type1 == type2 {
            return
        }
        
        // <Q03 hint="understand data structure" />
        // FIXME: Use correct terms
        let representativeType = type1 < type2 ? type1 : type2
        let sourceType = type1 < type2 ? type2 : type1
        var newBindings = [TypeVariable: Binding]()
        newBindings[sourceType] = .transfer(representativeType)
        for (type, element) in map {
            guard case let .transfer(typeVariable) = element,
                  typeVariable.isEqual(sourceType) else {
                continue
            }
            newBindings[type] = .transfer(representativeType)
        }
        map.merge(newBindings) { $1 }
    }
    
    /// Adds a binding to assign a given fixed type to a type variable.
    /// - Parameters:
    ///   - variable:
    ///   - type:
    ///
    /// 型変数と固定型の割当: \
    /// `typevar` \<bind> `fixed` >> `assign(typevar, fixed)` \
    /// `typevar` の置換先を `fixed` にする。 \
    /// [Swiftの型推論アルゴリズム(1)](https://speakerdeck.com/omochi/swiftfalsexing-tui-lun-arugorizumu-1?slide=32)
    public mutating func assign(variable: TypeVariable,
                                type: Type)
    {
        precondition(variable.isRepresentative(bindings: self))
        precondition(variable.fixedType(bindings: self) == nil)
        precondition(!(type is TypeVariable))
        
        map[variable] = .fixed(type)
    }
}

extension TypeVariable {
    /// A boolean value that indicates whether this type value itself is representative or not.
    ///
    /// ある型変数の置換を辿って最後に到達する型変数を、その型変数の代表型変数（representative）と呼ぶ。 \
    /// [Swiftの型推論アルゴリズム(1)](https://speakerdeck.com/omochi/swiftfalsexing-tui-lun-arugorizumu-1?slide=33)
    public func isRepresentative(bindings: TypeVariableBindings) -> Bool {
        representative(bindings: bindings) == self
    }
    
    public func representative(bindings: TypeVariableBindings) -> TypeVariable {
        switch bindings.binding(for: self) {
        case .free,
             .fixed:
            return self
        case .transfer(let rep):
            return rep
        }
    }
    
    /// - Note: 型変数ではない型を固定型（fixed type）と呼ぶことにする。  \
    ///         [Swiftの型推論アルゴリズム(1)](https://speakerdeck.com/omochi/swiftfalsexing-tui-lun-arugorizumu-1?slide=21)
    public func fixedType(bindings: TypeVariableBindings) -> Type? {
        switch bindings.binding(for: self) {
        case .free:
            return nil
        case .fixed(let ft):
            return ft
        case .transfer(let rep):
            return rep.fixedType(bindings: bindings)
        }
    }
    
    public func fixedOrRepresentative(bindings: TypeVariableBindings) -> Type {
        switch bindings.binding(for: self) {
        case .free:
            return self
        case .fixed(let ft):
            return ft
        case .transfer(let rep):
            return rep.fixedOrRepresentative(bindings: bindings)
        }
    }
    
    /// Returns type variables that are equivalent to this one under given bindings.
    /// - Parameters:
    ///   - bindings: A substitution map.
    /// - Returns: A set of type variables. It may includes this type itself.
    public func equivalentTypeVariables(bindings: TypeVariableBindings) -> Set<TypeVariable> {
        var ret = Set<TypeVariable>()
        for (tv, b) in bindings.map {
            switch b {
            case .free,
                 .fixed:
                if tv == self { ret.insert(tv) }
            case .transfer(let rep):
                if rep == self { ret.insert(tv) }
            }
        }
        return ret
    }
    
    public func isFree(bindings: TypeVariableBindings) -> Bool {
        switch bindings.binding(for: self) {
        case .free: return true
        case .fixed,
             .transfer: return false
        }
    }
}

extension Type {
    public func simplify(bindings: TypeVariableBindings) -> Type {
        transform { (type) in
            if let tv = type as? TypeVariable {
                var type = tv.fixedOrRepresentative(bindings: bindings)
                if !(type is TypeVariable) {
                    type = type.simplify(bindings: bindings)
                }
                return type
            }
             
            return nil
        }
    }
}
