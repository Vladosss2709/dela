import SwiftUI

struct EditTarget: Identifiable {
    let task: TaskItem
    var remind: Bool = false
    var id: UUID { task.id }
}

struct RemindersView: View {
    @EnvironmentObject var store: TaskStore
    @State private var editing: EditTarget?
    @State private var quickTitle = ""

    private let cal = Calendar.current

    private func list(_ pred: (TaskItem) -> Bool) -> [TaskItem] {
        store.tasks.filter(pred).sorted {
            ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture)
        }
    }

    private var overdue: [TaskItem] {
        list { !$0.isDone && ($0.dueDate ?? .distantFuture) < Date() }
    }
    private var today: [TaskItem] {
        list { t in
            guard !t.isDone, let d = t.dueDate else { return false }
            return d >= Date() && cal.isDateInToday(d)
        }
    }
    private var later: [TaskItem] {
        list { t in
            guard !t.isDone, let d = t.dueDate else { return false }
            return d >= Date() && !cal.isDateInToday(d)
        }
    }
    private var noDate: [TaskItem] {
        list { !$0.isDone && $0.dueDate == nil }
    }
    private var done: [TaskItem] {
        list { $0.isDone }
    }

    var body: some View {
        List {
            block("Просрочено", overdue, Theme.overdue)
            block("Сегодня", today, Theme.accent)
            block("Позже", later, .white)
            block("Без срока", noDate, Theme.secondary)
            if !done.isEmpty {
                Section {
                    ForEach(done) { t in row(t) }
                } header: {
                    HStack {
                        Text("Выполнено").foregroundColor(Theme.secondary)
                        Spacer()
                        Button("Очистить") { store.clearDone() }
                            .font(.caption)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.bg)
        .overlay {
            if store.tasks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checklist").font(.system(size: 48))
                    Text("Пока нет задач").font(.headline)
                    Text("Напишите задачу внизу").font(.subheadline)
                }
                .foregroundColor(Theme.secondary)
            }
        }
        .navigationTitle("Дела")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    editing = EditTarget(task: TaskItem(title: ""))
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .safeAreaInset(edge: .bottom) { quickBar }
        .sheet(item: $editing) { target in
            TaskEditor(task: target.task, remind: target.remind)
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }

    @ViewBuilder
    private func block(_ title: String, _ items: [TaskItem], _ color: Color) -> some View {
        if !items.isEmpty {
            Section {
                ForEach(items) { t in row(t) }
            } header: {
                Text(title).foregroundColor(color)
            }
        }
    }

    private func row(_ t: TaskItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                withAnimation { store.toggleDone(t) }
            } label: {
                Image(systemName: t.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(t.isDone ? Theme.accent : Theme.secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text(t.title)
                    .strikethrough(t.isDone)
                    .foregroundColor(t.isDone ? Theme.secondary : .white)
                if let d = t.dueDate {
                    Label(Fmt.due(d), systemImage: "bell.fill")
                        .font(.caption)
                        .foregroundColor(!t.isDone && d < Date() ? Theme.overdue : Theme.secondary)
                }
                if !t.notes.isEmpty {
                    Text(t.notes)
                        .font(.caption)
                        .foregroundColor(Theme.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture { editing = EditTarget(task: t) }
        .listRowBackground(Theme.card)
        .listRowSeparatorTint(Theme.sep)
        .swipeActions {
            Button(role: .destructive) { store.delete(t) } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
    }

    private var quickBar: some View {
        let empty = quickTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return HStack(spacing: 12) {
            TextField("Новая задача…", text: $quickTitle)
                .submitLabel(.done)
                .onSubmit(quickAdd)
            Button {
                editing = EditTarget(task: TaskItem(title: quickTitle), remind: true)
                quickTitle = ""
            } label: {
                Image(systemName: "bell.badge").font(.title3)
            }
            Button(action: quickAdd) {
                Image(systemName: "arrow.up.circle.fill").font(.title)
            }
            .disabled(empty)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Theme.card)
    }

    private func quickAdd() {
        let t = quickTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        store.upsert(TaskItem(title: t))
        quickTitle = ""
    }
}
