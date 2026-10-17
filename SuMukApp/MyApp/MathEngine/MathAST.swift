import Foundation

/// Expression tree for SuMuk Script formulas. Ported from MathSketch's MathEngine.
nonisolated indirect enum MathExpr: Equatable, Sendable {
    case number(Double)
    case variable(String)
    case negate(MathExpr)
    case binary(MathBinaryOp, MathExpr, MathExpr)
    case call(String, [MathExpr])

    /// Free variable names referenced by this expression (functions excluded).
    var variables: Set<String> {
        switch self {
        case .number: return []
        case .variable(let n): return [n]
        case .negate(let e): return e.variables
        case .binary(_, let l, let r): return l.variables.union(r.variables)
        case .call(_, let args): return args.reduce(into: Set<String>()) { $0.formUnion($1.variables) }
        }
    }
}

nonisolated enum MathBinaryOp: Equatable, Sendable {
    case add, subtract, multiply, divide, power
    /// Comparisons evaluate to 1 (true) or 0 (false); used by `points … when …` and `if(c, a, b)`.
    case greater, less, greaterEqual, lessEqual
}

/// A user definition from a `where` section: `name(params) = body` (or a constant when `params` is empty).
nonisolated struct FunctionDefinition: Equatable, Sendable {
    let name: String
    let parameters: [String]
    let body: MathExpr
}
