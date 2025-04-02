import SwiftUI

struct OrdersView: View {
    @StateObject private var viewModel = OrdersViewModel()
    
    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.orders.isEmpty {
                ProgressView("Loading orders...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.orders, id: \.id) { order in
                        OrderRow(order: order)
                    }
                }
            }
        }
        .navigationTitle("Orders")
        .refreshable {
            await viewModel.fetchOrders()
        }
        .task {
            await viewModel.fetchOrders()
        }
        .overlay {
            if !viewModel.isLoading && viewModel.orders.isEmpty {
                ContentUnavailableView(
                    "No Orders",
                    systemImage: "cart.badge.questionmark",
                    description: Text("Your order history will appear here")
                )
            }
        }
    }
}

struct OrderRow: View {
    let order: Order
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(RestaurantManager.shared.getRestaurant(by: order.restaurantId)?.name ?? "Restaurant")
                    .font(.headline)
                Spacer()
                Text("₹\(String(format: "%.2f", order.totalAmount))")
                    .font(.subheadline)
                    .bold()
            }
            
            Text("\(order.items.count) items")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Text(order.status.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(8)
                
                Spacer()
                
                Text(order.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var statusColor: Color {
        switch order.status {
        case .pending:
            return .orange
        case .preparing:
            return .yellow
        case .readyForPickup:
            return .blue
        case .completed:
            return .green
        case .cancelled:
            return .red
        }
    }
}

@MainActor
class OrdersViewModel: ObservableObject {
    @Published var orders: [Order] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    func fetchOrders() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Here you would make the API call to fetch orders
            // For now, we'll just print that we're ready to fetch
            print("🔄 Ready to fetch orders from API")
            print("GET http://localhost:3000/orders")
            
            // Get auth token from UserDefaults
            if let userId = UserDefaultsManager.shared.getUserId() {
                print("📱 Fetching orders for user: \(userId)")
            } else {
                print("❌ No user ID found")
            }
        } catch {
            self.error = error
            print("❌ Error fetching orders: \(error)")
        }
    }
} 