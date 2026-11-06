import SwiftUI

// ───────── Добавить трату ─────────

struct AddExpenseSheet: View {
    let event: TripEvent
    let onSave: (Expense) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var payer: UUID
    @State private var amountText = ""
    @State private var title = ""
    @State private var mode: SplitMode = .all
    @State private var selected: Set<UUID>
    @State private var manual: [UUID: String] = [:]
    @State private var percent: [UUID: String] = [:]
    @State private var error = ""

    init(event: TripEvent, onSave: @escaping (Expense) -> Void) {
        self.event = event
        self.onSave = onSave
        _payer = State(initialValue: event.members.first?.id ?? UUID())
        _selected = State(initialValue: Set(event.members.map { $0.id }))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Кто заплатил") {
                    Picker("Плательщик", selection: $payer) {
                        ForEach(event.members) { m in
                            Text(m.name).tag(m.id)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .listRowBackground(Theme.card2)

                Section {
                    TextField("Сумма, ₽", text: $amountText)
                        .keyboardType(.decimalPad)
                    TextField("Описание (например «ужин»)", text: $title)
                }
                .listRowBackground(Theme.card2)

                Section("Как делить") {
                    Picker("Режим", selection: $mode) {
                        ForEach(SplitMode.allCases) { m in
                            Text(m.title).tag(m)
                        }
                    }
                    .pickerStyle(.menu)
                    modeFields
                    Text(info)
                        .font(.caption)
                        .foregroundColor(Theme.secondary)
                }
                .listRowBackground(Theme.card2)

                if !error.isEmpty {
                    Section {
                        Text(error).foregroundColor(Theme.overdue)
                    }
                    .listRowBackground(Theme.card2)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.card)
            .navigationTitle("Новая трата")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить", action: save)
                }
            }
        }
        .tint(Theme.accent)
    }

    @ViewBuilder
    private var modeFields: some View {
        switch mode {
        case .selected:
            ForEach(event.members) { m in
                Toggle(m.name, isOn: Binding(
                    get: { selected.contains(m.id) },
                    set: { on in
                        if on {
                            _ = selected.insert(m.id)
                        } else {
                            _ = selected.remove(m.id)
                        }
                    }))
            }
        case .manual:
            ForEach(event.members) { m in
                numberRow(m.name, unit: "₽", text: Binding(
                    get: { manual[m.id] ?? "" },
                    set: { manual[m.id] = $0 }))
            }
        case .percent:
            ForEach(event.members) { m in
                numberRow(m.name, unit: "%", text: Binding(
                    get: { percent[m.id] ?? "" },
                    set: { percent[m.id] = $0 }))
            }
        default:
            EmptyView()
        }
    }

    private func numberRow(_ name: String, unit: String, text: Binding<String>) -> some View {
        HStack {
            Text(name)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
            Text(unit).foregroundColor(Theme.secondary)
        }
    }

    private var info: String {
        let a = parseNumber(amountText)
        switch mode {
        case .all:
            return "Поровну на всех участников, включая плательщика."
        case .withoutPayer:
            return "Поровну на всех, кроме плательщика."
        case .onlyPayer:
            return "Личная трата — вся сумма на плательщике."
        case .selected:
            return "Выбрано \(selected.count) из \(event.members.count)."
        case .manual:
            var s = 0.0
            for m in event.members { s += parseNumber(manual[m.id]) }
            s = r2(s)
            if abs(s - a) < 0.01 && a > 0 {
                return "Указано \(money(s)) ✓"
            }
            return "Указано \(money(s)) · осталось \(money(a - s))"
        case .percent:
            var s = 0.0
            for m in event.members { s += parseNumber(percent[m.id]) }
            s = r2(s)
            if abs(s - 100) < 0.01 {
                return "Сумма долей \(percentText(s))% ✓"
            }
            return "Сумма долей \(percentText(s))% · нужно ещё \(percentText(r2(100 - s)))%"
        }
    }

    private func save() {
        let a = parseNumber(amountText)
        guard a > 0, a <= 10_000_000 else {
            error = "Введите корректную сумму (положительное число)"
            return
        }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let desc = String((trimmed.isEmpty ? "трата" : trimmed).prefix(120))

        let result = buildShares(amount: a,
                                 mode: mode,
                                 members: event.members,
                                 payer: payer,
                                 selected: selected,
                                 manual: manual,
                                 percent: percent)
        switch result {
        case .failure(let failure):
            error = failure.text
        case .success(let shares):
            onSave(Expense(payerID: payer, amount: r2(a), title: desc, shares: shares))
            dismiss()
        }
    }
}
