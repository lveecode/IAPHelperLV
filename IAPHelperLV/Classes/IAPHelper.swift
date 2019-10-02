
import StoreKit

public extension Notification.Name {
    static let IAPHelperPurchaseNotification = Notification.Name("IAPHelperPurchaseNotification")
}

extension IAPHelper {
    @objc public static func runOnMainThreadWithoutDeadlocking(_ block: (()->Void)) {
        // Run block on main thread without deadlocking.
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.sync {
                block()
            }
        }
    }
}


open class IAPHelper: NSObject  {
    
    public static let shared = IAPHelper()
    
    public var loggingEnabled: Bool = true
    private var purchasedProductIdentifiers: Set<String> = []
    private var productsRequest: SKProductsRequest?
    private var productsRequestCompletionHandler: ((_ success: Bool) -> Void)? = nil
    private var purchaseCompletionHandler: ((_ success: Bool, _ canceled: Bool, _ errorMessage: String?) -> Void)? = nil
    
    public var products: [SKProduct]? = nil
    public var loadedProducts: Bool = false
    
    var productIds: Set<String> = []
    
    public func setup(productIds: Set<String>) {
        
        self.productIds = productIds
        
        // Track which items have already been purchased
        // according to our UserDefaults
        for productIdentifier in productIds {
            let purchased = UserDefaults.standard.bool(forKey: productIdentifier)
            if purchased {
                purchasedProductIdentifiers.insert(productIdentifier)
            }
        }
        
        // Add Store Queue observer
        SKPaymentQueue.default().add(self)
    }
    
    public func buyProduct(_ productId: String, completionHandler: @escaping (_ success: Bool, _ canceled: Bool, _ errorMessage: String?) -> Void) {
        
        if !IAPHelper.canMakePayments() {
            if loggingEnabled { print("[IAPHelper]: Can't make payments") }
            completionHandler(false, false, "Can't make payments")
            return
        }
        
        let purchaseBlock: (_ success: Bool) -> Void = { [weak self] success in
            if success {
                
                var foundProduct: SKProduct? = nil
                for product in self?.products ?? [] {
                    if product.productIdentifier == productId {
                        foundProduct = product
                        break
                    }
                }
                
                if foundProduct == nil {
                    if self?.loggingEnabled == true { print("[IAPHelper]: Product not found ", productId) }
                    completionHandler(false, false, "Product not found")
                    return
                }
                self?.buyProduct(foundProduct!, completionHandler)
                
            } else {
                completionHandler(false, false, "Failed to load products")
            }
        }
        if !loadedProducts {
            requestProducts(purchaseBlock)
        } else {
            purchaseBlock(true)
        }
    }
    
    public func isProductPurchased(_ productIdentifier: String) -> Bool {
        return purchasedProductIdentifiers.contains(productIdentifier)
    }
    
    public func requestProducts(_ completionHandler: @escaping (_ success: Bool) -> Void) {
        productsRequest?.cancel()
        productsRequestCompletionHandler = { (success) in
            IAPHelper.runOnMainThreadWithoutDeadlocking {
                completionHandler(success)
            } }
        
        productsRequest = SKProductsRequest(productIdentifiers: productIds)
        productsRequest!.delegate = self
        productsRequest!.start()
    }
    
    
    public func buyProduct(_ product: SKProduct, _ completionHandler: @escaping (_ success: Bool, _ canceled: Bool, _ errorMessage: String?) -> Void) {
        
        if loggingEnabled { print("[IAPHelper]: Buying \(product.productIdentifier)") }
        
        self.purchaseCompletionHandler = { (success, cancelled, errorMessage) in
            IAPHelper.runOnMainThreadWithoutDeadlocking {
                completionHandler(success, cancelled, errorMessage)
            } }
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }
    
    public class func canMakePayments() -> Bool {
        return SKPaymentQueue.canMakePayments()
    }
    
