import SwiftcBasic

public protocol ASTNode : AnyObject, CustomStringConvertible {
    // break retain cycle
    func dispose()
    
    var source: SourceFile { get }
    var sourceRange: SourceRange { get }
    
    /// 各ノードは `NodeVisitor` オブジェクト `v` を引数として受け取る `accept()` というメソッドだけを持っていて、
    /// その中で「 `v.visitノード種別()` 」というメソッドを呼び出すことで「自分の種別の処理」を呼び出します。 \
    /// [システムソフトウェア特論’17＃9 コンパイラコンパイラ](https://www.edu.cc.uec.ac.jp/~ka002689/sysof17/ohp09.pdf)
    func accept<V: ASTVisitor>(visitor: V) throws -> V.VisitResult
    
    var descriptionParts: [String] { get }
    var descriptionPartsTail: [String] { get }
}

extension ASTNode {
    public func dispose() {}
    
    public var sourceLocationRange: SourceLocationRange {
        sourceRange.toLocation(name: source.fileName, map: source.sourceLineMap)
    }
    
    public var descriptionPartsHead: String {
        let ty = type(of: self)
        return "\(ty)"
    }
    
    public var descriptionParts: [String] {
        [descriptionPartsHead] + descriptionPartsTail
    }
    
    public var description: String {
        "(" + descriptionParts.joined(separator: " ") + ")"
    }

}

public enum ASTNodes {
    public static func descriptionParts(_ node: ASTNode) -> [String] {
        var range = node.sourceLocationRange
        range.name = nil
        return ["range=\(range)"]
    }
}
