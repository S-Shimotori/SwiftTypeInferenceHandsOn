import SwiftcBasic
import SwiftcType
import SwiftcAST

/// A visitor that applies a type inference solution to visited AST nodes.
public final class ConstraintSolutionApplier : ASTVisitor {
    public typealias VisitResult = ASTNode
    
    private let solution: ConstraintSystem.Solution
    
    public init(solution: ConstraintSystem.Solution)
    {
        self.solution = solution
    }
    
    public func preWalk(node: ASTNode, context: DeclContext) throws -> PreWalkResult<ASTNode> {
        .continue(node)
    }
    
    public func postWalk(node: ASTNode, context: DeclContext) throws -> WalkResult<ASTNode> {
        let node = try startVisiting(node)
        return .continue(node)
    }
    
    private func applyFixedType(expr: Expr) throws -> Expr {
        let ty = try solution.fixedTypeOrThrow(for: expr)
        expr.type = ty
        return expr
    }
    
    public func visit(_ node: SourceFile) throws -> ASTNode {
        node
    }
    
    public func visit(_ node: FunctionDecl) throws -> ASTNode {
        node
    }
    
    /// - Returns: The variable declaration node, which received type information.
    public func visit(_ node: VariableDecl) throws -> ASTNode {
        let ty = try solution.fixedTypeOrThrow(for: node)
        node.type = ty
        return node
    }
    
    /// - Returns: The call expression node, which received type information.
    public func visit(_ node: CallExpr) throws -> ASTNode {
        if let calleeTy = node.callee.type as? FunctionType {
            let paramTy = calleeTy.parameter
            node.argument = try solution.coerce(expr: node.argument, to: paramTy)
            return try applyFixedType(expr: node)
        }
        
        throw MessageError("unconsidered")
    }
    
    /// - Returns: The closure expression node, which received type information.
    public func visit(_ node: ClosureExpr) throws -> ASTNode {
        _ = try applyFixedType(expr: node)
        
        // <Q14 hint="see visitCallExpr" />
        if let returnType = node.returnType,
           let lastExpr = node.body.last as? Expr {
            node.body[node.body.endIndex - 1] = try solution.coerce(expr: lastExpr, to: returnType)
        }
        
        return node
    }
    
    public func visit(_ node: UnresolvedDeclRefExpr) throws -> ASTNode {
        throw MessageError("invalid node: \(node)")
    }
    
    public func visit(_ node: DeclRefExpr) throws -> ASTNode {
        return try applyFixedType(expr: node)
    }
    
    public func visit(_ node: OverloadedDeclRefExpr) throws -> ASTNode {
        return try applyFixedType(expr: node)
    }
    
    public func visit(_ node: IntegerLiteralExpr) throws -> ASTNode {
        return try applyFixedType(expr: node)
    }
    
    public func visit(_ node: InjectIntoOptionalExpr) throws -> ASTNode {
        return try applyFixedType(expr: node)
    }
    
    public func visit(_ node: BindOptionalExpr) throws -> ASTNode {
        return try applyFixedType(expr: node)
    }
    
    public func visit(_ node: OptionalEvaluationExpr) throws -> ASTNode {
        return try applyFixedType(expr: node)
    }
}

extension ConstraintSystem.Solution {
    /// ref: applySolution at [CSApply.cpp](https://github.com/apple/swift/blob/main/lib/Sema/CSApply.cpp)
    public func apply(to expr: Expr,
                      context: DeclContext,
                      constraintSystem: ConstraintSystem) throws -> Expr
    {
        let applier = ConstraintSolutionApplier(solution: self)
        switch try expr.walk(context: context,
                             preWalk: applier.preWalk,
                             postWalk: applier.postWalk)
        {
        case .continue(let node): return node as! Expr
        case .terminate: preconditionFailure()
        }
    }
    
    /// - Parameters:
    ///   - expr: An expression node to apply type coercion.
    ///   - toTy: What type the given expression is coerced to be.
    /// - Throws:
    /// - Returns: The expression node that is applied type coercion to.
    ///
    /// ref: coerceToType at [CSApply.cpp](https://github.com/apple/swift/blob/main/lib/Sema/CSApply.cpp)
    ///
    /// > Type coercion:
    /// > Type coercion is the automatic or implicit conversion of values from one data type to another (such as strings to numbers).
    /// > Type conversion is similar to type coercion because they both convert values from one data type to another with one key difference
    /// > — type coercion is implicit whereas type conversion can be either implicit or explicit. \
    /// > [Type coercion - MDN Web Docs Glossary](https://developer.mozilla.org/en-US/docs/Glossary/Type_coercion)
    public func coerce(expr: Expr, to toTy: Type) throws -> Expr {
        let fromTy = try expr.typeOrThrow()
        if fromTy == toTy {
            return expr
        }
        
        let convRelOrNone = typeConversionRelations.first { (rel) in
            rel.left == fromTy && rel.right == toTy
        }
        
        if let convRel = convRelOrNone {
            switch convRel.conversion {
            case .deepEquality:
                return expr
            case .valueToOptional:
                // <Q12 hint="use `InjectIntoOptionalExpr` and `coerce`" />
                guard let toTy = toTy as? OptionalType else {
                    throw MessageError("not optional")
                }
                var expr = try coerce(expr: expr, to: toTy.wrapped)
                expr = InjectIntoOptionalExpr(subExpr: expr, type: toTy)
                return expr
            case .optionalToOptional:
                return try coerceOptionalToOptional(expr: expr, to: toTy)
            }
        }
     
        switch toTy {
        case let toTy as OptionalType:
            if let _ = fromTy as? OptionalType {
                return try coerceOptionalToOptional(expr: expr, to: toTy)
            }
            
            var expr = try coerce(expr: expr, to: toTy.wrapped)
            expr = InjectIntoOptionalExpr(subExpr: expr, type: toTy)
            return expr
        default:
            break
        }
        
        // [TODO] function type coercion
        
        throw MessageError("unconsidered")
    }
    
    private func coerceOptionalToOptional(expr: Expr, to toType: Type) throws -> Expr {
        let fromType = try expr.typeOrThrow()
        guard let fromTy = fromType as? OptionalType else { throw MessageError("not optional") }
        guard let toTy = toType as? OptionalType else { throw MessageError("not optional") }
        
        do {
            let fromOpts = fromTy.lookThroughAllOptionals()
            let fromDepth = fromOpts.count
            let toOpts = toTy.lookThroughAllOptionals()
            let toDepth = toOpts.count
            let depthDiff = toDepth - fromDepth
            if depthDiff > 0,
                toOpts[depthDiff] == fromTy
            {
                var expr = expr
                for i in 0..<depthDiff {
                    let optTy = toOpts[depthDiff - i - 1]
                    expr = InjectIntoOptionalExpr(subExpr: expr, type: optTy)
                }
                return expr
            }
        }
        
        let bindExpr = BindOptionalExpr(subExpr: expr, type: fromTy.wrapped)
        
        var expr = try coerce(expr: bindExpr, to: toTy.wrapped)
        expr = InjectIntoOptionalExpr(subExpr: expr, type: toTy)
        expr = OptionalEvaluationExpr(subExpr: expr, type: toTy)
        return expr
    }
}
