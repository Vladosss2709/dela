import SwiftUI

extension Theme {
    static let coral = Color(red: 255 / 255, green: 107 / 255, blue: 107 / 255)
}

struct DiaryView: View {
    @EnvironmentObject var store: DiaryStore

    @State private var month = Date()          // любой день показываемого месяца
    @State private var selected = Date()
    @State private var text = ""
    @FocusState private var focused: Bool

    private static let weekdays = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]

    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "ru_RU")
        c.firstWeekday = 2   // неделя с понедельника
        return c
    }

    private func trimmed(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Есть ли изменения, которые ещё не сохранены.
    private var isDirty: Bool {
        trimmed(text) != trimmed(store.entry(for: selected)?.text ?? "")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                monthHeader
                calendarCard
                editorCard
            }
            .padding(16)
        }
        .background(Theme.bg.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Дневник")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Сегодня") { goToday() }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Готово") { focused = false }
            }
        }
        .onAppear { loadSelected() }
        .onDisappear { saveIfNeeded() }
    }

    // ── Месяц ──

    private var monthHeader: some View {
        HStack {
            Text(capitalized(format(month, "LLLL yyyy")))
                .font(.title2.weight(.semibold))
                .foregroundColor(.white)
            Spacer()
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left").font(.title3).frame(width: 36, height: 32)
            }
            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right").font(.title3).frame(width: 36, height: 32)
            }
        }
    }

    private var calendarCard: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                ForEach(DiaryView.weekdays, id: \.self) { d in
                    Text(d)
                        .font(.caption)
                        .foregroundColor(Theme.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 2) {
                ForEach(Array(gridDays().enumerated()), id: \.offset) { item in
                    if let d = item.element {
                        dayCell(d)
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 10)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func gridDays() -> [Date?] {
        let c = cal
        guard let interval = c.dateInterval(of: .month, for: month),
              let days = c.range(of: .day, in: .month, for: month) else { return [] }
        let first = interval.start
        let weekday = c.component(.weekday, from: first)
        let lead = (weekday - c.firstWeekday + 7) % 7
        var out: [Date?] = Array(repeating: nil, count: lead)
        for d in days {
            out.append(c.date(byAdding: .day, value: d - 1, to: first))
        }
        return out
    }

    private func dayCell(_ date: Date) -> some View {
        let c = cal
        let isSelected = c.isDate(date, inSameDayAs: selected)
        let isToday = c.isDateInToday(date)
        let hasEntry = store.entry(for: date) != nil
        return Button {
            select(date)
        } label: {
            VStack(spacing: 2) {
                Text("\(c.component(.day, from: date))")
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(isSelected ? Theme.accent : Color.clear))
                    .overlay(Circle().stroke(Theme.accent, lineWidth: (isToday && !isSelected) ? 1.5 : 0))
                Circle()
                    .fill(hasEntry ? Theme.accentLight : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .frame(height: 44)
        }
        .buttonStyle(.plain)
    }

    // ── Запись дня ──

    private var editorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(capitalized(format(selected, "EEEE, d MMMM")))
                .font(.headline)
                .foregroundColor(.white)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .focused($focused)
                    .scrollContentBackground(.hidden)
                    .foregroundColor(.white)
                    .frame(minHeight: 170)
                    .padding(4)
                    .background(Theme.card2)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                if text.isEmpty {
                    Text("Как прошёл день? О чём думаешь?")
                        .foregroundColor(Theme.secondary)
                        .padding(.top, 12)
                        .padding(.leading, 9)
                        .allowsHitTesting(false)
                }
            }

            HStack {
                statusLabel
                Spacer()
                Text("\(text.count) симв.")
                    .foregroundColor(Theme.secondary)
            }
            .font(.caption)

            Button {
                commit()
                focused = false
            } label: {
                Text("Сохранить")
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isDirty ? Theme.accent : Theme.card2)
                    .foregroundColor(isDirty ? .white : Theme.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!isDirty)
        }
        .padding(16)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var statusLabel: some View {
        if isDirty {
            Text("Есть несохранённые изменения")
                .foregroundColor(Theme.overdue)
        } else if store.entry(for: selected) != nil {
            Text("Сохранено")
                .foregroundColor(Theme.secondary)
        } else {
            Text("Запись пока пуста")
                .foregroundColor(Theme.secondary)
        }
    }

    // ── Действия ──

    private func commit() {
        store.set(date: selected, text: text)
    }

    /// Чтобы ничего не потерялось: при смене дня или выходе несохранённый текст сохраняется сам.
    private func saveIfNeeded() {
        if isDirty { commit() }
    }

    private func select(_ date: Date) {
        focused = false
        saveIfNeeded()
        selected = date
        loadSelected()
    }

    private func loadSelected() {
        text = store.entry(for: selected)?.text ?? ""
    }

    private func goToday() {
        focused = false
        saveIfNeeded()
        month = Date()
        selected = Date()
        loadSelected()
    }

    private func shiftMonth(_ delta: Int) {
        if let m = cal.date(byAdding: .month, value: delta, to: month) {
            month = m
        }
    }

    // ── Форматирование ──

    private func format(_ date: Date, _ pattern: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = pattern
        return f.string(from: date)
    }

    private func capitalized(_ s: String) -> String {
        s.prefix(1).uppercased() + s.dropFirst()
    }
}
