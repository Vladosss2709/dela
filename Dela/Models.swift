import Foundation
import UserNotifications
import WidgetKit

enum Notifier {
    static func requestAuthorization() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func cancel(_ id: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [id.uuidString])
    }

    static func schedule(_ task: TaskItem) {
        cancel(task.id)
        guard !task.isDone, let due = task.dueDate, due > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = task.title
        content.body = task.notes.isEmpty ? "Пора это сделать" : task.notes
        content.sound = .default
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: due)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: task.id.uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}

final class TaskStore: ObservableObject {
    @Published var tasks: [TaskItem] = [] {
        didSet { save() }
    }

    init() {
        migrateIfNeeded()
        load()
        Notifier.requestAuthorization()
        for t in tasks { Notifier.schedule(t) }
    }

    func upsert(_ task: TaskItem) {
        if let i = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[i] = task
        } else {
            tasks.append(task)
        }
        Notifier.schedule(task)
    }

    func toggleDone(_ task: TaskItem) {
        guard let i = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[i].isDone.toggle()
        Notifier.schedule(tasks[i])
    }

    func delete(_ task: TaskItem) {
        Notifier.cancel(task.id)
        tasks.removeAll { $0.id == task.id }
    }

    func clearDone() {
        for t in tasks where t.isDone { Notifier.cancel(t.id) }
        tasks.removeAll { $0.isDone }
    }

    /// Если появился общий контейнер (для виджета), переносим туда старые задачи из Documents.
    private func migrateIfNeeded() {
        guard let group = SharedStorage.groupURL else { return }
        let groupFile = group.appendingPathComponent("tasks.json")
        let oldFile = SharedStorage.documentsURL.appendingPathComponent("tasks.json")
        let fm = FileManager.default
        if !fm.fileExists(atPath: groupFile.path), fm.fileExists(atPath: oldFile.path) {
            try? fm.copyItem(at: oldFile, to: groupFile)
        }
    }

    private func load() {
        tasks = SharedStorage.loadTasks()
    }

    private func save() {
        SharedStorage.saveTasks(tasks)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
