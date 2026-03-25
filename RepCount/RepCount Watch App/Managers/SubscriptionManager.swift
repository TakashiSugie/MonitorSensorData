//
//  SubscriptionManager.swift
//  RepCount Watch App
//
//  StoreKit 2 を用いたサブスクリプション（Standard Plan）の状態管理
//

import Foundation
import StoreKit
import Combine

@MainActor
class SubscriptionManager: ObservableObject {
    
    // アプリ内でPremium向けの機能をアンロックするフラグ
    @Published var isPremium: Bool = false
    
    // StoreKit ConfigurationまたはApp Store Connectで設定するProduct ID
    private let productId = "com.repcount.standard.monthly"
    
    /// 提供する商品情報リスト（今回の場合は1つだが拡張を見越して配列に）
    @Published var products: [Product] = [] 
    
    // StoreKitのリスナータスク
    private var updateListenerTask: Task<Void, Error>? = nil
    
    init() {
        // 購入状況の監視を開始
        updateListenerTask = listenForTransactions()
        
        // アプリ起動時に商品情報取得と、現在の有効なサブスク状態をチェック
        Task {
            await requestProducts()
            await updateCustomerProductStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Product Fetching
    
    private func requestProducts() async {
        do {
            products = try await Product.products(for: [productId])
        } catch {
            print("[SubscriptionManager] Failed to fetch products: \(error)")
        }
    }
    
    // MARK: - Transaction Listener
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    // checkVerified is now nonisolated so we can call it without await if it weren't async
                    // but wait, result itself is a value.
                    let transaction = try self.checkVerified(result)
                    
                    // トランザクションが成功した場合の処理をここに追加 (例: アナリティクスイベント)
                    // トランザクション終了処理
                    await transaction.finish()
                    
                    // ステータスを更新
                    await self.updateCustomerProductStatus()
                } catch {
                    print("[SubscriptionManager] Transaction failed verification")
                }
            }
        }
    }
    
    // MARK: - Status Update
    
    @MainActor
    func updateCustomerProductStatus() async {
        var isCurrentlyPremium = false
        
        // 有効なサブスクリプション（Current Entitlements）をループして確認
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                // 本アプリの対象Product IDであれば有効とする
                // サブスクリプションの場合は、期限切れ・キャンセルになっていなければEntitlementに含まれる
                if transaction.productID == productId {
                    isCurrentlyPremium = true
                }
            } catch {
                print("[SubscriptionManager] Failed to verify entitlement")
            }
        }
        
        self.isPremium = isCurrentlyPremium
    }
    
    // MARK: - Purchase Action
    
    @MainActor
    func purchase() async throws -> Bool {
        guard let product = products.first(where: { $0.id == productId }) else {
            print("[SubscriptionManager] Product not found for ID: \(productId)")
            return false
        }
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await updateCustomerProductStatus()
            return true
            
        case .userCancelled, .pending:
            return false
            
        @unknown default:
            return false
        }
    }
    
    // MARK: - Receipt Verification Helper (JWS Verification)
    
    // receipt verification helper is nonisolated to avoid actor overhead for simple logic
    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        // StoreKit 2 ではAppleによって自動的に署名検証が行われる
        switch result {
        case .unverified:
            // 署名検証失敗
            throw StoreError.failedVerification
        case .verified(let safe):
            // 検証成功
            return safe
        }
    }
}

// カスタムエラー定義
enum StoreError: Error {
    case failedVerification
}
