import SwiftData
import SwiftUI

struct CategoryEditView: View {
    let category: Category?
    /// 新規作成したカテゴリを受け取る（タスク作成画面から開いたとき用）。
    var onCreate: ((Category) -> Void)?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Category> { $0.isArchived == false }, sort: \Category.sortOrder)
    private var categories: [Category]

    @State private var name: String
    @State private var color: CategoryColor

    init(category: Category?, onCreate: ((Category) -> Void)? = nil) {
        self.category = category
        self.onCreate = onCreate
        _name = State(initialValue: category?.name ?? "")
        _color = State(initialValue: category?.color ?? .blue)
    }

    /// 他のカテゴリが使っている色。
    private var usedColors: Set<CategoryColor> {
        Set(categories.filter { $0.id != category?.id }.map(\.color))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("名前") {
                    TextField("", text: $name)
                        .accessibilityLabel("カテゴリ名")
                }
                Section("色") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(CategoryColor.allCases) { option in
                            Button { color = option } label: {
                                VStack(spacing: 4) {
                                    Circle()
                                        .fill(option.color)
                                        .frame(width: 40, height: 40)
                                        .overlay {
                                            if option == color {
                                                Image(systemName: "checkmark")
                                                    .font(.headline)
                                                    .foregroundStyle(option.foreground)
                                            }
                                        }
                                    Text(usedColors.contains(option) ? "使用中" : " ")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(option.name)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(category == nil ? "カテゴリを追加" : "カテゴリを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let category {
            category.name = trimmed
            category.colorKey = color.rawValue
        } else {
            let nextOrder = (categories.map(\.sortOrder).max() ?? -1) + 1
            let newCategory = Category(name: trimmed, color: color, sortOrder: nextOrder)
            context.insert(newCategory)
            onCreate?(newCategory)
        }
        try? context.save()
        dismiss()
    }
}

extension Category {
    /// 過去の記録を残すため、カテゴリ自体は消さずにアーカイブする。中のタスクは削除する。
    func archive(in context: ModelContext) {
        isArchived = true
        tasks?.forEach(context.delete)
        try? context.save()
    }
}
