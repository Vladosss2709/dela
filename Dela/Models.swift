import Foundation
import UserNotifications

struct TaskItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var notes: String = ""
    var dueDate: Date? = nil
    var isDone: Bool = false
}

func formatDue(_ d: Date) -> String {
    let cal = Calendar.current
    let tf = DateFormatter()
    tf.locale = Locale(identifier: "ru_RU")
    tf.dateFormat = "HH:mm"
    let time = tf.string(from: d)
    if cal.isDateInToday(d) { return "Сегодня, \(time)" }
    if cal.isDateInTomorrow(d) { return "Завтра, \(time)" }
    if cal.isDateInYesterday(d) { return "Вчера, \(time)" }
    let df = DateFormatter()
    df.locale = Locale(identifier: "ru_RU")
    df.dateFormat = "d MMM, HH:mm"
    return df.string(from: d)
}

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

    private let fileURL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("tasks.json")

    init() {
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

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([TaskItem].self, from: data) else { return }
        tasks = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(tasks) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
