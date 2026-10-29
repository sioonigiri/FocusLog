import SwiftData
import SwiftUI

/// 左から出てくるタスク一覧。カテゴリごとに1枚のカードで、畳める。
struct TaskDrawer: View {
    let onSelect: (TaskTemplate) -> Void
    let onOpenSettings: () -> Void

    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Category> { $0.isArchived == false }, sort: \Category.sortOrder)
    private var categories: [Category]
    @Query(sort: \TaskTemplate.sortOrder) private var tasks: [TaskTemplate]
    @AppStorage("collapsedCategoryIDs") private var collapsedRaw = ""

    @State private var editor: TaskEditorTarget?
    @State private var showingLimit = false
    @State private var taskToDelete: TaskTemplate?
    @State private var categoryToDelete: Category?
    /// 編集中はタスクをタップすると編集画面が開く。
    @State private var isEditing = false

    private var collapsed: Set<String> {
        Set(collapsedRaw.split(separator: ",").map(String.init))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 16) {
                    if categories.isEmpty {
                        Text("右上の＋からタスクを作成してください。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    }
                    ForEach(categories) { category in
                        card(for: category)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }

            Button(action: onOpenSettings) {
                Label("設定", systemImage: "gearshape")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .background(Color(.systemBackground))
        .sheet(item: $editor) { target in
            switch target {
            case .new: TaskEditView(task: nil)
            case .edit(let task): TaskEditView(task: task)
            }
        }
        .alert("タスクは\(Limits.tasks)個まで作成できます", isPresented: $showingLimit) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("使わないタスクを削除してから作成してください。")
        }
        .confirmationDialog("「\(taskToDelete?.name ?? "")」を削除しますか？",
                            isPresented: Binding(get: { taskToDelete != nil }, set: { if !$0 { taskToDelete = nil } }),
                            titleVisibility: .visible) {
            Button("削除", role: .destructive) {
                if let taskToDelete {
                    context.delete(taskToDelete)
                    try? context.save()
                }
            }
        } message: {
            Text("過去の記録は残ります。")
        }
        .confirmationDialog("「\(categoryToDelete?.name ?? "")」を削除しますか？",
                            isPresented: Binding(get: { categoryToDelete != nil }, set: { if !$0 { categoryToDelete = nil } }),
                            titleVisibility: .visible) {
            Button("カテゴリを削除", role: .destructive) {
                categoryToDelete?.archive(in: context)
            }
        } message: {
            Text("このカテゴリのタスクも削除されます。過去の記録はカレンダーに残ります。")
        }
    }

    private var header: some View {
        HStack(spacing: 20) {
            Text("タイマー")
                .font(.title2.bold())
            Spacer()
            Button("タスクを作成", systemImage: "plus", action: addTask)
                .disabled(isEditing)
            Button(isEditing ? "編集を終了" : "タスクを編集",
                   systemImage: isEditing ? "checkmark" : "square.and.pencil") {
                withAnimation(.snappy(duration: 0.25)) { isEditing.toggle() }
            }
            .disabled(tasks.isEmpty && !isEditing)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .font(.title3)
        .padding(.leading, 20)
        .padding(.trailing, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func card(for category: Category) -> some View {
        CategoryCard(
            category: category,
            tasks: tasks.filter { $0.category?.id == category.id },
            isExpanded: !collapsed.contains(category.id.uuidString),
            isEditing: isEditing,
            onToggle: { toggle(category) },
            onSelect: onSelect,
            onEdit: { editor = .edit($0) },
            onDelete: { taskToDelete = $0 },
            onDeleteCategory: { categoryToDelete = category }
        )
    }

    private func toggle(_ category: Category) {
        var set = collapsed
        let id = category.id.uuidString
        if set.contains(id) { set.remove(id) } else { set.insert(id) }
        withAnimation(.snappy(duration: 0.3)) {
            collapsedRaw = set.sorted().joined(separator: ",")
        }
    }

    private func addTask() {
        if tasks.count < Limits.tasks {
            editor = .new
        } else {
            showingLimit = true
        }
    }
}

/// 1つのカテゴリを1枚のカードとして表示する。
private struct CategoryCard: View {
    let category: Category
    let tasks: [TaskTemplate]
    let isExpanded: Bool
    let isEditing: Bool
    let onToggle: () -> Void
    let onSelect: (TaskTemplate) -> Void
    let onEdit: (TaskTemplate) -> Void
    let onDelete: (TaskTemplate) -> Void
    let onDeleteCategory: () -> Void

    private var tint: Color { category.color.color }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: isEditing ? 12 : 10) {
                    if isEditing {
                        // タスクカードの「−」と同じ位置・見た目にそろえる。
                        Button("カテゴリを削除", systemImage: "minus.circle.fill", action: onDeleteCategory)
                            .labelStyle(.iconOnly)
                            .font(.title3)
                            .foregroundStyle(.white, .red)
                            .buttonStyle(.borderless)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .frame(width: 14)
                    }
                    Text(category.name)
                        .font(.headline.bold())
                        .lineLimit(1)
                    Spacer(minLength: 8)
                }
                .padding(.leading, isEditing ? 28 : 16)
                .padding(.trailing, 16)
                .frame(minHeight: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(isExpanded ? "折りたたむ" : "展開する")

            if isExpanded {
                VStack(spacing: 10) {
                    if tasks.isEmpty {
                        Text("タスクがありません")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }
                    ForEach(tasks) { task in
                        taskCard(task)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(tint.opacity(0.07), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    /// 押せることが分かるよう、グループの上に浮かぶ白いカードにする。
    private func taskCard(_ task: TaskTemplate) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return Button { isEditing ? onEdit(task) : onSelect(task) } label: {
            HStack(spacing: 12) {
                if isEditing {
                    Button("削除", systemImage: "minus.circle.fill") { onDelete(task) }
                        .labelStyle(.iconOnly)
                        .font(.title3)
                        .foregroundStyle(.white, .red)
                        .buttonStyle(.borderless)
                        .transition(.scale.combined(with: .opacity))
                }
                Text(task.name)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text("\(task.durationMinutes)分")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                if isEditing {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 28)
                } else {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(tint)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.secondarySystemGroupedBackground), in: shape)
            .shadow(color: .black.opacity(0.06), radius: 4, y: 1)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .contentShape(.contextMenuPreview, shape)
        .contextMenu {
            Button("編集", systemImage: "pencil") { onEdit(task) }
            Button("削除", systemImage: "trash", role: .destructive) { onDelete(task) }
        }
    }
}
