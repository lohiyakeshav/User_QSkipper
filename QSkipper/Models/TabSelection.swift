import SwiftUI

class TabSelection: ObservableObject {
    static let shared = TabSelection()
    
    @Published var selectedTab: Tab = .home
    
    enum Tab {
        case home
        case favorites
        case orders
        case profile
    }
} 