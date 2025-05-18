import SwiftUI

struct RefreshableScrollView<Content: View>: View {
    var height: CGFloat = 160
    @Binding var refreshing: Bool
    let action: () async -> Void
    let content: () -> Content
    
    @State private var previousScrollOffset: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var frozen: Bool = false
    @State private var rotation: Angle = .degrees(0)
    
    var threshold: CGFloat = 80
    
    var body: some View {
        VStack {
            ScrollView(.horizontal, showsIndicators: false) {
                ZStack(alignment: .top) {
                    MovingView()
                    
                    VStack {
                        content()
                    }
                    .alignmentGuide(.top, computeValue: { d in
                        (refreshing && frozen) ? -threshold : 0.0
                    })
                    
                    SymbolView(height: height, threshold: threshold, refreshing: refreshing, frozen: frozen, rotation: rotation)
                        .opacity(scrollOffset > 0 ? 1 : 0)
                }
            }
            .background(FixedView())
            .onPreferenceChange(RefreshableKeyTypes.PrefKey.self) { values in
                self.scrollOffset = values[0]
                
                // Negative scroll offset means scrolling up (refresh)
                if !frozen && scrollOffset > threshold && previousScrollOffset <= threshold {
                    impact(style: .medium)
                    frozen = true
                    
                    Task {
                        await action()
                        
                        withAnimation {
                            self.frozen = false
                        }
                    }
                }
                
                // Update rotation for the refresh symbol
                if scrollOffset > 0 && !refreshing {
                    rotation = .degrees(Double(scrollOffset/threshold) * 180)
                }
                
                self.previousScrollOffset = scrollOffset
            }
        }
        .frame(height: height)
    }
    
    // Haptic feedback function
    private func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}

struct MovingView: View {
    var body: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: RefreshableKeyTypes.PrefKey.self,
                value: [proxy.frame(in: .global).minY]
            )
        }
        .frame(height: 0)
    }
}

struct FixedView: View {
    var body: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: RefreshableKeyTypes.PrefKey.self,
                value: [proxy.frame(in: .global).minY]
            )
        }
        .frame(height: 0)
    }
}

struct SymbolView: View {
    var height: CGFloat
    var threshold: CGFloat
    var refreshing: Bool
    var frozen: Bool
    var rotation: Angle
    
    var body: some View {
        VStack {
            Spacer()
            
            if refreshing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primaryGreen))
                    .scaleEffect(1.5)
            } else {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.primaryGreen)
                    .rotationEffect(rotation)
            }
            
            Spacer()
        }
        .frame(height: height)
        .opacity(min(1, scrollOffset/threshold))
        .offset(y: -height/2)
    }
    
    // Access scrollOffset from preference key
    private var scrollOffset: CGFloat {
        (frozen && refreshing) ? threshold : 0
    }
}

enum RefreshableKeyTypes {
    struct PrefKey: PreferenceKey {
        static var defaultValue: [CGFloat] = [0]
        
        static func reduce(value: inout [CGFloat], nextValue: () -> [CGFloat]) {
            value.append(contentsOf: nextValue())
        }
    }
}

// For preview
struct RefreshableScrollView_Previews: PreviewProvider {
    static var previews: some View {
        RefreshableScrollView(refreshing: .constant(false), action: {
            // Simulate network delay
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }) {
            HStack(spacing: 15) {
                ForEach(0..<5) { i in
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Text("Item \(i+1)")
                                .foregroundColor(.green)
                        )
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 160)
    }
} 