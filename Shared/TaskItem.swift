import Foundation

struct TaskItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var notes: String = ""
    var dueDate: Date? = nil
    var isDone: Bool = false
}

/// Общее хранилище задач: приложение и виджет читают один и тот же файл.
enum SharedStorage {
    static let defaultGroup = "group.com.mydela.app"

    /// Все группы, которые стоит попробовать: из профиля подписи, из Info.plist (AltStore) и стандартная.
    private static func groupsFromProvisioningProfile() -> [String] {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .isoLatin1),
              let start = text.range(of: "<?xml"),
              let end = text.range(of: "</plist>") else { return [] }
        let xml = String(text[start.lowerBound..<end.upperBound])
        guard let xmlData = xml.data(using: .isoLatin1),
              let plist = try? PropertyListSerialization.propertyList(from: xmlData, options: [], format: nil) as? [String: Any],
              let ents = plist["Entitlements"] as? [String: Any],
              let groups = ents["com.apple.security.application-groups"] as? [String] else { return [] }
        return groups
    }

    private static func candidateGroups() -> [String] {
        var list = SharedStorage.groupsFromProvisioningProfile()
        if let alt = Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") as? [String] {
            list.append(contentsOf: alt)
        }
        list.append(SharedStorage.defaultGroup)
        var seen = Set<String>()
        return list.filter { seen.insert($0).inserted }
    }

    /// Первая группа, для которой система реально выдала общую папку.
    private static let resolved: (id: String, url: URL?) = {
        let groups = SharedStorage.candidateGroups()
        for g in groups {
            if let u = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: g) {
                return (id: g, url: u)
            }
        }
        return (id: groups.first ?? SharedStorage.defaultGroup, url: nil)
    }()

    static var groupID: String { resolved.id }
    static var groupURL: URL? { resolved.url }

    static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static var tasksURL: URL {
        (groupURL ?? documentsURL).appendingPathComponent("tasks.json")
    }

    static func loadTasks() -> [TaskItem] {
        guard let data = try? Data(contentsOf: tasksURL),
              let tasks = try? JSONDecoder().decode([TaskItem].self, from: data) else { return [] }
        return tasks
    }

    static func saveTasks(_ tasks: [TaskItem]) {
        if let data = try? JSONEncoder().encode(tasks) {
            try? data.write(to: tasksURL, options: .atomic)
        }
    }
}

enum Fmt {
    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = format
        return f
    }

    static func time(_ d: Date) -> String {
        formatter("HH:mm").string(from: d)
    }

    static func day(_ d: Date, now: Date = Date()) -> String {
        let cal = Calendar.current
        if cal.isDate(d, inSameDayAs: now) { return "Сегодня" }
        if let t = cal.date(byAdding: .day, value: 1, to: now), cal.isDate(d, inSameDayAs: t) { return "Завтра" }
        if let y = cal.date(byAdding: .day, value: -1, to: now), cal.isDate(d, inSameDayAs: y) { return "Вчера" }
        return formatter("d MMM").string(from: d)
    }

    static func due(_ d: Date, now: Date = Date()) -> String {
        day(d, now: now) + ", " + time(d)
    }

    static func tasks(_ n: Int) -> String {
        let r10 = n % 10, r100 = n % 100
        if r10 == 1 && r100 != 11 { return "\(n) задача" }
        if r10 >= 2 && r10 <= 4 && !(r100 >= 12 && r100 <= 14) { return "\(n) задачи" }
        return "\(n) задач"
    }
}
