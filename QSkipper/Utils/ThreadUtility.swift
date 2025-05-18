import Foundation
import UIKit

/// Utility for safely executing code on the main thread
class ThreadUtility {
    /// Ensures the given closure is executed on the main thread
    /// - Parameter closure: The closure to execute on the main thread
    static func ensureMainThread(_ closure: @escaping () -> Void) {
        if Thread.isMainThread {
            closure()
        } else {
            DispatchQueue.main.async {
                closure()
            }
        }
    }
    
    /// Ensures the given closure is executed on the main thread and returns a value
    /// - Parameter closure: The closure to execute on the main thread and return a value
    /// - Returns: The value returned by the closure, or nil if executed asynchronously
    static func ensureMainThreadWithReturn<T>(_ closure: @escaping () -> T) -> T? {
        if Thread.isMainThread {
            return closure()
        } else {
            // When called from background thread, we can't return directly
            // The caller should use the async version instead
            DispatchQueue.main.async {
                _ = closure()
            }
            return nil
        }
    }
    
    /// ASYNC version of main thread execution - use this instead of syncOnMainThread
    /// - Parameter closure: The closure to execute on the main thread
    /// - Returns: A Task that will complete with the result of the closure
    @MainActor
    static func onMainThread<T>(_ closure: @escaping () -> T) async -> T {
        return closure()
    }
}

extension UIApplication {
    /// Returns the application's key window - should only be used on main thread
    /// - Returns: The key window if available, nil otherwise
    @MainActor
    static func getKeyWindow() -> UIWindow? {
        // This should only run on the main thread
        return UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .first(where: { $0 is UIWindowScene })
            .flatMap { $0 as? UIWindowScene }?.windows
            .first(where: { $0.isKeyWindow })
    }
    
    /// Returns the root view controller of the key window - should only be used on main thread
    /// - Returns: The root view controller if available, nil otherwise
    @MainActor
    static func getRootViewController() -> UIViewController? {
        return getKeyWindow()?.rootViewController
    }
    
    /// Safely presents a view controller on the main thread
    /// - Parameters:
    ///   - viewController: The view controller to present
    ///   - animated: Whether to animate the presentation
    ///   - completion: A closure to execute after the presentation completes
    static func presentSafely(_ viewController: UIViewController, animated: Bool = true, completion: (() -> Void)? = nil) {
        ThreadUtility.ensureMainThread {
            Task { @MainActor in
                guard let rootVC = await UIApplication.getRootViewController() else {
                    print("⚠️ No root view controller found for presentation")
                    return
                }
                
                // Find the top-most presented view controller
                var topVC = rootVC
                while let presentedVC = topVC.presentedViewController {
                    topVC = presentedVC
                }
                
                topVC.present(viewController, animated: animated, completion: completion)
            }
        }
    }
} 