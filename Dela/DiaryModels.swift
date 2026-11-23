import Foundation

struct DiaryEntry: Codable, Equatable {
    var text: String
    var mood: Int          // 0 — не выбрано, 1…5 — от плохого к отличному
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

    /// Пустой текст без настроения удаляет запись.
    func set(date: Date, text: String, mood: Int) {
        let k = DiaryStore.key(date)
        let empty = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if empty && mood == 0 {
            if entries[k] != nil {
                entries.removeValue(forKey: k)
            }
            return
        }
        if let old = entries[k], old.text == text, old.mood == mood {
            return
        }
        entries[k] = DiaryEntry(text: text, mood: mood, updatedAt: Date())
    }

    /// Сколько дней подряд есть записи. Если сегодня ещё пусто, считаем от вчера.
    func streak(today: Date = Date()) -> Int {
        let cal = Calendar.current
        var day = today
        if entry(for: day) == nil {
            day = cal.date(byAdding: .day, value: -1, to: day) ?? day
        }
        var n = 0
        while entry(for: day) != nil {
            n += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return n
    }

    func count(inMonthOf date: Date) -> Int {
        let cal = Calendar.current
        return entries.keys.filter { key in
            guard let d = DiaryStore.keyFormatter.date(from: key) else { return false }
            return cal.isDate(d, equalTo: date, toGranularity: .month)
        }.count
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([String: DiaryEntry].self, from: data) else { return }
        entries = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
