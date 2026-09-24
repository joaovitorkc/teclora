import Foundation

/// `1+2*3` vira um hit. Enter copia o resultado. Não avalia código.
@MainActor
final class CalcProvider: CommandProvider {
    func hits(for query: String) -> [LauncherItem] {
        guard let value = ExpressionMath.evaluate(query) else { return [] }
        let text = ExpressionMath.format(value)
        return [
            LauncherItem(
                id: "teclora.calc",
                title: text,
                subtitle: "Calculadora",
                section: "Calculadora",
                action: .copyText(text),
                kind: .command(symbol: "function")
            ),
        ]
    }
}

enum ExpressionMath {
    static func evaluate(_ raw: String) -> Double? {
        var source = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard looksLikeExpression(source) else { return nil }
        source = source
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: ",", with: ".")
            .filter { !$0.isWhitespace }
        var parser = Parser(source)
        guard let value = parser.parseExpression(), parser.isAtEnd, value.isFinite else { return nil }
        return value
    }

    static func format(_ value: Double) -> String {
        if value.rounded() == value, abs(value) < 1e15 {
            return String(Int(value))
        }
        return String(format: "%g", value)
    }

    /// Dígito e operador, só caracteres de conta. `-3` sozinho não conta.
    private static func looksLikeExpression(_ raw: String) -> Bool {
        let compact = raw.filter { !$0.isWhitespace }
        guard compact.contains(where: \.isNumber) else { return false }
        guard compact.allSatisfy({ allowed.contains($0) }) else { return false }
        let hasBinary = compact.contains(where: { "+*/".contains($0) })
        let minusNotOnlyLeading = compact.dropFirst().contains("-")
        return hasBinary || minusNotOnlyLeading
    }

    private static let allowed = Set("0123456789.+-*/(),×÷")
}

private struct Parser {
    private let chars: [Character]
    private var index = 0

    init(_ source: String) {
        chars = Array(source)
    }

    var isAtEnd: Bool { index >= chars.count }

    mutating func parseExpression() -> Double? {
        guard var value = parseTerm() else { return nil }
        while let op = peek(), op == "+" || op == "-" {
            index += 1
            guard let rhs = parseTerm() else { return nil }
            value = op == "+" ? value + rhs : value - rhs
        }
        return value
    }

    private mutating func parseTerm() -> Double? {
        guard var value = parseFactor() else { return nil }
        while let op = peek(), op == "*" || op == "/" {
            index += 1
            guard let rhs = parseFactor() else { return nil }
            if op == "/" {
                guard rhs != 0 else { return nil }
                value /= rhs
            } else {
                value *= rhs
            }
        }
        return value
    }

    private mutating func parseFactor() -> Double? {
        if peek() == "(" {
            index += 1
            guard let value = parseExpression(), peek() == ")" else { return nil }
            index += 1
            return value
        }
        if peek() == "+" || peek() == "-" {
            let sign: Double = peek() == "-" ? -1 : 1
            index += 1
            guard let value = parseFactor() else { return nil }
            return sign * value
        }
        return parseNumber()
    }

    private mutating func parseNumber() -> Double? {
        let start = index
        while let char = peek(), char.isNumber || char == "." {
            index += 1
        }
        guard start < index else { return nil }
        return Double(String(chars[start..<index]))
    }

    private func peek() -> Character? {
        index < chars.count ? chars[index] : nil
    }
}
