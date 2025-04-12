import UIKit
import Razorpay

// MARK: - Protocol to handle success and failure
protocol RazorPaymentDelegate: AnyObject {
    func paymentDidSucceed(paymentId: String, signature: String)
    func paymentDidFail(code: Int32, description: String)
}

class RazorpayPaymentManager: NSObject {
    
    private var razorpay: RazorpayCheckout?
    private weak var viewController: UIViewController?
    weak var delegate: RazorPaymentDelegate?
    
    // UPDATE KEY TEST OR PROD
    private let API_KEY_ID = "rzp_test_q3TpDbWA7Y1BJd"
    
    init(vc: UIViewController) {
        super.init()
        self.viewController = vc
    }

    // MARK: - Start payment
    func startPayment(
        orderId: String = "",
        amount: Int,
        email: String = "xyz@goodspace.com",
        contact: String = "9000000000",
        description: String = "payment for app subscription"
    ) {
        
        var options: [AnyHashable: Any] = [
            "name": "GOODSPACE.AI",
            "image": "https://goodspace.ai/assets/logo-bc3e1fa1.svg",
            "description": description,
            "prefill": [
                "contact": contact,
                "email": email
            ],
            "amount": amount * 100,
            "theme": [
                "color": "#2A78C2"
            ]
        ]
        
        // If you have an orderId from backend
        if !orderId.isEmpty {
            options["order_id"] = orderId
        }
        
        guard let controller = self.viewController else {
            print("❌ Razorpay Error: ViewController is nil")
            return
        }
        
        controller.navigationController?.isNavigationBarHidden = true
        
        self.razorpay = RazorpayCheckout.initWithKey(API_KEY_ID, andDelegateWithData: self)
        if let rzp = self.razorpay {
            rzp.open(options, displayController: controller)
        } else {
            debugPrint("❌ Failed to open page. Please try again later.")
        }
    }
}

extension RazorpayPaymentManager: RazorpayPaymentCompletionProtocolWithData {
    
    func onPaymentError(_ code: Int32, description str: String, andData response: [AnyHashable: Any]?) {
        debugPrint("error: ", code)
        debugPrint("additional error: ", response ?? [])
        delegate?.paymentDidFail(code: code, description: str)
    }
    
    func onPaymentSuccess(_ payment_id: String, andData response: [AnyHashable: Any]?) {
        debugPrint("success: ", payment_id)
        debugPrint("additional response: ", response ?? [])
        delegate?.paymentDidSucceed(paymentId: payment_id, signature: response?["razorpay_signature"] as? String ?? "")
    }
}
