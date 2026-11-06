import Foundation

// ───────── Модели «Трат» ─────────

struct Member: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
}

struct Expense: Identifiable, Codable, Equatable {
    var id = UUID()
    var payerID: UUID
    var amount: Double
    var title: String
    var shares: [UUID: Double]      // кто сколько должен в рублях (не проценты)
    var date = Date()
}

struct TripEvent: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var members: [Member]
    var expenses: [Expense] = []
    var createdAt = Date()
}

struct Transfer: Identifiable {
    let id = UUID()
    let from: UUID
    let to: UUID
    let amount: Double
}

struct Settlement {
    var balances: [UUID: Double]
    var transfers: [Transfer]
}

private struct PairKey: Hashable {
    let a: UUID
    let b: UUID
}

// ───────── Деньги ─────────

func r2(_ x: Double) -> Double { (x * 100).rounded() / 100 }

private let moneyFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.locale = Locale(identifier: "ru_RU")
    f.numberStyle = .decimal
    f.minimumFractionDigits = 2
    f.maximumFractionDigits = 2
    return f
}()

func money(_ x: Double) -> String {
    let s = moneyFormatter.string(from: NSNumber(value: r2(x))) ?? String(format: "%.2f", x)
    return s + " ₽"
}

func parseNumber(_ s: String?) -> Double {
    let t = (s ?? "")
        .replacingOccurrences(of: ",", with: ".")
        .replacingOccurrences(of: "%", with: "")
        .trimmingCharacters(in: .whitespaces)
    return Double(t) ?? 0
}

func percentText(_ x: Double) -> String {
    x == x.rounded() ? String(Int(x)) : String(format: "%.2f", x)
}

// ───────── Итоги и взаимозачёт ─────────

extension TripEvent {
    var total: Double { expenses.reduce(0) { $0 + $1.amount } }

    func memberName(_ id: UUID) -> String {
        members.first { $0.id == id }?.name ?? "?"
    }

    /// balance = сколько человек заплатил − сумма его долей.
    /// Переводы считаются попарно: долг A→B минус долг B→A.
    func settlement() -> Settlement {
        var bal: [UUID: Double] = [:]
        var pair: [PairKey: Double] = [:]
        for m in members { bal[m.id] = 0 }

        for e in expenses {
            bal[e.payerID, default: 0] += e.amount
            for (user, share) in e.shares {
                bal[user, default: 0] -= share
                if user != e.payerID {
                    pair[PairKey(a: user, b: e.payerID), default: 0] += share
                }
            }
        }

        var transfers: [Transfer] = []
        let ids = members.map { $0.id }
        for i in 0..<ids.count {
            for j in (i + 1)..<ids.count {
                let a = ids[i]
                let b = ids[j]
                let ab = pair[PairKey(a: a, b: b)] ?? 0
                let ba = pair[PairKey(a: b, b: a)] ?? 0
                let net = r2(ab - ba)
                if net > 0.01 {
                    transfers.append(Transfer(from: a, to: b, amount: net))
                } else if net < -0.01 {
                    transfers.append(Transfer(from: b, to: a, amount: -net))
                }
            }
        }
        return Settlement(balances: bal.mapValues { r2($0) }, transfers: transfers)
    }
}

// ───────── Режимы деления ─────────

enum SplitMode: String, CaseIterable, Identifiable {
    case all, withoutPayer, onlyPayer, selected, manual, percent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "Поровну на всех"
        case .withoutPayer: return "На всех, кроме плательщика"
        case .onlyPayer: return "Только на плательщика"
        case .selected: return "Выбрать участников"
        case .manual: return "Указать суммы вручную"
        case .percent: return "Указать доли в %"
        }
    }
}

struct SplitFailure: Error {
    let text: String
}

/// Остаток копеек при делении всегда уходит первому участнику списка (как в боте).
func buildShares(amount: Double,
                 mode: SplitMode,
                 members: [Member],
                 payer: UUID,
                 selected: Set<UUID>,
                 manual: [UUID: String],
                 percent: [UUID: String]) -> Result<[UUID: Double], SplitFailure> {

    func equal(_ list: [Member]) -> [UUID: Double] {
        let n = Double(list.count)
        let each = r2(amount / n)
        var out: [UUID: Double] = [:]
        for m in list { out[m.id] = each }
        let diff = r2(amount - each * n)
        let first = list[0].id
        out[first] = r2((out[first] ?? 0) + diff)
        return out
    }

    switch mode {
    case .all:
        return .success(equal(members))

    case .withoutPayer:
        let others = members.filter { $0.id != payer }
        if others.isEmpty {
            return .failure(SplitFailure(text: "Нет других участников, кроме плательщика"))
        }
        return .success(equal(others))

    case .onlyPayer:
        return .success([payer: r2(amount)])

    case .selected:
        let list = members.filter { selected.contains($0.id) }
        if list.isEmpty {
            return .failure(SplitFailure(text: "Выберите хотя бы одного участника"))
        }
        return .success(equal(list))

    case .manual:
        var out: [UUID: Double] = [:]
        var total = 0.0
        for m in members {
            let v = r2(parseNumber(manual[m.id]))
            if v > 0 {
                out[m.id] = v
                total += v
            }
        }
        if out.isEmpty || abs(total - amount) >= 0.01 {
            return .failure(SplitFailure(text: "Сумма по участникам должна быть \(money(amount))"))
        }
        return .success(out)

    case .percent:
        let list = members.filter { parseNumber(percent[$0.id]) > 0 }
        var totalPercent = 0.0
        for m in list { totalPercent += parseNumber(percent[m.id]) }
        if list.isEmpty || abs(totalPercent - 100) >= 0.01 {
            return .failure(SplitFailure(text: "Сумма долей должна быть 100%"))
        }
        var out: [UUID: Double] = [:]
        var sum = 0.0
        for m in list {
            let v = r2(amount * parseNumber(percent[m.id]) / 100)
            out[m.id] = v
            sum += v
        }
        let first = list[0].id
        out[first] = r2((out[first] ?? 0) + r2(amount - sum))
        return .success(out)
    }
}
