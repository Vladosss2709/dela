import Foundation

struct DiaryEntry: Codable, Equatable {
    var text: String
    var updatedAt: Date
}

/// Записи хранятся по дням: ключ вида "2026-11-23".
final class DiaryStore: ObservableObject {
    @Published var entries: [String: DiaryEntry] = [:] {
        didSet { save() }
    }

    private let fileURL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("diary.json")

    private static let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    init() {
        load()
    }

    static func key(_ date: Date) -> String {
        keyFormatter.string(from: date)
    }

    func entry(for date: Date) -> DiaryEntry? {
        entries[DiaryStore.key(date)]
    }

    /// Пустой текст удаляет запись за этот день.
    func set(date: Date, text: String) {
        let k = DiaryStore.key(date)
        let empty = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if empty {
            if entries[k] != nil {
                entries.removeValue(forKey: k)
            }
            return
        }
        if let old = entries[k], old.text == text {
            return
        }
        entries[k] = DiaryEntry(text: text, updatedAt: Date())
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([String: DiaryEntry].self, from: data) else { return }
        // Записи без текста (остались от старой версии с настроением) не показываем.
        entries = decoded.filter {
            !$0.value.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
