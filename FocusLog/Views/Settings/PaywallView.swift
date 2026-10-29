import StoreKit
import SwiftUI

struct PaywallView: View {
    var reason: String?

    @Environment(ProStore.self) private var pro
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var pro = pro
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "infinity.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.tint)
                Text("FocusLog Pro")
                    .font(.largeTitle.bold())
                if let reason {
                    Text(reason)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                // Proの内容は調整中。決まったらここに並べる。
                VStack(alignment: .leading, spacing: 12) {
                    Label("一度の購入でずっと使えます", systemImage: "checkmark.seal")
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                Spacer()

                Button {
                    Task {
                        if await pro.purchase() { dismiss() }
                    }
                } label: {
                    Text(pro.product.map { "\($0.displayPrice)で購入" } ?? "読み込み中…")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(pro.product == nil || pro.isPurchasing)

                Button("購入を復元") {
                    Task {
                        await pro.restore()
                        if pro.isPro { dismiss() }
                    }
                }
                .font(.footnote)
            }
            .padding(24)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる", systemImage: "xmark") { dismiss() }
                }
            }
            .alert("エラー", isPresented: Binding(get: { pro.errorMessage != nil },
                                                 set: { if !$0 { pro.errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(pro.errorMessage ?? "")
            }
        }
    }
}
