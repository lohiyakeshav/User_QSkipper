import UIKit

extension UIWindow {
    /// Thread-safe way to set the root view controller
    func setRootViewControllerSafely(_ viewController: UIViewController, animated: Bool = true) {
        ThreadUtility.ensureMainThread {
            self.rootViewController = viewController
            
            if animated {
                UIView.transition(with: self,
                                duration: 0.3,
                                options: .transitionCrossDissolve,
                                animations: nil,
                                completion: nil)
            }
        }
    }
}

extension UIApplication {
    /// Get the key window properly on the main thread
    @MainActor
    static var keyWindow: UIWindow? {
        if #available(iOS 15.0, *) {
            // iOS 15 and later
            return UIApplication.shared.connectedScenes
                .filter { $0.activationState == .foregroundActive }
                .first(where: { $0 is UIWindowScene })
                .flatMap { $0 as? UIWindowScene }?.windows
                .first(where: { $0.isKeyWindow })
        } else {
            // iOS 14 and earlier
            return UIApplication.shared.windows.first(where: { $0.isKeyWindow })
        }
    }
    
    /// Get the root view controller properly on the main thread
    @MainActor
    static var rootViewController: UIViewController? {
        return UIApplication.keyWindow?.rootViewController
    }
}

extension UIViewController {
    /// Present a view controller on the main thread
    func presentOnMainThread(_ viewController: UIViewController, animated: Bool = true, completion: (() -> Void)? = nil) {
        ThreadUtility.ensureMainThread { [weak self] in
            self?.present(viewController, animated: animated, completion: completion)
        }
    }
    
    /// Dismiss a view controller on the main thread
    func dismissOnMainThread(animated: Bool = true, completion: (() -> Void)? = nil) {
        ThreadUtility.ensureMainThread { [weak self] in
            self?.dismiss(animated: animated, completion: completion)
        }
    }
} 