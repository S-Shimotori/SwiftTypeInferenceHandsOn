/// > Visitorパターン:
/// > Visitorパターンは、データ構造内にさまざまな型のオブジェクトが多数あり、その一部またはすべてに何らかの操作を適用する場合に便利です。
/// > このパターンは、必要になる操作がすべて事前にわかっているわけではない場合に役立ちます。
/// > それぞれのオブジェクトの型に追加しなくても、新しい操作を追加できる柔軟性が得られるからです。
/// > 基本的な考え方は、何らかのイテレータを使ってVisitorオブジェクトをデータ構造の各ノードのもとに連れて行くというものです。
/// > 各ノードはそのVisitorを「受け入れ」、ノード・オブジェクトの内部データにアクセスできるようにします。
/// > 新しい機能が必要な場合は、新しいVisitorを書くだけで済みます。 \
/// > [Visitorデザイン・パターン徹底解説](https://www.oracle.com/webfolder/technetwork/jp/javamagazine/Java-SO18-VisitorDesignPattern-ja.pdf)
///
/// なお、これらの呼び出しはすべて1つのVisitorオブジェクトのメソッド呼び出しなので、
/// そのオブジェクトのインスタンス変数が「ずっと保持しておくデータの置き場所」に使えます。 \
/// [システムソフトウェア特論’17＃9 コンパイラコンパイラ](https://www.edu.cc.uec.ac.jp/~ka002689/sysof17/ohp09.pdf)
public protocol VisitorProtocol {
    associatedtype VisitTarget
    associatedtype VisitResult
    
    func startVisiting(_ target: VisitTarget) throws -> VisitResult
}