    public func restorePurchases(_ completionHandler: @escaping (_ success: Bool) -> Void ) {
        self.purchaseCompletionHandler = { (success, cancelled, errorMessage) in
            IAPHelper.runOnMainThreadWithoutDeadlocking {
                completionHandler(success)
            }
        }
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
}

// MARK: - SKProductsRequestDelegate

extension IAPHelper: SKProductsRequestDelegate {
    
    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        self.products = response.products
        
        for p in self.products! {
            if loggingEnabled { print("[IAPHelper]: Found product: \(p.productIdentifier) \(p.localizedTitle) \(p.price.floatValue) \(p.priceLocale)") }
        }
        if response.products.count == 0 {
            if loggingEnabled { print("[IAPHelper]: ? No products found") }
        }
        
        loadedProducts = true
        productsRequestCompletionHandler?(true)
        clearRequestAndHandler()
    }
    
    public func request(_ request: SKRequest, didFailWithError error: Error) {
        if loggingEnabled { print("[IAPHelper]: Failed to load list of products. Error: \(error.localizedDescription)") }
        
        loadedProducts = false
        productsRequestCompletionHandler?(false)
        clearRequestAndHandler()
    }
    
    private func clearRequestAndHandler() {
        productsRequest = nil
        productsRequestCompletionHandler = nil
    }
}

// MARK: - SKPaymentTransactionObserver

extension IAPHelper: SKPaymentTransactionObserver {
    
    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch (transaction.transactionState) {
            case .purchased:
                complete(transaction: transaction)
                break
            case .failed:
                fail(transaction: transaction)
                break
            case .restored:
                restore(transaction: transaction)
                break
            case .deferred:
                break
            case .purchasing:
                break
            @unknown default:
                break
            }
        }
    }
    
    private func complete(transaction: SKPaymentTransaction) {
        if loggingEnabled { print("[IAPHelper]: Transaction completed") }
        deliverPurchaseNotificationFor(identifier: transaction.payment.productIdentifier)
        SKPaymentQueue.default().finishTransaction(transaction)
        purchaseCompletionHandler?(true, false, nil)
    }
    
    private func restore(transaction: SKPaymentTransaction) {
        guard let productIdentifier = transaction.original?.payment.productIdentifier else { return }
        
        if loggingEnabled { print("[IAPHelper]: Restored \(productIdentifier)") }
        deliverPurchaseNotificationFor(identifier: productIdentifier)
        SKPaymentQueue.default().finishTransaction(transaction)
        purchaseCompletionHandler?(true, false, nil)
    }
    
    private func fail(transaction: SKPaymentTransaction) {
        if loggingEnabled { print("[IAPHelper]: Transaction failed") }
        
        var errorDescr: String = ""
        if let transactionError = transaction.error as NSError?,
            let localizedDescription = transaction.error?.localizedDescription,
            transactionError.code != SKError.paymentCancelled.rawValue {
            errorDescr = "Transaction Error: \(localizedDescription)"
            if loggingEnabled { print("[IAPHelper]: \(errorDescr)") }
        }
        
        let transactionError = transaction.error as NSError?
        let cancelled = transactionError?.code == SKError.paymentCancelled.rawValue
        
        SKPaymentQueue.default().finishTransaction(transaction)
        purchaseCompletionHandler?(false, cancelled, errorDescr)
    }
    
    public func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        if loggingEnabled { print("[IAPHelper]: Restore failed ", error.localizedDescription) }
        
        // Can't finish transaction, no transaction referenced
        purchaseCompletionHandler?(false, false, error.localizedDescription)
    }
    
    public func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        if loggingEnabled { print("[IAPHelper]: Restore completed, transactions finished") }
        
        // Can't finish transaction, no transaction referenced
        purchaseCompletionHandler?(true, false, nil)
    }
    
    private func deliverPurchaseNotificationFor(identifier: String?) {
        guard let identifier = identifier else { return }
        
        purchasedProductIdentifiers.insert(identifier)
        UserDefaults.standard.set(true, forKey: identifier)
        NotificationCenter.default.post(name: .IAPHelperPurchaseNotification, object: identifier)
    }
}
