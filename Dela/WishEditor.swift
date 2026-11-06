import SwiftUI

struct WishEditor: View {
    @EnvironmentObject var store: WishStore
    @Environment(\.dismiss) private var dismiss

    @State private var item: WishItem

    init(item: WishItem) {
        _item = State(initialValue: item)
    }

    private var isNew: Bool {
        !store.items.contains { $0.id == item.id }
    }

    private var titleEmpty: Bool {
        item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(item.kind.titleLabel, text: $item.title)
                    TextField(item.kind.creatorLabel, text: $item.creator)
                }
                .listRowBackground(Theme.card2)

                Section("Статус") {
                    Picker("Статус", selection: $item.status) {
                        ForEach(WishStatus.allCases) { s in
                            Text(s.short(item.kind)).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)

                    if item.status == .done {
                        HStack {
                            Text("Оценка")
                            Spacer()
                            ForEach(1...5, id: \.self) { i in
                                Button {
                                    item.rating = (item.rating == i) ? 0 : i
                                } label: {
                                    Image(systemName: i <= item.rating ? "star.fill" : "star")
                                        .font(.title3)
                                        .foregroundColor(Theme.star)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }
                .listRowBackground(Theme.card2)

                Section("Заметка") {
                    TextField("Почему хочу / впечатления", text: $item.note, axis: .vertical)
                        .lineLimit(1...5)
                }
                .listRowBackground(Theme.card2)

                if !isNew {
                    Section {
                        Button("Удалить", role: .destructive) {
                            store.delete(item)
                            dismiss()
                        }
                    }
                    .listRowBackground(Theme.card2)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.card)
            .navigationTitle(isNew ? "Новая запись" : "Запись")
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
        .tint(Theme.accent)
        .presentationDetents([.medium, .large])
    }

    private func save() {
        item.title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        item.creator = item.creator.trimmingCharacters(in: .whitespacesAndNewlines)
        if item.status != .done { item.rating = 0 }
        store.upsert(item)
        dismiss()
    }
}
