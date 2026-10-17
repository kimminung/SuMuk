import Foundation

nonisolated struct MathEvaluationError: Error, CustomStringConvertible, Equatable, Sendable {
    let message: String
    var description: String { message }
}

/// Names the parser treats as function calls when followed by `(`.
nonisolated enum MathBuiltins {
    static let functions: Set<String> = [
        "sin", "cos", "tan", "asin", "acos", "atan", "atan2", "sinh", "cosh", "tanh",
        "exp", "ln", "log", "log10", "sqrt", "√", "abs", "sign", "floor", "ceil", "round",
        "min", "max", "clamp", "mod", "pow", "hypot", "step", "if",
    ]
    static let constants: [String: Double] = ["pi": .pi, "π": .pi, "e": M_E, "τ": 2 * .pi]
}

/// Compiles a `MathExpr` into a closure over a flat slot array so a family of thousands of
/// elements can be evaluated without dictionary lookups. User functions are inlined at compile
/// time (depth-limited, no recursion), which is also how the Metal transpiler will treat them.
nonisolated struct CompiledExpression: Sendable {
    typealias Body = @Sendable (inout [Double]) -> Double
    let body: Body
    let slotCount: Int

    func evaluate(_ slots: inout [Double]) -> Double { body(&slots) }
}

nonisolated struct ExpressionCompiler {
    struct Scope {
        var slots: [String: Int]
    }

    private var definitions: [String: FunctionDefinition]
    private var nextSlot: Int
    private var depth = 0

    /// - Parameters:
    ///   - variables: names available as slots (e.g. `k`, let-variables), in slot order.
    init(variables: [String], definitions: [String: FunctionDefinition]) {
        self.definitions = definitions
        self.nextSlot = variables.count
        self.rootScope = Scope(slots: Dictionary(uniqueKeysWithValues: variables.enumerated().map { ($1, $0) }))
    }
    private let rootScope: Scope

    mutating func compile(_ expr: MathExpr) throws -> CompiledExpression {
        let body = try compile(expr, scope: rootScope)
        return CompiledExpression(body: body, slotCount: nextSlot)
    }

    private mutating func compile(_ expr: MathExpr, scope: Scope) throws -> CompiledExpression.Body {
        switch expr {
        case .number(let v):
            return { _ in v }
        case .variable(let name):
            if let slot = scope.slots[name] { return { s in s[slot] } }
            if let c = MathBuiltins.constants[name] { return { _ in c } }
            if let def = definitions[name], def.parameters.isEmpty {
                return try compile(def.body, scope: rootScope)   // constant definition like φ = π(3−√5)
            }
            throw MathEvaluationError(message: "정의되지 않은 이름 '\(name)'")
        case .negate(let inner):
            let f = try compile(inner, scope: scope)
            return { s in -f(&s) }
        case .binary(let op, let l, let r):
            // Long sums (a 200-term DCT series, a Fourier series) parse as a left-deep chain; flatten them
            // so compilation and evaluation stay iterative instead of recursing once per term.
            if op == .add || op == .subtract {
                var terms: [(sign: Double, expr: MathExpr)] = []
                var node = expr
                while case .binary(let o, let left, let right) = node, o == .add || o == .subtract {
                    terms.append((o == .subtract ? -1 : 1, right))   // the right operand carries the operator's sign
                    node = left
                }
                terms.append((1, node))
                terms.reverse()
                if terms.count > 2 {
                    let compiled = try terms.map { t -> (Double, CompiledExpression.Body) in (t.sign, try compile(t.expr, scope: scope)) }
                    return { s in
                        var acc = 0.0
                        for (sign, f) in compiled { acc += sign * f(&s) }
                        return acc
                    }
                }
            }
            let a = try compile(l, scope: scope), b = try compile(r, scope: scope)
            switch op {
            case .add: return { s in a(&s) + b(&s) }
            case .subtract: return { s in a(&s) - b(&s) }
            case .multiply: return { s in a(&s) * b(&s) }
            case .divide: return { s in a(&s) / b(&s) }
            case .power:
                if case .number(let p) = r, p == p.rounded(), abs(p) <= 64 {
                    let n = Int(p)
                    return { s in Self.ipow(a(&s), n) }
                }
                return { s in pow(a(&s), b(&s)) }
            case .greater: return { s in a(&s) > b(&s) ? 1 : 0 }
            case .less: return { s in a(&s) < b(&s) ? 1 : 0 }
            case .greaterEqual: return { s in a(&s) >= b(&s) ? 1 : 0 }
            case .lessEqual: return { s in a(&s) <= b(&s) ? 1 : 0 }
            }
        case .call(let name, let argExprs):
            if let def = definitions[name] {
                guard def.parameters.count == argExprs.count else {
                    throw MathEvaluationError(message: "'\(name)'은(는) 인자를 \(def.parameters.count)개 받습니다")
                }
                guard depth < 16 else { throw MathEvaluationError(message: "'\(name)' 정의가 너무 깊게 중첩되었습니다(재귀 금지)") }
                let args = try argExprs.map { try compile($0, scope: scope) }
                var inner = rootScope
                var slotList: [Int] = []
                for p in def.parameters { inner.slots[p] = nextSlot; slotList.append(nextSlot); nextSlot += 1 }
                let paramSlots = slotList
                depth += 1; defer { depth -= 1 }
                let bodyFn = try compile(def.body, scope: inner)
                return { s in
                    for (i, slot) in paramSlots.enumerated() { s[slot] = args[i](&s) }
                    return bodyFn(&s)
                }
            }
            let args = try argExprs.map { try compile($0, scope: scope) }
            return try builtin(name, args)
        }
    }

    static func ipow(_ x: Double, _ n: Int) -> Double {
        if n == 0 { return 1 }
        var base = x, e = abs(n), r = 1.0
        while e > 0 { if e & 1 == 1 { r *= base }; base *= base; e >>= 1 }
        return n < 0 ? 1 / r : r
    }

    private func builtin(_ name: String, _ args: [CompiledExpression.Body]) throws -> CompiledExpression.Body {
        func need(_ n: Int) throws {
            guard args.count == n else { throw MathEvaluationError(message: "'\(name)'은(는) 인자를 \(n)개 받습니다") }
        }
        switch name {
        case "sin": try need(1); let a = args[0]; return { s in sin(a(&s)) }
        case "cos": try need(1); let a = args[0]; return { s in cos(a(&s)) }
        case "tan": try need(1); let a = args[0]; return { s in tan(a(&s)) }
        case "asin": try need(1); let a = args[0]; return { s in asin(a(&s)) }
        case "acos": try need(1); let a = args[0]; return { s in acos(a(&s)) }
        case "atan": try need(1); let a = args[0]; return { s in atan(a(&s)) }
        case "atan2": try need(2); let a = args[0], b = args[1]; return { s in atan2(a(&s), b(&s)) }
        case "sinh": try need(1); let a = args[0]; return { s in sinh(a(&s)) }
        case "cosh": try need(1); let a = args[0]; return { s in cosh(a(&s)) }
        case "tanh": try need(1); let a = args[0]; return { s in tanh(a(&s)) }
        case "exp": try need(1); let a = args[0]; return { s in exp(a(&s)) }
        case "ln", "log": try need(1); let a = args[0]; return { s in log(a(&s)) }
        case "log10": try need(1); let a = args[0]; return { s in log10(a(&s)) }
        case "sqrt", "√": try need(1); let a = args[0]; return { s in sqrt(a(&s)) }
        case "abs": try need(1); let a = args[0]; return { s in abs(a(&s)) }
        case "sign": try need(1); let a = args[0]; return { s in let v = a(&s); return v > 0 ? 1 : (v < 0 ? -1 : 0) }
        case "floor": try need(1); let a = args[0]; return { s in floor(a(&s)) }
        case "ceil": try need(1); let a = args[0]; return { s in ceil(a(&s)) }
        case "round": try need(1); let a = args[0]; return { s in a(&s).rounded() }
        case "min": try need(2); let a = args[0], b = args[1]; return { s in Swift.min(a(&s), b(&s)) }
        case "max": try need(2); let a = args[0], b = args[1]; return { s in Swift.max(a(&s), b(&s)) }
        case "clamp": try need(3); let a = args[0], lo = args[1], hi = args[2]; return { s in Swift.min(Swift.max(a(&s), lo(&s)), hi(&s)) }
        case "mod": try need(2); let a = args[0], b = args[1]; return { s in let m = b(&s); let v = a(&s); return v - m * floor(v / m) }
        case "pow": try need(2); let a = args[0], b = args[1]; return { s in pow(a(&s), b(&s)) }
        case "hypot": try need(2); let a = args[0], b = args[1]; return { s in hypot(a(&s), b(&s)) }
        case "step": try need(1); let a = args[0]; return { s in a(&s) < 0 ? 0 : 1 }
        case "if": try need(3); let c = args[0], a = args[1], b = args[2]; return { s in c(&s) > 0 ? a(&s) : b(&s) }
        default:
            throw MathEvaluationError(message: "알 수 없는 함수 '\(name)'")
        }
    }
}

/// Convenience tree-walking evaluation for single values (tests, `let` defaults, canvas numbers).
nonisolated enum MathEvaluator {
    static func evaluate(_ expr: MathExpr, variables: [String: Double] = [:], definitions: [String: FunctionDefinition] = [:]) throws -> Double {
        let names = Array(variables.keys)
        var compiler = ExpressionCompiler(variables: names, definitions: definitions)
        let compiled = try compiler.compile(expr)
        var slots = [Double](repeating: 0, count: max(compiled.slotCount, names.count))
        for (i, n) in names.enumerated() { slots[i] = variables[n]! }
        return compiled.evaluate(&slots)
    }
}
