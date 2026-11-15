import Foundation

final class ExpenseStore: ObservableObject {
    @Published var events: [TripEvent] = [] {
        didSet { save() }
    }

    private let fileURL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("expenses.json")

    init() {
        load()
    }

    @discardableResult
    func addEvent(name: String, memberNames: [String]) -> UUID {
        var event = TripEvent(name: name, members: memberNames.map { Member(name: $0) })
        event.addLog(.eventCreated, "Событие «\(name)» создано")
        events.insert(event, at: 0)
        return event.id
    }

    func deleteEvent(_ id: UUID) {
        events.removeAll { $0.id == id }
    }

    func mutate(_ id: UUID, _ change: (inout TripEvent) -> Void) {
        guard let i = events.firstIndex(where: { $0.id == id }) else { return }
        var e = events[i]
        change(&e)
        events[i] = e
    }

    // ── Траты ──

    func addExpense(_ expense: Expense, to id: UUID) {
        mutate(id) { e in
            e.expenses.append(expense)
            let text = e.describe(expense)
            e.addLog(.expenseAdded, text, expenseID: expense.id)
        }
    }

    /// Отмена: трата перестаёт учитываться в итогах, но остаётся в истории и её можно вернуть.
    func cancelExpense(_ expenseID: UUID, in id: UUID) {
        mutate(id) { e in
            guard let i = e.expenses.firstIndex(where: { $0.id == expenseID }),
                  !e.expenses[i].cancelled else { return }
            e.expenses[i].cancelled = true
            let text = "Отменена трата: " + e.describe(e.expenses[i])
            e.addLog(.expenseCancelled, text, expenseID: expenseID)
        }
    }

    func restoreExpense(_ expenseID: UUID, in id: UUID) {
        mutate(id) { e in
            guard let i = e.expenses.firstIndex(where: { $0.id == expenseID }),
                  e.expenses[i].cancelled else { return }
            e.expenses[i].cancelled = false
            let text = "Возвращена трата: " + e.describe(e.expenses[i])
            e.addLog(.expenseRestored, text, expenseID: expenseID)
        }
    }

    // ── Участники ──

    @discardableResult
    func addMember(named name: String, to id: UUID) -> Bool {
        let clean = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(64))
        guard !clean.isEmpty else { return false }
        var added = false
        mutate(id) { e in
            let exists = e.members.contains { $0.name.lowercased() == clean.lowercased() }
            if !exists {
                e.members.append(Member(name: clean))
                e.addLog(.memberAdded, "Добавлен участник: \(clean)")
                added = true
            }
        }
        return added
    }

    /// Как в боте: удаляются траты этого участника как плательщика и его доли в остальных тратах.
    func removeMember(_ memberID: UUID, from id: UUID) {
        mutate(id) { e in
            let name = e.memberName(memberID)
            let removed = e.expenses.filter { $0.payerID == memberID }.count
            e.expenses.removeAll { $0.payerID == memberID }
            for i in e.expenses.indices {
                e.expenses[i].shares.removeValue(forKey: memberID)
            }
            e.members.removeAll { $0.id == memberID }
            let extra = removed > 0 ? " (удалено трат: \(removed))" : ""
            e.addLog(.memberRemoved, "Удалён участник: \(name)\(extra)")
        }
    }

    // ── Хранение ──

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              var decoded = try? JSONDecoder().decode([TripEvent].self, from: data) else { return }
        for i in decoded.indices where decoded[i].history.isEmpty {
            decoded[i].rebuildHistory()
        }
        events = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(events) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
