import SwiftcAST

/// A set of callbacks for each step of type checking for expressions.
///
/// ref: ExprTypeCheckListener at [TypeChecker.h](https://github.com/apple/swift/blob/main/lib/Sema/TypeChecker.h)
public struct ExprTypeCheckCallbacks {
    /// A callback that is called after constraints are generated.
    /// - Parameters:
    ///   - ConstraintSystem:
    ///   - Expr: The expression to be checked.
    ///   - DeclContext:
    /// - Throws:
    /// - Returns:
    public var didGenerateConstraints: ((ConstraintSystem, Expr, DeclContext) throws -> Void)?
    /// A callback that updates the expression after a solution is found.
    /// - Parameters:
    ///   - ConstraintSystem:
    ///   - ConstraintSystem.Solution:
    ///   - Expr: The type checked expression.
    ///   - DeclContext:
    /// - Throws:
    /// - Returns:
    public var didFoundSolution: ((ConstraintSystem, ConstraintSystem.Solution, Expr, DeclContext) throws -> Expr)?
    /// A callback that updates the expression after applying a solution.
    /// - Parameters:
    ///   - ConstraintSystem:
    ///   - ConstraintSystem.Solution:
    ///   - Expr: The type checked expression.
    ///   - DeclContext:
    /// - Throws:
    /// - Returns:
    public var didApplySolution: ((ConstraintSystem, ConstraintSystem.Solution, Expr, DeclContext) throws -> Expr)?
}
