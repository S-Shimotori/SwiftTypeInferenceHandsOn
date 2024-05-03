import SwiftcBasic
import SwiftcType

extension ConstraintSystem {
    // ref: simplifyConstraint at CSSimplify.cpp
    public func simplify(constraint: Constraint) -> SolveResult {
        let options = MatchOptions()
        switch constraint {
        case .bind(left: let left, right: let right, conversion: let conversion),
             .conversion(left: let left, right: let right, conversion: let conversion):
            let kind = constraint.kind.toMatchKind()!
            
            if let conversion = conversion {
                return simplify(kind: kind,
                                left: left, right: right,
                                conversion: conversion,
                                options: options)
            }

            return matchTypes(kind: kind,
                              left: left, right: right,
                              options: options)
        case .applicableFunction(left: let left, right: let right):
            return simplifyApplicableFunctionConstraint(left: left, right: right,
                                                        options: options)
        case .bindOverload(left: let left, choice: let choice, location: let location):
            resolveOverload(boundType: left, choice: choice, location: location)
            return .solved
        case .disjunction:
            return .ambiguous
        }
    }
    
    public func simplify(kind: Constraint.MatchKind,
                         left leftType: Type,
                         right rightType: Type,
                         conversion: Conversion,
                         options: MatchOptions) -> SolveResult {
        switch _simplify(kind: kind,
                         left: leftType, right: rightType,
                         conversion: conversion,
                         options: options) {
        case .solved:
            let rel = TypeConversionRelation(conversion: conversion, left: leftType, right: rightType)
            typeConversionRelations.append(rel)
            return .solved
        case .ambiguous: return .ambiguous
        case .failure: return .failure
        }
    }
    
    /// ```
    /// type1 <conv VToO> type2 >>
    ///     type1 <conv> type2.wrapped
    /// ```
    /// ```
    /// type1 <conv OToO> type2 >>
    ///     type1.wrapped <conv> type2.wrapped
    /// ```
    /// [規則集](https://github.com/omochi/SwiftTypeInferenceHandsOn/blob/master/Docs/rules.md)
    private func _simplify(kind: Constraint.MatchKind,
                           left leftType: Type,
                           right rightType: Type,
                           conversion: Conversion,
                           options: MatchOptions) -> SolveResult
    {
        precondition(!(leftType is TypeVariable))
        precondition(!(rightType is TypeVariable))
        
        let subOptions = decompositionOptions(options)
        
        switch conversion {
        case .deepEquality:
            return matchDeepEqualityTypes(left: leftType, right: rightType,
                                          options: options)
        case .valueToOptional:
            // <Q09 hint="see optionalToOptional" />
            guard let rightType = rightType as? OptionalType else {
                return .failure
            }
            return matchTypes(kind: kind,
                              left: (leftType as? OptionalType)?.wrapped ?? leftType,
                              right: rightType.wrapped,
                              options: options)
            
            return .failure
        case .optionalToOptional:
            if let leftType = leftType as? OptionalType,
                let rightType = rightType as? OptionalType
            {
                return matchTypes(kind: kind,
                                  left: leftType.wrapped,
                                  right: rightType.wrapped,
                                  options: subOptions)
            }
            return .failure
        }
    }
    
    /// - Parameters:
    ///   - lfn: A function type that represents a function application with a type of argument and a type of output.
    ///   - right: A function type or a type variable representing an expected type of the function application.
    ///   - options:
    /// - Returns:
    ///
    /// ref: simplifyApplicableFnConstraint at [CSSimplify.cpp](https://github.com/apple/swift/blob/main/lib/Sema/CSSimplify.cpp)
    ///
    /// ```
    /// (arg) -> ret <appfn> callee >>
    ///     if callee is typevar:
    ///         *ambiguous
    ///     if callee is function:
    ///         arg <conv> callee.param
    ///         ret <bind> callee.result
    ///     *failure
    /// ```
    /// [規則集](https://github.com/omochi/SwiftTypeInferenceHandsOn/blob/master/Docs/rules.md)
    ///
    /// \<app fn>解決の変更 \
    /// `(A) -> B` \<app fn> `(C) -> D` >> \
    /// `A` \<conv> `C` \
    /// `B` \<bind> `D` \
    /// 引数に渡すときに暗黙変換を認める。 \
    /// [Swiftの型推論アルゴリズム(1)](https://speakerdeck.com/omochi/swiftfalsexing-tui-lun-arugorizumu-1?slide=76)
    public func simplifyApplicableFunctionConstraint(left lfn: FunctionType,
                                                     right: Type,
                                                     options: MatchOptions) -> SolveResult
    {
        func ambiguous() -> SolveResult {
            if options.generateConstraintsWhenAmbiguous {
                let c = Constraint.applicableFunction(left: lfn, right: right)
                _addConstraintEntry(ConstraintEntry(c))
                return .solved
            }
            return .ambiguous
        }
        
        let right = simplify(type: right)
        
        if let _ = right as? TypeVariable {
            return ambiguous()
        }
        
        guard let rfn = right as? FunctionType else {
            return .failure
        }
        
        var subOpts = options
        subOpts.generateConstraintsWhenAmbiguous = true
        
        // <Q08 hint="think about semantics of appfn consts" />
        guard matchTypes(kind: .conversion, left: lfn.parameter, right: rfn.parameter, options: subOpts) == .solved,
              matchTypes(kind: .bind, left: lfn.result, right: rfn.result, options: subOpts) == .solved else {
            return .failure
        }
        
        return .solved
    }
    
    /// 現在活性化している制約を可能な限り簡約化する事を繰り返す。
    /// - Returns: `false` if there is a constraint that this constraint system cannot solve.
    ///
    /// ref: simplify at [CSSolver.cpp](https://github.com/apple/swift/blob/main/lib/Sema/CSSolver.cpp)
    public func simplify() -> Bool {
        while true {
            if isFailed {
                return false
            }
            
            guard let cs = (constraints.first { $0.isActive }) else {
                break
            }
            cs.isActive = false
            
            switch simplify(constraint: cs.constraint) {
            case .failure:
                _removeConstraintEntry(cs)
                fail(constraint: cs)
                
            case .ambiguous:
                break
                
            case .solved:
                _removeConstraintEntry(cs)
            }
        }
        
        return true
    }
}
