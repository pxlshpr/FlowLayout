import SwiftUI

public let flowLayoutDefaultItemSpacing: CGFloat = 4

public struct FlowLayout<RefreshBinding, Data, ItemView: View>: View {
    
    let mode: Mode
    @Binding var binding: RefreshBinding
    let items: [Data]
    let itemSpacing: CGFloat
    @ViewBuilder let viewMapping: (Data) -> ItemView
    
    @State private var computedHeight: CGFloat
    
    var shouldAnimateHeight: Binding<Bool>?
    var height: Binding<CGFloat>?

    public init(mode: Mode,
                binding: Binding<RefreshBinding>,
                items: [Data],
                itemSpacing: CGFloat = flowLayoutDefaultItemSpacing,
                height: Binding<CGFloat>? = nil,
                shouldAnimateHeight: Binding<Bool>? = nil,
                @ViewBuilder viewMapping: @escaping (Data) -> ItemView
    ) {
        self.mode = mode
        _binding = binding
        self.items = items
        self.itemSpacing = itemSpacing
        self.viewMapping = viewMapping
        self.shouldAnimateHeight = shouldAnimateHeight
        self.height = height
        _computedHeight = State(initialValue: (mode == .scrollable) ? .zero : .infinity)
    }
}

public extension FlowLayout where RefreshBinding == Never? {
    init(mode: Mode,
         items: [Data],
         itemSpacing: CGFloat = flowLayoutDefaultItemSpacing,
         height: Binding<CGFloat>? = nil,
         shouldAnimateHeight: Binding<Bool>? = nil,
         @ViewBuilder viewMapping: @escaping (Data) -> ItemView
    ) {
        self.init(mode: mode,
                  binding: .constant(nil),
                  items: items,
                  itemSpacing: itemSpacing,
                  height: height,
                  shouldAnimateHeight: shouldAnimateHeight,
                  viewMapping: viewMapping)
    }
}

extension FlowLayout {
    
    public var body: some View {
        let stack = VStack {
            GeometryReader { geometry in
                self.content(in: geometry)
            }
        }
        return Group {
            if mode == .scrollable {
                stack.frame(height: computedHeight)
            } else {
                stack.frame(maxHeight: computedHeight)
            }
        }
        .onChange(of: computedHeight, perform: computedHeightChanged)
    }
    
    func computedHeightChanged(to newValue: CGFloat) {
        self.height?.wrappedValue = newValue
    }
    
    private func content(in g: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        var lastHeight = CGFloat.zero
        let itemCount = items.count
        return ZStack(alignment: .topLeading) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                viewMapping(item)
                    .padding([.horizontal, .vertical], itemSpacing)
                    .alignmentGuide(.leading, computeValue: { d in
                        if (abs(width - d.width) > g.size.width) {
                            width = 0
                            height -= lastHeight
                        }
                        lastHeight = d.height
                        let result = width
                        if index == itemCount - 1 {
                            width = 0
                        } else {
                            width -= d.width
                        }
                        return result
                    })
                    .alignmentGuide(.top, computeValue: { d in
                        let result = height
                        if index == itemCount - 1 {
                            height = 0
                        }
                        return result
                    })
            }
        }
        .background(
            HeightReaderView(
                binding: $computedHeight,
                shouldAnimate: shouldAnimateHeight
            )
        )
    }
    
    public enum Mode {
        case scrollable, vstack
    }
}

private struct HeightPreferenceKey: PreferenceKey {
    static func reduce(value _: inout CGFloat, nextValue _: () -> CGFloat) {}
    static var defaultValue: CGFloat = 0
}

private struct HeightReaderView: View {
    
    @Binding var binding: CGFloat
    var shouldAnimate: Binding<Bool>?

    var body: some View {
        GeometryReader { geo in
            Color.clear
                .preference(key: HeightPreferenceKey.self, value: geo.frame(in: .local).size.height)
        }
        .onPreferenceChange(HeightPreferenceKey.self) { h in
            if let shouldAnimate, shouldAnimate.wrappedValue == true {
                withAnimation {
                    binding = h
                }
            } else {
                binding = h
            }
        }
    }
}
