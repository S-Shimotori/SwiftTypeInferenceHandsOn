import SwiftcBasic

public final class ConstraintEntry : IdentityEquatable, CustomStringConvertible {
    public let constraint: Constraint
    /// A boolean value that indicates whether this constraint is active or not.
    ///
    /// > 制約ワークリスト:
    /// > 先の手順において、\<app fn>制約の再試行が生じた。
    /// > この再試行を、都度全ての制約に対して行うと効率が悪い。
    /// > そこで、置換表に変化が生じた瞬間、影響を受けうる制約を検索してフラグを立てる。
    /// > コンパイラ内部では、このフラグが立っている事をactiveと呼ぶ。 \
    /// > [Swiftの型推論アルゴリズム(1)](https://speakerdeck.com/omochi/swiftfalsexing-tui-lun-arugorizumu-1?slide=70)
    public var isActive: Bool
    
    public init(_ constraint: Constraint) {
        self.constraint = constraint
        self.isActive = false
    }
    
    public var description: String {
        constraint.description
    }
}
