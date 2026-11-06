import SwiftUI

extension Theme {
    static let teal = Color(red: 64 / 255, green: 200 / 255, blue: 224 / 255)
    static let star = Color(red: 255 / 255, green: 214 / 255, blue: 10 / 255)
}

struct WishEditTarget: Identifiable {
    let item: WishItem
    var id: UUID { item.id }
}

struct WishlistView: View {
    @EnvironmentObject var store: WishStore
    @State private var kind: WishKind = .book
    @State private var editing: WishEditTarget?
    @State private var quickTitle = ""

    private var all: [WishItem] {
        store.items.filter { $0.kind == kind }
    }

    private func items(_ status: WishStatus) -> [WishItem] {
        all.filter { $0.status == status }.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Раздел", selection: $kind) {
                ForEach(WishKind.allCases) { k in
                    Text(k.tabTitle).tag(k)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            List {
                progressCard
                block(.doing)
                block(.want)
                block(.done)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .overlay {
                if all.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: kind.icon).font(.system(size: 48))
                        Text(kind.emptyTitle).font(.headline)
                        Text("Напишите название внизу").font(.subheadline)
                    }
                    .foregroundColor(Theme.secondary)
                }
            }
        }
        .background(Theme.bg)
        .navigationTitle("Хочу")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    editing = WishEditTarget(item: WishItem(kind: kind, title: ""))
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .safeAreaInset(edge: .bottom) { quickBar }
        .sheet(item: $editing) { target in
            WishEditor(item: target.item)
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }

    // ── Карточка с прогрессом ──

    @ViewBuilder
    private var progressCard: some View {
        if !all.isEmpty {
            let doneCount = all.filter { $0.status == .done }.count
            let doingCount = all.filter { $0.status == .doing }.count
            let wantCount = all.filter { $0.status == .want }.count
            let fraction = Double(doneCount) / Double(all.count)

            Section {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().stroke(Theme.card, lineWidth: 6)
                        Circle()
                            .trim(from: 0, to: CGFloat(fraction))
                            .stroke(Theme.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(Int((fraction * 100).rounded()))%")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.white)
                    }
                    .frame(width: 58, height: 58)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(kind.doneTitle) \(doneCount) из \(all.count)")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("\(WishStatus.doing.title(kind)): \(doingCount) · Хочу: \(wantCount)")
                            .font(.caption)
                            .foregroundColor(Theme.secondary)
                    }
                    Spacer()
                }
                .padding(14)
                .background(Theme.card2)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 10, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
    }

    // ── Секции по статусам ──

    @ViewBuilder
    private func block(_ status: WishStatus) -> some View {
        let list = items(status)
        if !list.isEmpty {
            Section {
                ForEach(list) { item in row(item) }
            } header: {
                Text(status.title(kind))
                    .foregroundColor(headerColor(status))
            }
        }
    }

    private func headerColor(_ status: WishStatus) -> Color {
        switch status {
        case .doing: return Theme.accent
        case .want: return .white
        case .done: return Theme.secondary
        }
    }

    private func row(_ item: WishItem) -> some View {
        HStack(spacing: 12) {
            cover(item.kind)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .foregroundColor(item.status == .done ? Theme.secondary : .white)
                    .lineLimit(2)
                if !item.creator.isEmpty {
                    Text(item.creator)
                        .font(.caption)
                        .foregroundColor(Theme.secondary)
                }
                if item.status == .done && item.rating > 0 {
                    stars(item.rating)
                }
                if !item.note.isEmpty {
                    Text(item.note)
                        .font(.caption)
                        .foregroundColor(Theme.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()

            Button {
                withAnimation { store.advance(item) }
            } label: {
                Image(systemName: item.status.icon)
                    .font(.title2)
                    .foregroundColor(item.status == .want ? Theme.secondary : Theme.accent)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture { editing = WishEditTarget(item: item) }
        .listRowBackground(Theme.card)
        .listRowSeparatorTint(Theme.sep)
        .swipeActions {
            Button(role: .destructive) {
                store.delete(item)
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
    }

    private func cover(_ k: WishKind) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(LinearGradient(colors: [Theme.teal, Theme.indigo],
                                     startPoint: .topLeading,
                                     endPoint: .bottomTrailing))
            Image(systemName: k.icon)
                .font(.system(size: 18))
                .foregroundColor(.white)
        }
        .frame(width: 40, height: 54)
    }

    private func stars(_ rating: Int) -> some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: i <= rating ? "star.fill" : "star")
                    .font(.caption2)
            }
        }
        .foregroundColor(Theme.star)
    }

    // ── Быстрое добавление ──

    private var quickBar: some View {
        let empty = quickTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return HStack(spacing: 12) {
            TextField(kind.addPlaceholder, text: $quickTitle)
                .submitLabel(.done)
                .onSubmit(quickAdd)
            Button {
                editing = WishEditTarget(item: WishItem(kind: kind, title: quickTitle))
                quickTitle = ""
            } label: {
                Image(systemName: "square.and.pencil").font(.title3)
            }
            Button(action: quickAdd) {
                Image(systemName: "arrow.up.circle.fill").font(.title)
            }
            .disabled(empty)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Theme.card)
    }

    private func quickAdd() {
        let t = quickTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        store.upsert(WishItem(kind: kind, title: t))
        quickTitle = ""
    }
}
