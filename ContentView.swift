import SwiftUI

// ───────────────────────────────────────────────────────────
// Главный экран: сетка иконок мини-приложений.
// Чтобы добавить новое мини-приложение:
//   1) добавьте строку в MiniAppRegistry.all
//   2) добавьте case в MiniAppRegistry.view(for:)
// ───────────────────────────────────────────────────────────

struct MiniApp: Identifiable {
    let id: String
    let title: String
    let icon: String      // название SF Symbol
    let color: Color
}

enum MiniAppRegistry {
    static let all: [MiniApp] = [
        MiniApp(id: "reminders", title: "Дела", icon: "checklist", color: Theme.accent),
        MiniApp(id: "expenses", title: "Траты", icon: "creditcard.fill", color: Theme.indigo),
        MiniApp(id: "wishlist", title: "Хочу", icon: "bookmark.fill", color: Theme.teal)
    ]

    @ViewBuilder
    static func view(for id: String) -> some View {
        switch id {
        case "reminders":
            RemindersView()
        case "expenses":
            ExpensesView()
        case "wishlist":
            WishlistView()
        default:
            Text("Скоро")
        }
    }
}

struct ContentView: View {
    @State private var path: [String] = []
    @State private var showHint = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8, alignment: .top), count: 4)

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 22) {
                    ForEach(MiniAppRegistry.all) { app in
                        NavigationLink(value: app.id) {
                            tile(title: app.title, icon: app.icon, color: app.color)
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        showHint = true
                    } label: {
                        placeholderTile
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Приложения")
            .navigationDestination(for: String.self) { id in
                MiniAppRegistry.view(for: id)
            }
            .alert("Новое приложение", isPresented: $showHint) {
                Button("Понятно", role: .cancel) {}
            } message: {
                Text("Здесь появится следующее мини-приложение.")
            }
        }
        .onOpenURL { url in
            if url.host == "reminders" {
                path = ["reminders"]
            }
        }
    }

    private func tile(title: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 15, style: .continuous).fill(color)
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(.white)
            }
            .frame(width: 64, height: 64)
            Text(title)
                .font(.caption)
                .foregroundColor(.white)
        }
    }

    private var placeholderTile: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(Theme.secondary, style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                Image(systemName: "plus")
                    .font(.system(size: 26))
                    .foregroundColor(Theme.secondary)
            }
            .frame(width: 64, height: 64)
            Text("Новое")
                .font(.caption)
                .foregroundColor(.white)
        }
    }
}
