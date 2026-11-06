import WidgetKit
import SwiftUI

struct TaskEntry: TimelineEntry {
    let date: Date
    let tasks: [TaskItem]   // невыполненные, по возрастанию срока (просроченные первыми)

    /// Что показать в малом виджете: ближайшее будущее, иначе просроченное, иначе без срока.
    var featured: TaskItem? {
        if let t = tasks.first(where: { isUpcoming($0) }) { return t }
        if let t = tasks.first(where: { $0.dueDate != nil }) { return t }
        return tasks.first
    }

    private func isUpcoming(_ t: TaskItem) -> Bool {
        guard let d = t.dueDate else { return false }
        return d >= date
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> TaskEntry {
        TaskEntry(date: Date(), tasks: [
            TaskItem(title: "Позвонить маме", dueDate: Date().addingTimeInterval(7200)),
            TaskItem(title: "Купить продукты", dueDate: Date().addingTimeInterval(90000))
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (TaskEntry) -> Void) {
        completion(entry(at: Date(), all: SharedStorage.loadTasks()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TaskEntry>) -> Void) {
        let now = Date()
        let all = SharedStorage.loadTasks()
        var dates: [Date] = [now]
        let upcoming = all.filter { !$0.isDone }
            .compactMap { $0.dueDate }
            .filter { $0 > now }
            .sorted()
        dates.append(contentsOf: upcoming.prefix(12))
        let entries = dates.map { entry(at: $0, all: all) }
        let refresh = Calendar.current.date(byAdding: .hour, value: 6, to: now) ?? now.addingTimeInterval(21600)
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }

    private func entry(at date: Date, all: [TaskItem]) -> TaskEntry {
        let sorted = all
            .filter { !$0.isDone }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        return TaskEntry(date: date, tasks: sorted)
    }
}

extension View {
    @ViewBuilder
    func widgetBackground(_ color: Color) -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(color, for: .widget)
        } else {
            background(color)
        }
    }
}

struct SmallView: View {
    let entry: TaskEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Дела", systemImage: "bell.fill")
                .font(.caption.weight(.medium))
                .foregroundColor(Theme.accent)
            Spacer(minLength: 0)
            if let t = entry.featured {
                Text(t.title)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .lineLimit(2)
                if let d = t.dueDate {
                    let late = d < entry.date
                    Text(Fmt.time(d))
                        .font(.system(size: 26, weight: .medium))
                        .foregroundColor(late ? Theme.overdue : Theme.accent)
                    Text(Fmt.day(d, now: entry.date))
                        .font(.caption)
                        .foregroundColor(Theme.secondary)
                } else {
                    Text("Без срока")
                        .font(.caption)
                        .foregroundColor(Theme.secondary)
                }
            } else {
                Text("Нет задач")
                    .font(.subheadline)
                    .foregroundColor(Theme.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MediumView: View {
    let entry: TaskEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Дела", systemImage: "checklist")
                    .font(.caption.weight(.medium))
                    .foregroundColor(Theme.accent)
                Spacer()
                Text(Fmt.tasks(entry.tasks.count))
                    .font(.caption)
                    .foregroundColor(Theme.secondary)
            }
            if entry.tasks.isEmpty {
                Spacer()
                Text("Нет задач")
                    .font(.subheadline)
                    .foregroundColor(Theme.secondary)
                Spacer()
            } else {
                ForEach(Array(entry.tasks.prefix(3))) { t in
                    HStack {
                        Text(t.title)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Spacer()
                        if let d = t.dueDate {
                            Text(Fmt.due(d, now: entry.date))
                                .font(.caption)
                                .foregroundColor(d < entry.date ? Theme.overdue : Theme.secondary)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DelaWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: TaskEntry

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                MediumView(entry: entry)
            default:
                SmallView(entry: entry)
            }
        }
        .widgetBackground(Theme.card)
        .widgetURL(URL(string: "dela://reminders"))
    }
}

struct DelaWidget: Widget {
    let kind = "DelaWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            DelaWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Дела")
        .description("Ближайшие напоминания и время")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct DelaWidgetBundle: WidgetBundle {
    var body: some Widget {
        DelaWidget()
    }
}
