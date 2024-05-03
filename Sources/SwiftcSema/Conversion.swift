/// It's common for there to be multiple potential conversions that can apply between two types,
/// e.g., given class types A and B, there might be a superclass conversion from A to B or there might be a user-defined conversion from A to B.
/// The solver may need to explore both paths. \
/// [swift/include/swift/Sema/Constraint.h](https://github.com/apple/swift/blob/main/include/swift/Sema/Constraint.h)
///
/// `Optional`の変換 \
/// [Swiftの型推論アルゴリズム(1)](https://speakerdeck.com/omochi/swiftfalsexing-tui-lun-arugorizumu-1?slide=109)
public enum Conversion : CustomStringConvertible, Hashable {
    /// Deep equality comparison. \
    /// [swift/include/swift/Sema/Constraint.h](https://github.com/apple/swift/blob/main/include/swift/Sema/Constraint.h)
    ///
    /// `A == B`、コスト無し。 \
    /// [Swiftの型推論アルゴリズム(1)](https://speakerdeck.com/omochi/swiftfalsexing-tui-lun-arugorizumu-1?slide=109)
    case deepEquality
    /// `T -> U?` value to optional conversion (or to implicitly unwrapped optional). \
    /// [swift/include/swift/Sema/Constraint.h](https://github.com/apple/swift/blob/main/include/swift/Sema/Constraint.h)
    ///
    /// `A <c C`; `.some(C) == B`、コスト有り。 \
    /// [Swiftの型推論アルゴリズム(1)](https://speakerdeck.com/omochi/swiftfalsexing-tui-lun-arugorizumu-1?slide=109)
    case valueToOptional
    /// `T? -> U?` optional to optional conversion (or unchecked to unchecked). \
    /// [swift/include/swift/Sema/Constraint.h](https://github.com/apple/swift/blob/main/include/swift/Sema/Constraint.h)
    ///
    /// `A == .some(C)`; `C <c D`;  `.some(D) == B`、コスト無し。 \
    /// [Swiftの型推論アルゴリズム(1)](https://speakerdeck.com/omochi/swiftfalsexing-tui-lun-arugorizumu-1?slide=109)
    case optionalToOptional
    
    public var description: String {
        switch self {
        case .deepEquality: return "[deep equality]"
        case .valueToOptional: return "[value to optional]"
        case .optionalToOptional: return "[optional to optional]"
        }
    }
}
