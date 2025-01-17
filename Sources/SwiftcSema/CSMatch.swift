import SwiftcBasic
import SwiftcType

extension ConstraintSystem {
    /// - Parameters:
    ///   - kind: A kind of constraint between the given two types.
    ///   - leftType: A type under a constraint.
    ///   - rightType: A type that appears in a constraint.
    ///   - options:
    /// - Returns: The result of matching.
    ///
    /// ref: matchTypes at [CSSimplify.cpp](https://github.com/apple/swift/blob/main/lib/Sema/CSSimplify.cpp)
    ///
    /// ```
    /// fixed <bind> typevar >>
    ///     assign(typevar, fixed)
    /// ```
    /// ```
    /// typevar1 <bind> typevar2 >>
    ///     merge(typevar1, typevar2)
    /// ```
    /// [規則集](https://github.com/omochi/SwiftTypeInferenceHandsOn/blob/master/Docs/rules.md)
    public func matchTypes(kind: Constraint.MatchKind,
                           left leftType: Type,
                           right rightType: Type,
                           options: MatchOptions) -> SolveResult
    {
        let leftType = simplify(type: leftType)
        let rightType = simplify(type: rightType)
        
        func ambiguous() -> SolveResult {
            if options.generateConstraintsWhenAmbiguous {
                let c = Constraint(kind: kind.asKind(), left: leftType, right: rightType)
                _addConstraintEntry(ConstraintEntry(c))
                return .solved
            }
            return .ambiguous
        }
        
        let leftVarOrNone = leftType as? TypeVariable
        let rightVarOrNone = rightType as? TypeVariable
        
        if leftVarOrNone != nil || rightVarOrNone != nil {
            if let leftVar = leftVarOrNone,
                let rightVar = rightVarOrNone
            {
                if leftVar == rightVar {
                    return .solved
                }
            }
            
            switch kind {
            case .bind:
                if let leftVar = leftVarOrNone,
                    let rightVar = rightVarOrNone
                {
                    mergeEquivalence(type1: leftVar, type2: rightVar)
                    return .solved
                }
                
                let variable: TypeVariable
                let fixedType: Type
                if let leftVar = leftVarOrNone {
                    variable = leftVar
                    fixedType = rightType
                } else {
                    variable = rightVarOrNone!
                    fixedType = leftType
                }
                
                return matchTypesBind(typeVariable: variable,
                                      fixedType: fixedType)
            case .conversion:
                return ambiguous()
            }
        }
        
        return matchFixedTypes(kind: kind,
                               left: leftType,
                               right: rightType,
                               options: options)
    }
    
    /// ref: matchTypes at [CSSimplify.cpp](https://github.com/apple/swift/blob/main/lib/Sema/CSSimplify.cpp)
    private func matchTypesBind(typeVariable: TypeVariable,
                                fixedType: Type) -> SolveResult
    {
        precondition(typeVariable.isRepresentative(bindings: bindings))
        
        if typeVariable.occurs(in: fixedType) {
            return .failure
        }
        
        assignFixedType(for: typeVariable, fixedType)
        return .solved
    }
    
    internal func decompositionOptions(_ options: MatchOptions) -> MatchOptions {
        var options = options
        options.generateConstraintsWhenAmbiguous = true
        return options
    }
    
    /// Tries to match a given fixed type with another type.
    /// - Parameters:
    ///   - kind: A kind of constraint between the given two types.
    ///   - leftType: A type under a constraint.
    ///   - rightType: A type that appears in a constraint.
    ///   - options:
    /// - Returns: The result of matching.
    /// - Precondition: Neither `leftType` nor `rightType` should be type variables.
    ///
    /// ```
    /// type1 <conv> type2
    ///     where type2 is more optional than type1 >>
    ///     type1 <conv VToO> type2
    /// ```
    /// ```
    /// type1 <conv> type2
    ///     where type1 and type2 are optional >>
    ///     type1 <conv DEQ> type2
    ///     type1 <conv OToO> type2
    /// ```
    /// [規則集](https://github.com/omochi/SwiftTypeInferenceHandsOn/blob/master/Docs/rules.md)
    ///
    /// ref: matchTypes at [CSSimplify.cpp](https://github.com/apple/swift/blob/main/lib/Sema/CSSimplify.cpp)
    private func matchFixedTypes(kind: Constraint.MatchKind,
                                 left leftType: Type,
                                 right rightType: Type,
                                 options: MatchOptions) -> SolveResult
    {
        precondition(!(leftType is TypeVariable))
        precondition(!(rightType is TypeVariable))
        
        var conversions: [Conversion] = []
        
        if let leftType = leftType as? PrimitiveType,
            let rightType = rightType as? PrimitiveType
        {
            if leftType.name == rightType.name {
                conversions.append(.deepEquality)
            }
        }
        
        if let leftType = leftType as? FunctionType,
            let rightType = rightType as? FunctionType
        {
            return matchFunctionTypes(kind: kind,
                                      left: leftType,
                                      right: rightType,
                                      options: options)
        }
        
        if let leftType = leftType as? OptionalType,
            let rightType = rightType as? OptionalType
        {
            conversions.append(.deepEquality)
        }
        
        switch kind {
        case .conversion:
            if leftType is OptionalType,
                rightType is OptionalType
            {
                conversions.append(.optionalToOptional)
            }
            
            let leftOptNum = leftType.lookThroughAllOptionals().count
            let rightOptNum = rightType.lookThroughAllOptionals().count
            if leftOptNum < rightOptNum {
                conversions.append(.valueToOptional)
            }
        case .bind: break
        }
        
        
        func subKind(_ kind: Constraint.MatchKind, conversion: Conversion) -> Constraint.MatchKind {
            if conversion == .deepEquality { return .bind }
            else { return kind }
        }
        
        // 無いなら無理
        if conversions.isEmpty {
            return .failure
        }

        // 1つなら即時投入
        if conversions.count == 1 {
            let conversion = conversions[0]
            return simplify(kind: subKind(kind, conversion: conversion),
                            left: leftType, right: rightType,
                            conversion: conversion,
                            options: options)
        }

        // 2つ以上ならdisjunction
        let convCs: [Constraint] = conversions.map { (conv) in
            Constraint(kind: subKind(kind, conversion: conv),
                       left: leftType, right: rightType,
                       conversion: conv)
        }
        
        addDisjunctionConstraint(convCs)
        
        return .solved
    }
    
