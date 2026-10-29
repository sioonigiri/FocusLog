import Foundation
import Observation
import StoreKit

/// 買い切りの「FocusLog Pro」の購入状態を管理する。
/// Proは内容と価格を調整中のため、今は画面に出していない。
@MainActor
@Observable
final class ProStore {
    static let productID = "com.sioonigiri.focuslog.pro"

    private(set) var isPro = false
    private(set) var product: Product?
    private(set) var isPurchasing = false
    var errorMessage: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
                await self?.refreshEntitlements()
            }
        }
        Task {
            await refreshEntitlements()
            await loadProduct()
        }
    }

    func loadProduct() async {
        product = try? await Product.products(for: [Self.productID]).first
    }

    func refreshEntitlements() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.productID,
               transaction.revocationDate == nil {
                owned = true
            }
        }
        isPro = owned
    }

    /// 購入できたらtrue。
    func purchase() async -> Bool {
        guard let product else { return false }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await transaction.finish()
                isPro = true
                return true
            case .success(.unverified):
                errorMessage = "購入を確認できませんでした。"
                return false
            default:
                return false
            }
        } catch {
            errorMessage = "購入に失敗しました。時間をおいて再度お試しください。"
            return false
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            errorMessage = "購入を復元できませんでした。"
        }
        await refreshEntitlements()
    }
}
