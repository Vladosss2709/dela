import SwiftUI

// ───────── Список событий ─────────

struct ExpensesView: View {
    @EnvironmentObject var store: ExpenseStore
    @State private var showNew = false
    @State private var toDelete: TripEvent?

    var body: some View {
        List {
            ForEach(store.events) { e in
                NavigationLink {
                    EventView(eventID: e.id)
                } label: {
                    row(e)
                }
                .listRowBackground(Theme.card)
                .listRowSeparatorTint(Theme.sep)
                .swipeActions {
                    Button(role: .destructive) {
                        toDelete = e
                    } label: {
                        Label("Удалить", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.bg)
        .overlay {
            if store.events.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "creditcard").font(.system(size: 48))
                    Text("Пока нет событий").font(.headline)
                    Text("Создайте первое кнопкой «+»").font(.subheadline)
                }
                .foregroundColor(Theme.secondary)
            }
        }
        .navigationTitle("Траты")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showNew = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showNew) {
            NewEventSheet()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
        .alert("Удалить событие?",
               isPresented: Binding(get: { toDelete != nil },
                                    set: { if !$0 { toDelete = nil } })) {
            Button("Удалить навсегда", role: .destructive) {
                if let e = toDelete { store.deleteEvent(e.id) }
                toDelete = nil
            }
            Button("Отмена", role: .cancel) { toDelete = nil }
        } message: {
            Text("Все траты и расчёты будут удалены. Действие необратимо.")
        }
    }

    private func row(_ e: TripEvent) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(e.name).foregroundColor(.white)
                Text("\(e.members.count) участн. · \(e.expenses.count) трат")
                    .font(.caption)
                    .foregroundColor(Theme.secondary)
            }
            Spacer()
            Text(money(e.total)).foregroundColor(.white)
        }
    }
}

// ───────── Новое событие ─────────

struct NewEventSheet: View {
    @EnvironmentObject var store: ExpenseStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var members: [String] = ["Я"]
    @State private var newName = ""
    @State private var error = ""

    private var newNameEmpty: Bool {
        newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Название (например «Сочи 2026»)", text: $name)
                }
                .listRowBackground(Theme.card2)

                if !error.isEmpty {
                    Section {
                        Text(error).foregroundColor(Theme.overdue)
                    }
                    .listRowBackground(Theme.card2)
                }

                Section("Участники") {
                    ForEach(members, id: \.self) { m in
                        Text(m)
                    }
                    .onDelete { offsets in
                        members.remove(atOffsets: offsets)
                    }
                    HStack {
                        TextField("Имя участника", text: $newName)
                            .submitLabel(.done)
                            .onSubmit(addMember)
                        Button("Добавить", action: addMember)
                            .buttonStyle(.borderless)
                            .disabled(newNameEmpty)
                    }
                }
                .listRowBackground(Theme.card2)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.card)
            .navigationTitle("Новое событие")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Создать", action: create)
                }
            }
        }
        .tint(Theme.accent)
    }

    private func addMember() {
        let clean = String(newName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(64))
        guard !clean.isEmpty else { return }
        if !members.contains(where: { $0.lowercased() == clean.lowercased() }) {
            members.append(clean)
        }
        newName = ""
    }

    private func create() {
        let clean = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(64))
        if clean.isEmpty {
            error = "Название не может быть пустым"
            return
        }
        if members.isEmpty {
            error = "Добавьте хотя бы одного участника"
            return
        }
        store.addEvent(name: clean, memberNames: members)
        dismiss()
    }
}

// ───────── Экран события ─────────

struct EventView: View {
    let eventID: UUID
    @EnvironmentObject var store: ExpenseStore
    @Environment(\.dismiss) private var dismiss

    @State private var tab = 0
    @State private var showAdd = false
    @State private var newMember = ""
    @State private var memberToRemove: Member?
    @State private var confirmDelete = false

    private var event: TripEvent? {
        store.events.first { $0.id == eventID }
    }