    /// Tries to match a given function type with another one.
    /// - Parameters:
    ///   - kind:
    ///   - leftType: A function type under a constraint.
    ///   - rightType: A function type that appears in a constraint.
    ///   - options: Match options.
    /// - Returns: The result of matching.
    ///
    /// ref: matchFunctionTypes at [CSSimplify.cpp]( https://github.com/apple/swift/blob/main/lib/Sema/CSSimplify.cpp ).
    ///
    /// ```
    /// (type1) -> type2 <bind> (type3) -> type4 >>
    ///     type1 <bind> type3
    ///     type2 <bind> type4
    /// ```
    /// ```
    /// (type1) -> type2 <conv> (type3) -> type4 >>
    /// type3 <conv> type1 // contravariance
    /// type2 <conv> type4 // covariance
    /// ```
    /// [規則集](https://github.com/omochi/SwiftTypeInferenceHandsOn/blob/master/Docs/rules.md)
    ///
    /// > 関数型同士の割当:
    /// > `(type1) -> type2` \<bind> `(type3) -> type4` >> \
    /// > `type1` \<bind> `type3` \
    /// > `type2` \<bind> `type4` \
    /// > このような、新たに細かい規則に分解する場合を簡約規則（simplify）と呼ぶ。 \
    /// > [Swiftの型推論アルゴリズム(1)](https://speakerdeck.com/omochi/swiftfalsexing-tui-lun-arugorizumu-1?slide=34)
    private func matchFunctionTypes(kind: Constraint.MatchKind,
                                    left leftType: FunctionType,
                                    right rightType: FunctionType,
                                    options: MatchOptions) -> SolveResult
    {
        let leftArg = leftType.parameter
        let rightArg = rightType.parameter
        
        let leftRet = leftType.result
        let rightRet = rightType.result
        
        let subKind: Constraint.MatchKind
        
        switch kind {
        case .bind: subKind = .bind
        case .conversion: subKind = .conversion
        }
        
        let subOptions = decompositionOptions(options)

        // <Q02 hint="match arg and ret" />
        let matchArgTypes = matchTypes(kind: subKind, left: rightArg, right: leftArg, options: subOptions)
        let matchRetTypes = matchTypes(kind: subKind, left: leftRet, right: rightRet, options: subOptions)
        switch (matchArgTypes, matchRetTypes) {
        case (.solved, .solved):
            break
        case (.ambiguous, _), (_, .ambiguous):
            // generateConstraintsWhenAmbiguous = true
            preconditionFailure()
        case (.failure, _), (_, .failure):
            return .failure
        }
        
        return .solved
    }
    
    /// Tries deep equality matching between a given type with another one.
    /// - Parameters:
    ///   - leftType: A type under a constraint.
    ///   - rightType: A type that appears in a constraint.
    ///   - options: Match options.
    /// - Returns: The result of matching.
    ///
    /// ref: matchDeepEqualityTypes at [CSSimplify.cpp]( https://github.com/apple/swift/blob/main/lib/Sema/CSSimplify.cpp ).
    ///
    /// ```
    /// primitive1 <bind> primitive2 >>
    ///     if primitive1 == primitive2:
    ///         *solved
    ///     *failure
    /// ```
    /// ```
    /// primitive1 <conv> primitive2 >>
    ///     if primitive1 == primitive2:
    ///         *solved
    ///     *failure
    /// ```
    /// [規則集](https://github.com/omochi/SwiftTypeInferenceHandsOn/blob/master/Docs/rules.md)
    internal func matchDeepEqualityTypes(left leftType: Type,
                                         right rightType: Type,
                                         options: MatchOptions) -> SolveResult
    {
        let subOptions = decompositionOptions(options)
        
        // <Q01 hint="consider primitive type" />
        if let leftType = leftType as? PrimitiveType,
        let rightType = rightType as? PrimitiveType
        {
            // ``PrimitiveType`` is a structure that has only ``PrimitiveType/name``.
            // `isEqual(_:)` works exactly like `leftType.name == rightType.name`.
            return leftType.isEqual(rightType) ? .solved : .failure
        }
        
        if let leftType = leftType as? OptionalType,
        let rightType = rightType as? OptionalType
        {
            return matchTypes(kind: .bind,
                              left: leftType.wrapped,
                              right: rightType.wrapped,
                              options: subOptions)
        }
        
        return .failure
    }
}
