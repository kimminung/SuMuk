import Foundation

/// Token set for SuMuk Script. Ported from MathSketch's MathLexer and extended with the
/// unicode operators that appear in hand-written formulas (`· × − π √ … ∈ | ²`), braces,
/// brackets, `=`, hex colours and significant newlines (statements are line based).
nonisolated enum MathTokenKind: Equatable, Sendable {
    case number(Double)
    case identifier(String)
    case hexColor(String)
    case plus, minus, star, slash, caret
    case leftParen, rightParen, leftBrace, rightBrace, leftBracket, rightBracket
    case comma, equals, bar, ellipsis, inSet
    case newline
    case end
}

nonisolated struct MathToken: Equatable, Sendable {
    let kind: MathTokenKind
    let column: Int   // 0-based offset into the whole source
    let line: Int     // 1-based line number
}

/// A parse or evaluation failure with a 1-based line and column into the script.
nonisolated struct MathSyntaxError: Error, CustomStringConvertible, Equatable, Sendable {
    let message: String
    let line: Int
    let column: Int
    var description: String { "\(line)행 \(column)열: \(message)" }
}

nonisolated struct MathLexer {
    private let characters: [Character]
    private var index = 0
    private var line = 1
    private var lineStart = 0

    init(_ source: String) {
        characters = Array(source)
    }

    static let superscripts: [Character: Int] = ["⁰": 0, "¹": 1, "²": 2, "³": 3, "⁴": 4, "⁵": 5, "⁶": 6, "⁷": 7, "⁸": 8, "⁹": 9]

    mutating func tokenize() throws -> [MathToken] {
        var tokens: [MathToken] = []
        while let token = try next() {
            // collapse runs of newlines
            if token.kind == .newline, tokens.last?.kind == .newline { continue }
            tokens.append(token)
        }
        tokens.append(MathToken(kind: .end, column: characters.count, line: line))
        return tokens
    }

    private func make(_ kind: MathTokenKind, _ start: Int) -> MathToken {
        MathToken(kind: kind, column: start - lineStart + 1, line: line)
    }

    /// Characters that always form a one-character identifier (so `2πk` lexes as 2 · π · k).
    static let soloIdentifiers: Set<Character> = ["π", "τ", "√"]

    private static func isIdentifierChar(_ c: Character) -> Bool {
        if soloIdentifiers.contains(c) || superscripts[c] != nil { return false }
        return c.isLetter || c == "_" || (c.isNumber && c.isASCII)
    }

    private mutating func next() throws -> MathToken? {
        if let pending = pendingNumber {
            pendingNumber = nil
            return make(.number(pending), index)
        }
        while index < characters.count, characters[index].isWhitespace, !characters[index].isNewline {
            index += 1
        }
        guard index < characters.count else { return nil }
        let start = index
        let c = characters[index]

        if let sup = Self.superscripts[c] {
            // ² → ^2 : emit the caret now and the digit on the next call
            var value = sup; index += 1
            while index < characters.count, let d = Self.superscripts[characters[index]] { value = value * 10 + d; index += 1 }
            pendingNumber = Double(value)
            return make(.caret, start)
        }
        if c.isNewline {
            index += 1
            let token = make(.newline, start)
            line += 1; lineStart = index
            return token
        }
        // comments
        if c == "/", index + 1 < characters.count, characters[index + 1] == "/" {
            while index < characters.count, !characters[index].isNewline { index += 1 }
            return try next()
        }
        if (c.isNumber && c.isASCII) || (c == "." && index + 1 < characters.count && characters[index + 1].isNumber && characters[index + 1].isASCII) {
            var text = ""
            while index < characters.count, (characters[index].isNumber && characters[index].isASCII) || characters[index] == "." {
                if characters[index] == ".", index + 2 < characters.count, characters[index + 1] == ".", characters[index + 2] == "." { break } // 1...500
                text.append(characters[index]); index += 1
            }
            // scientific notation 1e-5 / 2.5E3 (only when followed by a digit or sign+digit)
            if index < characters.count, characters[index] == "e" || characters[index] == "E" {
                var j = index + 1
                if j < characters.count, characters[j] == "-" || characters[j] == "+" { j += 1 }
                if j < characters.count, characters[j].isNumber {
                    text.append("e")
                    index += 1
                    if characters[index] == "-" || characters[index] == "+" { text.append(characters[index]); index += 1 }
                    while index < characters.count, characters[index].isNumber { text.append(characters[index]); index += 1 }
                }
            }
            guard let value = Double(text) else {
                throw MathSyntaxError(message: "잘못된 숫자 '\(text)'", line: line, column: start - lineStart + 1)
            }
            return make(.number(value), start)
        }
        if c == "#" {
            var text = ""
            index += 1
            while index < characters.count, characters[index].isHexDigit { text.append(characters[index]); index += 1 }
            guard text.count == 6 || text.count == 8 else {
                throw MathSyntaxError(message: "색은 #RRGGBB 형식이어야 합니다", line: line, column: start - lineStart + 1)
            }
            return make(.hexColor(text), start)
        }
        if Self.soloIdentifiers.contains(c) {
            index += 1
            return make(.identifier(String(c)), start)
        }
        if c.isLetter || c == "_" {
            var text = ""
            while index < characters.count, Self.isIdentifierChar(characters[index]) {
                text.append(characters[index]); index += 1
            }
            return make(.identifier(text), start)
        }
        index += 1
        switch c {
        case "+": return make(.plus, start)
        case "-", "−", "–": return make(.minus, start)
        case "*", "·", "×", "⋅": return make(.star, start)
        case "/", "÷": return make(.slash, start)
        case "^": return make(.caret, start)
        case "(": return make(.leftParen, start)
        case ")": return make(.rightParen, start)
        case "{": return make(.leftBrace, start)
        case "}": return make(.rightBrace, start)
        case "[": return make(.leftBracket, start)
        case "]": return make(.rightBracket, start)
        case ",": return make(.comma, start)
        case "=": return make(.equals, start)
        case "|": return make(.bar, start)
        case "∈": return make(.inSet, start)
        case "…": return make(.ellipsis, start)
        case ".":
            if index + 1 < characters.count, characters[index] == ".", characters[index + 1] == "." {
                index += 2
                return make(.ellipsis, start)
            }
            throw MathSyntaxError(message: "'.'는 숫자나 범위(...)에만 쓸 수 있습니다", line: line, column: start - lineStart + 1)
        default:
            throw MathSyntaxError(message: "알 수 없는 문자 '\(c)'", line: line, column: start - lineStart + 1)
        }
    }

    private var pendingNumber: Double?
}
