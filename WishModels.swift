import Foundation

enum WishKind: String, Codable, CaseIterable, Identifiable {
    case book, movie

    var id: String { rawValue }

    var tabTitle: String { self == .book ? "Книги" : "Фильмы" }
    var icon: String { self == .book ? "book.closed.fill" : "film.fill" }
    var creatorLabel: String { self == .book ? "Автор" : "Режиссёр" }
    var titleLabel: String { self == .book ? "Название книги" : "Название фильма" }
    var addPlaceholder: String { self == .book ? "Какую книгу хотите прочитать?" : "Какой фильм хотите посмотреть?" }
    var doneTitle: String { self == .book ? "Прочитано" : "Просмотрено" }
    var emptyTitle: String { self == .book ? "Список книг пуст" : "Список фильмов пуст" }
}

enum WishStatus: String, Codable, CaseIterable, Identifiable {
    case want, doing, done

    var id: String { rawValue }

    func title(_ kind: WishKind) -> String {
        switch self {
        case .want: return kind == .book ? "Хочу прочитать" : "Хочу посмотреть"
        case .doing: return kind == .book ? "Читаю сейчас" : "Смотрю сейчас"
        case .done: return kind == .book ? "Прочитано" : "Просмотрено"
        }
    }

    func short(_ kind: WishKind) -> String {
        switch self {
        case .want: return "Хочу"
        case .doing: return kind == .book ? "Читаю" : "Смотрю"
        case .done: return "Готово"
        }
    }

    var icon: String {
        switch self {
        case .want: return "circle"
        case .doing: return "circle.lefthalf.filled"
        case .done: return "checkmark.circle.fill"
        }
    }
}

struct WishItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var kind: WishKind
    var title: String
    var creator: String = ""
    var note: String = ""
    var status: WishStatus = .want
    var rating: Int = 0
    var createdAt = Date()
}

final class WishStore: ObservableObject {
    @Published var items: [WishItem] = [] {
        didSet { save() }
    }

    private let fileURL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("wishlist.json")

    init() {
        load()
    }

    func upsert(_ item: WishItem) {
        if let i = items.firstIndex(where: { $0.id == item.id }) {
            items[i] = item
        } else {
            items.append(item)
        }
    }

    /// Хочу → Читаю/Смотрю → Готово → снова Хочу
    func advance(_ item: WishItem) {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        switch items[i].status {
        case .want:
            items[i].status = .doing
        case .doing:
            items[i].status = .done
        case .done:
            items[i].status = .want
            items[i].rating = 0
        }
    }

    func delete(_ item: WishItem) {
        items.removeAll { $0.id == item.id }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([WishItem].self, from: data) else { return }
        items = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
