import SwiftcBasic
import SwiftcType

/// A declaration of variable.
public final class VariableDecl : ValueDecl {
    public unowned let source: SourceFile
    public let sourceRange: SourceRange
    public weak var parentContext: DeclContext?
    public var name: String
    /// An expression that gives an initial value or object to this variable.
    public var initializer: Expr?
    /// An explicit type annotation for this variable.
    public var typeAnnotation: Type?
    public var type: Type?
    public init(source: SourceFile,
                sourceRange: SourceRange,
                parentContext: DeclContext,
                name: String,
                initializer: Expr?,
                typeAnnotation: Type?)
    {
        self.source = source
        self.sourceRange = sourceRange
        self.name = name
        self.initializer = initializer
        self.typeAnnotation = typeAnnotation
    }
    
    public var interfaceType: Type? { type }
    
    public var descriptionPartsTail: [String] {
        var parts: [String] = []
        
        let type = self.typeAnnotation ?? self.type
        parts.append("type=\"\(str(type))\"")
        
        parts += ValueDecls.descriptionParts(self)
        
        return parts
    }
    
    public func accept<V>(visitor: V) throws -> V.VisitResult where V : ASTVisitor {
        try visitor.visit(self)
    }

    public func resolveInSelf(name: String) -> [ValueDecl] {
        var decls: [ValueDecl] = []
        if self.name == name {
            decls.append(self)
        }
        return decls
    }
}
