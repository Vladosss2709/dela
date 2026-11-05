import SwiftUI

struct TaskEditor: View {
    @EnvironmentObject var store: TaskStore
    @Environment(\.dismiss) private var dismiss

    @State private var task: TaskItem
    @State private var hasDate: Bool
    @State private var date: Date

    init(task: TaskItem) {
        _task = State(initialValue: task)
        _hasDate = State(initialValue: task.dueDate != nil)
        _date = State(initialValue: task.dueDate ?? TaskEditor.defaultDate())
    }

    static func defaultDate() -> Date {
        let c = Calendar.current
        let next = c.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        let comps = c.dateComponents([.year, .month, .day, .hour], from: next)
        return c.date(from: comps) ?? next
    }

    private var isNew: Bool { !store.tasks.contains { $0.id == task.id } }
    private var titleEmpty: Bool {
        task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Что нужно сделать?", text: $task.title, axis: .vertical)
                }
                Section("Заметка") {
                    TextField("Подробности (необязательно)", text: $task.notes, axis: .vertical)
                        .lineLimit(1...4)
                }
                Section("Напоминание") {
                    Toggle("Напомнить", isOn: $hasDate.animation())
                    if hasDate {
                        DatePicker("Когда", selection: $date,
                                   displayedComponents: [.date, .hourAndMinute])
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                chip("+15 мин") { date = Date().addingTimeInterval(15 * 60) }
                                chip("+1 час") { date = Date().addingTimeInterval(60 * 60) }
                                chip("Вечером") { date = at(hour: 19, plusDays: 0) }
                                chip("Завтра утром") { date = at(hour: 9, plusDays: 1) }
                            }
                        }
                    }
                }
                if !isNew {
                    Section {
                        Button("Удалить задачу", role: .destructive) {
                            store.delete(task)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "Новая задача" : "Задача")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить", action: save).disabled(titleEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func chip(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .controlSize(.small)
    }

    private func at(hour: Int, plusDays: Int) -> Date {
        let c = Calendar.current
        let day = c.date(byAdding: .day, value: plusDays, to: Date()) ?? Date()
        var d = c.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
        if d < Date() { d = c.date(byAdding: .day, value: 1, to: d) ?? d }
        return d
    }

    private func save() {
        task.title = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
        task.dueDate = hasDate ? date : nil
        store.upsert(task)
        dismiss()
    }
}
