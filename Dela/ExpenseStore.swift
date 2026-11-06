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
        let event = TripEvent(name: name, members: memberNames.map { Member(name: $0) })
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

    func addExpense(_ expense: Expense, to id: UUID) {
        mutate(id) { $0.expenses.append(expense) }
    }

    func deleteExpense(_ expenseID: UUID, from id: UUID) {
        mutate(id) { $0.expenses.removeAll { $0.id == expenseID } }
    }

    @discardableResult
    func addMember(named name: String, to id: UUID) -> Bool {
        let clean = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(64))
        guard !clean.isEmpty else { return false }
        var added = false
        mutate(id) { e in
            let exists = e.members.contains { $0.name.lowercased() == clean.lowercased() }
            if !exists {
                e.members.append(Member(name: clean))
                added = true
            }
        }
        return added
    }

    /// Как в боте: удаляются траты этого участника как плательщика и его доли в остальных тратах.
    func removeMember(_ memberID: UUID, from id: UUID) {
        mutate(id) { e in
            e.expenses.removeAll { $0.payerID == memberID }
            for i in e.expenses.indices {
                e.expenses[i].shares.removeValue(forKey: memberID)
            }
            e.members.removeAll { $0.id == memberID }
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([TripEvent].self, from: data) else { return }
        events = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(events) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
