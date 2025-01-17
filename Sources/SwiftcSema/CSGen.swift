import SwiftcBasic
import SwiftcType
import SwiftcAST

/// A visitor that generates constraints from visited AST nodes.
///
/// 制約の生成 \
/// [型推論ハンズオン](https://speakerdeck.com/omochi/xing-tui-lun-hanzuon?slide=9)
public final class ConstraintGenerator : ASTVisitor {
    public typealias VisitResult = Type
    
    private let cts: ConstraintSystem
    
    public init(constraintSystem: ConstraintSystem) {
        self.cts = constraintSystem
    }
    
    public func preWalk(node: ASTNode, context: DeclContext) throws -> PreWalkResult<ASTNode> {
        .continue(node)
    }
    
    public func postWalk(node: ASTNode, context: DeclContext) throws -> WalkResult<ASTNode> {
        let ty = try startVisiting(node)
        cts.setASTType(for: node, ty)
        return .continue(node)
    }
    
    public func visit(_ node: SourceFile) throws -> Type {
        throw MessageError("source")
    }
    
    public func visit(_ node: FunctionDecl) throws -> Type {
        throw MessageError("function")
    }
    
    /// - Returns: A type annotated in the declaration, or a new type variable if there is no annotation.
    ///
    /// ```
    /// init <conv> var
    /// ```
    /// [規則集](https://github.com/omochi/SwiftTypeInferenceHandsOn/blob/master/Docs/rules.md)
    public func visit(_ node: VariableDecl) throws -> Type {
        if let ta = node.typeAnnotation {
            return ta
        }
        
        return cts.createTypeVariable()
    }
    
    /// - Returns: A type variable that refers to a type of the expression.
    ///
    /// ```
    /// (argument) -> self <appfn> callee
    /// ```
    /// [規則集](https://github.com/omochi/SwiftTypeInferenceHandsOn/blob/master/Docs/rules.md)
    ///
    /// `apply` >> \
    /// `(arg) -> self.type` \<app fn> `callee` \
    /// `callee` が関数型をしているとは限らないので、いったん\<app fn>制約として表現して後回しにする。 \
    /// [Swiftの型推論アルゴリズム(1)](https://speakerdeck.com/omochi/swiftfalsexing-tui-lun-arugorizumu-1?slide=61)
    public func visit(_ node: CallExpr) throws -> Type {
        let callee = try cts.astTypeOrThrow(for: node.callee)
        let arg = try cts.astTypeOrThrow(for: node.argument)
        
        let tv = cts.createTypeVariable()
        
        // <Q07 hint="call addConstraint" />
        cts.addConstraint(kind: .applicableFunction, left: FunctionType(parameter: arg, result: tv), right: callee)
        
        return tv
    }
    
    /// - Returns: A function type that represents the closure.
    ///
    /// ```
    /// body.last <conv> result
    ///     where body.count == 1
    /// ```
    /// [規則集](https://github.com/omochi/SwiftTypeInferenceHandsOn/blob/master/Docs/rules.md)
    ///
    /// `closure` >> \
    /// `self.type.return` \<bind> `body` \
    /// クロージャ本文が1文の時だけ。複数文の時は別の問題として後で処理される。 \
    /// [Swiftの型推論アルゴリズム(1)](https://speakerdeck.com/omochi/swiftfalsexing-tui-lun-arugorizumu-1?slide=42)
    public func visit(_ node: ClosureExpr) throws -> Type {
        let paramTy = try cts.astTypeOrThrow(for: node.parameter)
        
        func resultTy_() -> Type {
            if let ret = node.returnType {
                return ret
            }
            return cts.createTypeVariable()
        }
        
        let resultTy = resultTy_()

        let closureTy = FunctionType(parameter: paramTy, result: resultTy)
        
        let bodyTy = try cts.astTypeOrThrow(for: node.body.last!)
        
        // <Q06 hint="call addConstraint" />
        cts.addConstraint(kind: .conversion, left: bodyTy, right: resultTy)
        
        return closureTy
    }
    
    public func visit(_ node: UnresolvedDeclRefExpr) throws -> Type {
        throw MessageError("unresolved")
    }
    
    /// - Returns: A type variable that refers to a type of the declaration.
    ///
    /// ```
    /// self <bind> target
    /// ```
    /// [規則集](https://github.com/omochi/SwiftTypeInferenceHandsOn/blob/master/Docs/rules.md)
    public func visit(_ node: DeclRefExpr) throws -> Type {
        let tv = cts.createTypeVariable()
        
        let choice = OverloadChoice(decl: node.target)

        cts.resolveOverload(boundType: tv, choice: choice, location: node)

        return tv
    }
    
    /// ```
    /// disjunction(
    ///     self <bind> targets[0],
    ///     self <bind> targets[1],
    ///     ...
    /// )
    /// ```
    /// [規則集](https://github.com/omochi/SwiftTypeInferenceHandsOn/blob/master/Docs/rules.md)
    public func visit(_ node: OverloadedDeclRefExpr) throws -> Type {
        let tv = cts.createTypeVariable()
        
        var cs: [Constraint] = []
        for target in node.targets {
            let choice = OverloadChoice(decl: target)
            cs.append(.bindOverload(left: tv, choice: choice, location: node))
        }
        cts.addDisjunctionConstraint(cs)
        return tv
    }
    
    /// - Returns: An integer type.
    public func visit(_ node: IntegerLiteralExpr) throws -> Type {
        return PrimitiveType.int
    }
    
    public func visit(_ node: InjectIntoOptionalExpr) throws -> Type {
        throw MessageError("invalid")
    }
    
    public func visit(_ node: BindOptionalExpr) throws -> Type {
        // OptionalObject constraint
        unimplemented()
    }
    
    public func visit(_ node: OptionalEvaluationExpr) throws -> Type {
        // subExpr conv .some(subExpr)
        unimplemented()
    }
    
}

extension ConstraintSystem {
    // ref: generateConstraints at CSGen.cpp
    public func generateConstraints(expr: Expr,
                                    context: DeclContext) throws {
        let gen = ConstraintGenerator(constraintSystem: self)
        
        try expr.walk(context: context,
                      preWalk: gen.preWalk,
                      postWalk: gen.postWalk)
    }
}