    var body: some View {
        Group {
            if let event = event {
                content(event)
            } else {
                Color.clear
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle(event?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func content(_ event: TripEvent) -> some View {
        VStack(spacing: 0) {
            summaryCard(event)
            Picker("Раздел", selection: $tab) {
                Text("Траты").tag(0)
                Text("Итоги").tag(1)
                Text("Участники").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            Group {
                if tab == 0 {
                    expensesList(event)
                } else if tab == 1 {
                    settlementList(event)
                } else {
                    membersList(event)
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if tab != 2 {
                Button {
                    showAdd = true
                } label: {
                    Label("Трата", systemImage: "plus")
                        .font(.body.weight(.medium))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(Theme.accent)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .padding(16)
            }
        }
        .sheet(isPresented: $showAdd) {
            AddExpenseSheet(event: event) { expense in
                store.addExpense(expense, to: eventID)
            }
            .preferredColorScheme(.dark)
        }
        .alert("Удалить участника?",
               isPresented: Binding(get: { memberToRemove != nil },
                                    set: { if !$0 { memberToRemove = nil } })) {
            Button("Удалить", role: .destructive) {
                if let m = memberToRemove { store.removeMember(m.id, from: eventID) }
                memberToRemove = nil
            }
            Button("Отмена", role: .cancel) { memberToRemove = nil }
        } message: {
            Text("Траты этого участника как плательщика и его доли в других тратах тоже удалятся. Баланс пересчитается.")
        }
        .confirmationDialog("Удалить событие?",
                            isPresented: $confirmDelete,
                            titleVisibility: .visible) {
            Button("Удалить навсегда", role: .destructive) {
                store.deleteEvent(eventID)
                dismiss()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Все траты и расчёты будут удалены. Действие необратимо.")
        }
    }

    // ── Сводка ──

    private func summaryCard(_ event: TripEvent) -> some View {
        HStack {
            stat("Участников", "\(event.members.count)")
            Spacer()
            stat("Трат", "\(event.expenses.count)")
            Spacer()
            stat("Общая сумма", money(event.total))
        }
        .padding(14)
        .background(Theme.card2)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(16)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundColor(Theme.secondary)
            Text(value).font(.headline).foregroundColor(.white)
        }
    }

    // ── Вкладка «Траты» ──

    private func expensesList(_ event: TripEvent) -> some View {
        List {
            if event.expenses.isEmpty {
                Text("Пока нет ни одной траты")
                    .foregroundColor(Theme.secondary)
                    .listRowBackground(Color.clear)
            }
            ForEach(event.expenses.reversed()) { x in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(x.title).foregroundColor(.white)
                        Text("\(event.memberName(x.payerID)) заплатил · на \(x.shares.count) чел.")
                            .font(.caption)
                            .foregroundColor(Theme.secondary)
                    }
                    Spacer()
                    Text(money(x.amount)).foregroundColor(.white)
                }
                .listRowBackground(Theme.card)
                .listRowSeparatorTint(Theme.sep)
                .swipeActions {
                    Button(role: .destructive) {
                        store.deleteExpense(x.id, from: eventID)
                    } label: {
                        Label("Удалить", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // ── Вкладка «Итоги» ──

    private func settlementList(_ event: TripEvent) -> some View {
        let s = event.settlement()
        let clean = event.expenses.isEmpty || s.balances.values.allSatisfy { abs($0) < 0.01 }
        return List {
            if clean {
                Text("Всё чисто — никто никому не должен")
                    .foregroundColor(Theme.secondary)
                    .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(event.members) { m in
                        balanceRow(m, s.balances[m.id] ?? 0)
                    }
                } header: {
                    Text("Балансы участников")
                }
                Section {
                    if s.transfers.isEmpty {
                        Text("Переводов не требуется")
                            .foregroundColor(Theme.secondary)
                            .listRowBackground(Theme.card)
                    }
                    ForEach(s.transfers) { t in
                        HStack {
                            Text(event.memberName(t.from)).foregroundColor(.white)
                            Image(systemName: "arrow.right").foregroundColor(Theme.accent)
                            Text(event.memberName(t.to)).foregroundColor(.white)
                            Spacer()
                            Text(money(t.amount)).font(.headline).foregroundColor(.white)
                        }
                        .listRowBackground(Theme.card)
                        .listRowSeparatorTint(Theme.sep)
                    }
                } header: {
                    Text("Кто кому должен (с учётом взаимозачёта)")
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func balanceRow(_ m: Member, _ b: Double) -> some View {
        let positive = b > 0.01
        let negative = b < -0.01
        let color: Color = positive ? Theme.good : (negative ? Theme.overdue : Theme.secondary)
        let sign = positive ? "+" : (negative ? "−" : "")
        let note = positive ? "должны ему" : (negative ? "должен он" : "")
        return HStack {
            Text(m.name).foregroundColor(.white)
            Spacer()
            Text(sign + money(abs(b))).foregroundColor(color)
            Text(note)
                .font(.caption)
                .foregroundColor(Theme.secondary)
                .frame(width: 78, alignment: .leading)
        }
        .listRowBackground(Theme.card)
        .listRowSeparatorTint(Theme.sep)
    }

    // ── Вкладка «Участники» ──

    private func membersList(_ event: TripEvent) -> some View {
        List {
            Section {
                ForEach(event.members) { m in
                    Text(m.name)
                        .foregroundColor(.white)
                        .listRowBackground(Theme.card)
                        .swipeActions {
                            if event.members.count > 1 {
                                Button(role: .destructive) {
                                    memberToRemove = m
                                } label: {
                                    Label("Удалить", systemImage: "person.fill.xmark")
                                }
                            }
                        }
                }
                HStack {
                    TextField("Имя участника", text: $newMember)
                        .submitLabel(.done)
                        .onSubmit(addMember)
                    Button("Добавить", action: addMember)
                        .buttonStyle(.borderless)
                        .disabled(newMember.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .listRowBackground(Theme.card)
            }
            Section {
                Button("Удалить событие", role: .destructive) {
                    confirmDelete = true
                }
                .listRowBackground(Theme.card)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func addMember() {
        store.addMember(named: newMember, to: eventID)
        newMember = ""
    }
}
