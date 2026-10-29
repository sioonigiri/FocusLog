import SwiftData
import SwiftUI

enum TaskEditorTarget: Identifiable {
    case new
    case edit(TaskTemplate)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let task): task.id.uuidString
        }
    }
}

struct TaskEditView: View {
    let task: TaskTemplate?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Category> { $0.isArchived == false }, sort: \Category.sortOrder)
    private var categories: [Category]
    @Query(sort: \TaskTemplate.sortOrder) private var tasks: [TaskTemplate]

    @State private var name: String
    @State private var categoryID: UUID?
    @State private var minutes: Int
    @State private var creatingCategory = false
    /// 作成したカテゴリ。シートが閉じてから選択する（閉じる前に選ぶと、この画面ごと閉じてしまうため）。
    @State private var createdCategoryID: UUID?
    @State private var showingLimit = false

    private let presets = [15, 25, 30, 45, 60]

    init(task: TaskTemplate?) {
        self.task = task
        _name = State(initialValue: task?.name ?? "")
        _categoryID = State(initialValue: task?.category?.id)
        _minutes = State(initialValue: min(task?.durationMinutes ?? 25, Limits.timerMinutes.upperBound))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("タスク名") {
                    TextField("例：フランス語文法", text: $name)
                }
                Section("カテゴリ") {
                    ForEach(categories) { category in
                        Button { categoryID = category.id } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(category.color.color)
                                    .frame(width: 12, height: 12)
                                Text(category.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if category.id == categoryID {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        // ボタンの色（アクセントカラー）が名前に付かないようにする。
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(category.id == categoryID ? .isSelected : [])
                    }
                    Button("新しいカテゴリを作成", systemImage: "plus") {
                        if categories.count < Limits.categories {
                            creatingCategory = true
                        } else {
                            showingLimit = true
                        }
                    }
                }
                Section("タイマー時間") {
                    HStack {
                        ForEach(presets, id: \.self) { preset in
                            Button("\(preset)") { minutes = preset }
                                .buttonStyle(.bordered)
                                .tint(minutes == preset ? .accentColor : .secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    Picker("時間", selection: $minutes) {
                        ForEach(Limits.timerMinutes, id: \.self) { Text("\($0)分").tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 140)
                }
            }
            .navigationTitle(task == nil ? "タスクを追加" : "タスクを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || categoryID == nil)
                }
            }
            .sheet(isPresented: $creatingCategory, onDismiss: {
                // 作ったカテゴリをそのまま選択状態にする。
                if let createdCategoryID { categoryID = createdCategoryID }
                createdCategoryID = nil
            }) {
                CategoryEditView(category: nil) { createdCategoryID = $0.id }
            }
            .alert("カテゴリは\(Limits.categories)個まで作成できます", isPresented: $showingLimit) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("使わないカテゴリを削除してから作成してください。")
            }
            .onAppear(perform: selectDefaultCategory)
            .onChange(of: categories.count) { selectDefaultCategory() }
        }
    }

    private func selectDefaultCategory() {
        if categoryID == nil { categoryID = categories.first?.id }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let category = categories.first { $0.id == categoryID }
        if let task {
            task.name = trimmed
            task.category = category
            task.durationMinutes = minutes
        } else {
            let nextOrder = (tasks.map(\.sortOrder).max() ?? -1) + 1
            context.insert(TaskTemplate(name: trimmed, durationMinutes: minutes, sortOrder: nextOrder, category: category))
        }
        try? context.save()
        dismiss()
    }
}
