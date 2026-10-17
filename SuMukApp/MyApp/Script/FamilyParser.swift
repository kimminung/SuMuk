import Foundation
import CoreGraphics

/// Parser for SuMuk Script (PRD §4). Line based statements:
///
///     canvas 354 × 472
///     ink #141414 width 0.6 alpha 0.85
///     let brush = 0.03 in [0.01, 0.08]
///     segments k = 1 ... 500 {            circles k = -10 ... 10 {        curve t ∈ [0, 2π] samples 600 {
///       from ( x, y )                        center ( x, y )                  x = …
///       to   ( x, y )                        radius r                         y = …
///     }                                    }                                }
///     where
///       f(k) = …          // user functions, constants `φ = π(3 − √5)`
///
/// Expressions: `+ − · × / ^`, juxtaposition multiplication (`2πk`), `sin^7(x)`, `|x|`, `√x`,
/// superscripts (`x²`), builtin functions (MathBuiltins), user functions from `where`.
nonisolated struct FamilyParser {
    private var tokens: [MathToken]
    private var position = 0
    private var functionNames: Set<String>
    private var absDepth = 0
    private var groupDepth = 0
    private var familyLines: [Int] = []
    private var definitionLines: [String: Int] = [:]

    static let keywords: Set<String> = ["canvas", "ink", "let", "segments", "circles", "curve", "pixel", "where", "from", "to", "center", "radius", "samples", "in", "width", "alpha", "fill"]

    static func parse(_ source: String) throws -> Artwork {
        guard source.count <= Artwork.maxScriptLength else {
            throw MathSyntaxError(message: "스크립트가 너무 깁니다 (최대 \(Artwork.maxScriptLength)자)", line: 1, column: 1)
        }
        var lexer = MathLexer(source)
        let tokens = try lexer.tokenize()
        var parser = FamilyParser(tokens: tokens)
        return try parser.parseScript()
    }

    private init(tokens: [MathToken]) {
        self.tokens = tokens
        // pre-pass: collect user function names `name(` … `) =` at statement starts so that
        // `x1(2πk/600)` parses as a call while `k(2π…)` stays a multiplication.
        var names = Set<String>()
        var i = 0
        while i < tokens.count {
            let atLineStart = i == 0 || tokens[i - 1].kind == .newline
            if atLineStart, case .identifier(let n) = tokens[i].kind, !Self.keywords.contains(n) {
                var j = i + 1
                if j < tokens.count, tokens[j].kind == .leftParen {
                    var depth = 0
                    while j < tokens.count {
                        if tokens[j].kind == .leftParen { depth += 1 }
                        if tokens[j].kind == .rightParen { depth -= 1; if depth == 0 { break } }
                        j += 1
                    }
                    if j + 1 < tokens.count, tokens[j + 1].kind == .equals { names.insert(n) }
                }
            }
            i += 1
        }
        functionNames = names.union(MathBuiltins.functions)
    }

    // MARK: - helpers

    private var current: MathToken { tokens[position] }
    private var previous: MathToken? { position > 0 ? tokens[position - 1] : nil }

    @discardableResult
    private mutating func advance() -> MathToken {
        let t = tokens[position]
        if position < tokens.count - 1 { position += 1 }
        return t
    }

    private mutating func skipNewlines() {
        while current.kind == .newline { advance() }
    }

    private func error(_ message: String, _ token: MathToken? = nil) -> MathSyntaxError {
        let t = token ?? current
        return MathSyntaxError(message: message, line: t.line, column: t.column)
    }

    private mutating func expect(_ kind: MathTokenKind, _ what: String) throws {
        guard current.kind == kind else { throw error("\(what)가 필요합니다") }
        advance()
    }

    private mutating func expectKeyword(_ word: String) throws {
        guard case .identifier(let n) = current.kind, n == word else { throw error("'\(word)'가 필요합니다") }
        advance()
    }

    private func isKeyword(_ word: String) -> Bool {
        if case .identifier(let n) = current.kind { return n == word }
        return false
    }

    private mutating func number() throws -> Double {
        let expr = try parseExpression()
        return try MathEvaluator.evaluate(expr)
    }

    // MARK: - script

    private mutating func parseScript() throws -> Artwork {
        var art = Artwork()
        var definitions: [FunctionDefinition] = []
        while true {
            skipNewlines()
            if current.kind == .end { break }
            guard case .identifier(let word) = current.kind else {
                throw error("문장은 canvas · ink · let · segments · circles · curve · where 또는 정의로 시작해야 합니다")
            }
            switch word {
            case "canvas":
                // `canvas 354 × 472` — plain numbers, not an expression (× would otherwise multiply them)
                advance()
                guard case .number(let w) = current.kind else { throw error("canvas 너비(숫자)가 필요합니다") }
                advance()
                if current.kind == .star { advance() } else if isKeyword("x") || isKeyword("by") { advance() }
                guard case .number(let h) = current.kind else { throw error("canvas 높이(숫자)가 필요합니다") }
                advance()
                guard w > 0, h > 0 else { throw error("canvas 크기는 0보다 커야 합니다") }
                art.canvas = CGSize(width: w, height: h)
            case "ink":
                advance()
                art.ink = try parseInk(base: art.ink)
            case "let":
                advance()
                guard case .identifier(let name) = current.kind else { throw error("변수 이름이 필요합니다") }
                let line = current.line
                advance()
                try expect(.equals, "'='")
                let value = try number()
                var range = (value - 1)...(value + 1)
                if isKeyword("in") {
                    advance()
                    try expect(.leftBracket, "'['")
                    let lo = try number()
                    try expect(.comma, "','")
                    let hi = try number()
                    try expect(.rightBracket, "']'")
                    guard lo < hi else { throw error("범위의 하한이 상한보다 작아야 합니다") }
                    range = lo...hi
                }
                art.lets.append(LetVariable(name: name, value: value, range: range, line: line))
            case "segments", "circles", "curve":
                familyLines.append(current.line)
                advance()
                art.families.append(try parseFamily(kind: word))
            case "pixel":
                throw error("픽셀 수식(pixel)은 아직 이 버전에서 지원하지 않습니다")
            case "where":
                advance()
            default:
                let line = current.line
                let def = try parseDefinition()
                definitionLines[def.name] = line
                definitions.append(def)
            }
            if current.kind != .end, current.kind != .newline {
                throw error("한 줄에는 문장 하나만 쓸 수 있습니다")
            }
        }
        for d in definitions {
            guard art.definitions[d.name] == nil else { throw MathSyntaxError(message: "'\(d.name)'이(가) 두 번 정의되었습니다", line: definitionLines[d.name] ?? 1, column: 1) }
            art.definitions[d.name] = d
        }
        guard art.families.count <= Artwork.maxFamilies else {
            throw MathSyntaxError(message: "계열은 최대 \(Artwork.maxFamilies)개까지 가능합니다", line: 1, column: 1)
        }
        guard art.elementCount <= Artwork.maxElements else {
            throw MathSyntaxError(message: "요소 수가 상한(\(Artwork.maxElements))을 넘습니다", line: 1, column: 1)
        }
        try validate(art)
        return art
    }

    private mutating func parseInk(base: InkStyle) throws -> InkStyle {
        var ink = base
        while current.kind != .newline, current.kind != .end, current.kind != .rightBrace {
            switch current.kind {
            case .hexColor(let hex): ink.hex = String(hex.prefix(6)); advance()
            case .identifier("width"): advance(); ink.width = try number()
            case .identifier("alpha"): advance(); ink.alpha = min(1, max(0, try number()))
            case .identifier("fill"): advance(); ink.fill = true
            default: throw error("ink 뒤에는 #색상 · width · alpha · fill 만 올 수 있습니다")
            }
        }
        return ink
    }

    private mutating func parseFamily(kind: String) throws -> Family {
        guard case .identifier(let variable) = current.kind else { throw error("계열 변수 이름(k, t …)이 필요합니다") }
        advance()
        var intRange: IntegerRange?
        var realRange: RealRange?
        if kind == "curve" {
            if current.kind == .inSet || current.kind == .equals { advance() } else { throw error("'∈'가 필요합니다") }
            try expect(.leftBracket, "'['")
            let lo = try number()
            try expect(.comma, "','")
            let hi = try number()
            try expect(.rightBracket, "']'")
            var samples = 600
            if isKeyword("samples") { advance(); samples = Int(try number()) }
            guard samples >= 2, samples <= 100_000 else { throw error("samples는 2~100000 사이여야 합니다") }
            realRange = RealRange(variable: variable, lower: lo, upper: hi, samples: samples)
        } else {
            try expect(.equals, "'='")
            let lo = try number()
            guard current.kind == .ellipsis else { throw error("범위 '...'가 필요합니다") }
            advance()
            let hi = try number()
            guard lo == lo.rounded(), hi == hi.rounded() else { throw error("정수 범위여야 합니다") }
            intRange = IntegerRange(variable: variable, lower: Int(lo), upper: Int(hi))
            guard intRange!.count >= 1 else { throw error("범위가 비어 있습니다") }
        }
        try expect(.leftBrace, "'{'")
        var from: (MathExpr, MathExpr)?, to: (MathExpr, MathExpr)?, center: (MathExpr, MathExpr)?
        var radius: MathExpr?, x: MathExpr?, y: MathExpr?, ink: InkStyle?
        while true {
            skipNewlines()
            if current.kind == .rightBrace { advance(); break }
            guard case .identifier(let key) = current.kind else { throw error("from · to · center · radius · x · y · ink 가 필요합니다") }
            advance()
            switch key {
            case "from": from = try parsePair()
            case "to": to = try parsePair()
            case "center": center = try parsePair()
            case "radius": radius = try parseExpression()
            case "x": if current.kind == .equals { advance() }; x = try parseExpression()
            case "y": if current.kind == .equals { advance() }; y = try parseExpression()
            case "ink": ink = try parseInk(base: InkStyle())
            default: throw error("알 수 없는 항목 '\(key)'")
            }
            if current.kind != .newline, current.kind != .rightBrace { throw error("한 줄에는 항목 하나만 쓸 수 있습니다") }
        }
        switch kind {
        case "segments":
            guard let f = from, let t = to else { throw error("segments 블록에는 from 과 to 가 필요합니다") }
            return .segments(range: intRange!, from: f, to: t, ink: ink)
        case "circles":
            guard let c = center, let r = radius else { throw error("circles 블록에는 center 와 radius 가 필요합니다") }
            return .circles(range: intRange!, center: c, radius: r, ink: ink)
        default:
            guard let xe = x, let ye = y else { throw error("curve 블록에는 x 와 y 가 필요합니다") }
            return .curve(range: realRange!, x: xe, y: ye, ink: ink)
        }
    }

    private mutating func parsePair() throws -> (MathExpr, MathExpr) {
        if current.kind == .equals { advance() }
        try expect(.leftParen, "'('")
        groupDepth += 1
        let a = try parseExpression()
        try expect(.comma, "','")
        let b = try parseExpression()
        groupDepth -= 1
        try expect(.rightParen, "')'")
        return (a, b)
    }

    private mutating func parseDefinition() throws -> FunctionDefinition {
        guard case .identifier(let name) = current.kind else { throw error("정의 이름이 필요합니다") }
        let nameToken = current
        advance()
        var params: [String] = []
        if current.kind == .leftParen {
            advance()
            while true {
                guard case .identifier(let p) = current.kind else { throw error("매개변수 이름이 필요합니다") }
                params.append(p); advance()
                if current.kind == .comma { advance(); continue }
                break
            }
            try expect(.rightParen, "')'")
        }
        guard current.kind == .equals else { throw error("정의에는 '='가 필요합니다", nameToken) }
        advance()
        let body = try parseExpression()
        return FunctionDefinition(name: name, parameters: params, body: body)
    }

    private func validate(_ art: Artwork) throws {
        let letNames = Set(art.lets.map(\.name))
        let constants = Set(MathBuiltins.constants.keys).union(art.definitions.filter { $0.value.parameters.isEmpty }.keys)
        func check(_ e: MathExpr, allowed: Set<String>, context: String, line: Int) throws {
            let free = e.variables.subtracting(allowed).subtracting(letNames).subtracting(constants)
            if let name = free.sorted().first {
                throw MathSyntaxError(message: "\(context)에 정의되지 않은 이름 '\(name)'이(가) 있습니다", line: line, column: 1)
            }
        }
        for (i, fam) in art.families.enumerated() {
            let ctx = "계열 \(i + 1)"
            let line = i < familyLines.count ? familyLines[i] : 1
            switch fam {
            case .segments(let r, let f, let t, _):
                for e in [f.0, f.1, t.0, t.1] { try check(e, allowed: [r.variable], context: ctx, line: line) }
            case .circles(let r, let c, let rad, _):
                for e in [c.0, c.1, rad] { try check(e, allowed: [r.variable], context: ctx, line: line) }
            case .curve(let r, let x, let y, _):
                for e in [x, y] { try check(e, allowed: [r.variable], context: ctx, line: line) }
            }
        }
        for d in art.definitions.values.sorted(by: { (definitionLines[$0.name] ?? 0) < (definitionLines[$1.name] ?? 0) }) {
            try check(d.body, allowed: Set(d.parameters), context: "정의 '\(d.name)'", line: definitionLines[d.name] ?? 1)
        }
    }

    // MARK: - expressions

    /// Whether a newline at the current position continues the expression.
    private func newlineContinues() -> Bool {
        if groupDepth > 0 || absDepth > 0 { return true }
        if let prev = previous {
            switch prev.kind {
            case .plus, .minus, .star, .slash, .caret, .leftParen, .comma, .equals: return true
            default: break
            }
        }
        var j = position
        while j < tokens.count, tokens[j].kind == .newline { j += 1 }
        if j < tokens.count {
            switch tokens[j].kind {
            case .plus, .minus, .star, .slash, .caret: return true
            default: return false
            }
        }
        return false
    }

    private mutating func skipContinuationNewlines() {
        while current.kind == .newline, newlineContinues() { advance() }
    }

    private mutating func parseExpression() throws -> MathExpr {
        var left = try parseTerm()
        while true {
            skipContinuationNewlines()
            switch current.kind {
            case .plus: advance(); skipContinuationNewlines(); left = .binary(.add, left, try parseTerm())
            case .minus: advance(); skipContinuationNewlines(); left = .binary(.subtract, left, try parseTerm())
            default: return left
            }
        }
    }

    private func startsPrimary(_ kind: MathTokenKind) -> Bool {
        switch kind {
        case .number, .leftParen: return true
        case .identifier(let n): return !Self.keywords.contains(n)
        case .bar: return absDepth == 0 || true  // decided by caller
        default: return false
        }
    }

    private mutating func parseTerm() throws -> MathExpr {
        var left = try parseUnary()
        while true {
            skipContinuationNewlines()
            switch current.kind {
            case .star: advance(); skipContinuationNewlines(); left = .binary(.multiply, left, try parseUnary())
            case .slash: advance(); skipContinuationNewlines(); left = .binary(.divide, left, try parseUnary())
            case .bar where absDepth > 0:
                return left   // closing bar of |…|
            case .number, .leftParen, .identifier, .bar:
                // juxtaposition multiplication: 2πk, 3(x+1), sin(a)cos(b), 2|x|
                if case .identifier(let n) = current.kind, Self.keywords.contains(n) { return left }
                if case .number = current.kind, let p = previous, case .number = p.kind { return left } // "1 2" is not a product
                left = .binary(.multiply, left, try parsePower())
            default:
                return left
            }
        }
    }

    private mutating func parseUnary() throws -> MathExpr {
        if current.kind == .minus { advance(); return .negate(try parseUnary()) }
        if current.kind == .plus { advance(); return try parseUnary() }
        return try parsePower()
    }

    private mutating func parsePower() throws -> MathExpr {
        let base = try parsePrimary()
        if current.kind == .caret {
            advance()
            let exponent = try parseUnary()
            return .binary(.power, base, exponent)
        }
        return base
    }

    private mutating func parseArguments() throws -> [MathExpr] {
        try expect(.leftParen, "'('")
        groupDepth += 1; defer { groupDepth -= 1 }
        let savedAbs = absDepth; absDepth = 0; defer { absDepth = savedAbs }
        var args: [MathExpr] = []
        skipNewlines()
        if current.kind != .rightParen {
            args.append(try parseExpression())
            while current.kind == .comma { advance(); skipNewlines(); args.append(try parseExpression()) }
        }
        skipNewlines()
        guard current.kind == .rightParen else { throw error("')'가 필요합니다") }
        advance()
        return args
    }

    private mutating func parsePrimary() throws -> MathExpr {
        let token = current
        switch token.kind {
        case .number(let v):
            advance()
            return .number(v)
        case .identifier(let name):
            if Self.keywords.contains(name) { throw error("식이 필요합니다 ('\(name)'은 예약어)") }
            advance()
            if name == "√" {
                return .call("sqrt", [try parsePower()])
            }
            if functionNames.contains(name) {
                if current.kind == .caret {
                    // sin^7(x) == (sin(x))^7 — only when a '(' follows the exponent; otherwise `x^2` is a plain power
                    advance()
                    let exponent: MathExpr
                    if case .number(let v) = current.kind { advance(); exponent = .number(v) }
                    else if current.kind == .minus { advance(); guard case .number(let v) = current.kind else { throw error("지수가 필요합니다") }; advance(); exponent = .number(-v) }
                    else if current.kind == .leftParen { exponent = try parsePrimary() }
                    else { throw error("지수가 필요합니다") }
                    if current.kind == .leftParen {
                        let args = try parseArguments()
                        return .binary(.power, .call(name, args), exponent)
                    }
                    return .binary(.power, .variable(name), exponent)
                }
                if current.kind == .leftParen {
                    return .call(name, try parseArguments())
                }
                if MathBuiltins.functions.contains(name) {
                    // bare `sin x` style: apply to the next power expression
                    return .call(name, [try parsePower()])
                }
                return .variable(name)
            }
            return .variable(name)
        case .leftParen:
            advance()
            groupDepth += 1
            let savedAbs = absDepth; absDepth = 0
            skipNewlines()
            let expr = try parseExpression()
            skipNewlines()
            absDepth = savedAbs
            groupDepth -= 1
            guard current.kind == .rightParen else { throw error("')'가 필요합니다") }
            advance()
            return expr
        case .bar:
            advance()
            absDepth += 1
            let expr = try parseExpression()
            absDepth -= 1
            guard current.kind == .bar else { throw error("닫는 '|'가 필요합니다") }
            advance()
            return .call("abs", [expr])
        default:
            throw error("식이 필요합니다")
        }
    }
}
