//
//  iOS15Compat.swift
//  Trop
//
//  Compatibility layer for iOS 15.0+ backport.
//

import Combine
import Foundation
import SwiftUI

// MARK: - Duration & Task.sleep

struct Duration: Sendable, Hashable {
    let secondsValue: Double

    init(secondsValue: Double) {
        self.secondsValue = secondsValue
    }

    static func seconds(_ s: Double) -> Duration { Duration(secondsValue: s) }
    static func seconds(_ s: Int) -> Duration { Duration(secondsValue: Double(s)) }
    static func milliseconds(_ ms: Double) -> Duration { Duration(secondsValue: ms / 1000.0) }
    static func milliseconds(_ ms: Int) -> Duration { Duration(secondsValue: Double(ms) / 1000.0) }
}

extension Task where Success == Never, Failure == Never {
    static func sleep(for duration: Duration) async throws {
        let ns = UInt64(max(0, duration.secondsValue) * 1_000_000_000)
        try await Task.sleep(nanoseconds: ns)
    }
}

// MARK: - NavigationPath

struct NavigationPath: Equatable {
    var routes: [DetailRoute] = []

    init() {}

    var count: Int { routes.count }

    mutating func append(_ route: DetailRoute) {
        routes.append(route)
    }

    mutating func removeLast() {
        if !routes.isEmpty {
            routes.removeLast()
        }
    }

    mutating func removeTo(depth: Int) {
        while routes.count > depth {
            routes.removeLast()
        }
    }
}

// MARK: - NavigationStack

struct NavigationStack<Root: View>: View {
    @Binding var path: NavigationPath
    let hasPath: Bool
    let root: Root

    init(path: Binding<NavigationPath>, @ViewBuilder root: () -> Root) {
        self._path = path
        self.hasPath = true
        self.root = root()
    }

    init(@ViewBuilder root: () -> Root) {
        self._path = .constant(NavigationPath())
        self.hasPath = false
        self.root = root()
    }

    var body: some View {
        NavigationView {
            if hasPath {
                NavigationRootWithStack(path: $path, root: root)
            } else {
                root
            }
        }
        .navigationViewStyle(.stack)
    }
}

private struct NavigationRootWithStack<Root: View>: View {
    @Binding var path: NavigationPath
    let root: Root

    var body: some View {
        ZStack {
            root

            NavigationLink(
                isActive: Binding(
                    get: { path.routes.count >= 1 },
                    set: { if !$0 && path.routes.count >= 1 { path.removeTo(depth: 0) } }
                ),
                destination: {
                    if let r1 = path.routes.first {
                        DetailRouteDestinationView(route: r1)
                            .background(NavigationLevel2(path: $path))
                    }
                },
                label: { EmptyView() }
            )
            .hidden()
        }
    }
}

private struct NavigationLevel2: View {
    @Binding var path: NavigationPath

    var body: some View {
        NavigationLink(
            isActive: Binding(
                get: { path.routes.count >= 2 },
                set: { if !$0 && path.routes.count >= 2 { path.removeTo(depth: 1) } }
            ),
            destination: {
                if path.routes.count >= 2 {
                    DetailRouteDestinationView(route: path.routes[1])
                        .background(NavigationLevel3(path: $path))
                }
            },
            label: { EmptyView() }
        )
        .hidden()
    }
}

private struct NavigationLevel3: View {
    @Binding var path: NavigationPath

    var body: some View {
        NavigationLink(
            isActive: Binding(
                get: { path.routes.count >= 3 },
                set: { if !$0 && path.routes.count >= 3 { path.removeTo(depth: 2) } }
            ),
            destination: {
                if path.routes.count >= 3 {
                    DetailRouteDestinationView(route: path.routes[2])
                }
            },
            label: { EmptyView() }
        )
        .hidden()
    }
}

// MARK: - ContentUnavailableView

struct ContentUnavailableView<Label: View, Description: View, Actions: View>: View {
    let label: Label
    let description: Description?
    let actions: Actions?

    init(
        @ViewBuilder label: () -> Label,
        @ViewBuilder description: () -> Description = { EmptyView() },
        @ViewBuilder actions: () -> Actions = { EmptyView() }
    ) {
        self.label = label()
        self.description = description()
        self.actions = actions()
    }

    var body: some View {
        VStack(spacing: 12) {
            label
                .font(.title2.weight(.semibold))
            if let description {
                description
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            if let actions {
                actions
            }
        }
        .multilineTextAlignment(.center)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension ContentUnavailableView where Label == SwiftUI.Label<Text, Image>, Description == Text, Actions == EmptyView {
    init(
        _ title: LocalizedStringKey,
        systemImage: String,
        description: Text? = nil
    ) {
        self.init(
            label: { SwiftUI.Label(title, systemImage: systemImage) },
            description: { description ?? Text("") },
            actions: { EmptyView() }
        )
    }

    init<S: StringProtocol>(
        _ title: S,
        systemImage: String,
        description: Text? = nil
    ) {
        self.init(
            label: { SwiftUI.Label(title, systemImage: systemImage) },
            description: { description ?? Text("") },
            actions: { EmptyView() }
        )
    }
}

extension ContentUnavailableView where Label == SwiftUI.Label<Text, Image>, Description == EmptyView, Actions == EmptyView {
    init(_ title: LocalizedStringKey, systemImage: String) {
        self.init(
            label: { SwiftUI.Label(title, systemImage: systemImage) },
            description: { EmptyView() },
            actions: { EmptyView() }
        )
    }

    init<S: StringProtocol>(_ title: S, systemImage: String) {
        self.init(
            label: { SwiftUI.Label(title, systemImage: systemImage) },
            description: { EmptyView() },
            actions: { EmptyView() }
        )
    }
}

// MARK: - Modifiers & Enums

struct PresentationDetent: Hashable {
    static let medium = PresentationDetent()
    static let large = PresentationDetent()
    static func fraction(_: CGFloat) -> PresentationDetent { PresentationDetent() }
    static func height(_: CGFloat) -> PresentationDetent { PresentationDetent() }
}

struct PresentationDragIndicator: Hashable {
    static let automatic = PresentationDragIndicator()
    static let visible = PresentationDragIndicator()
    static let hidden = PresentationDragIndicator()
}

struct ToolbarPlacement: Hashable {
    static let navigationBar = ToolbarPlacement()
    static let bottomBar = ToolbarPlacement()
}

struct ScrollIndicatorVisibility: Hashable {
    static let automatic = ScrollIndicatorVisibility()
    static let visible = ScrollIndicatorVisibility()
    static let hidden = ScrollIndicatorVisibility()
    static let never = ScrollIndicatorVisibility()
}

extension View {
    func presentationDetents(_ detents: Set<PresentationDetent>) -> some View { self }
    func presentationDragIndicator(_ indicator: PresentationDragIndicator) -> some View { self }
    func scrollContentBackground(_ visibility: Visibility) -> some View { self }
    func scrollDisabled(_ disabled: Bool) -> some View { self }
    func scrollIndicators(_ visibility: ScrollIndicatorVisibility, axes: Axis.Set = [.vertical, .horizontal]) -> some View { self }

    func containerRelativeFrame(_ axes: Axis.Set, alignment: Alignment = .center) -> some View {
        self.frame(
            maxWidth: axes.contains(.horizontal) ? .infinity : nil,
            maxHeight: axes.contains(.vertical) ? .infinity : nil,
            alignment: alignment
        )
    }

    func toolbar(_ visibility: Visibility, for placement: ToolbarPlacement...) -> some View {
        self.navigationBarHidden(visibility == .hidden)
    }
}

struct ScrollGeometry {
    var contentOffset: CGPoint = .zero
    var contentInsets: EdgeInsets = EdgeInsets()
    var contentSize: CGSize = .zero
    var containerSize: CGSize = .zero
    var visibleRect: CGRect = .zero
}

enum ScrollPhase: Equatable {
    case idle
    case tracking
    case interacting
    case decelerating
    case animating
}

extension View {
    func onScrollPhaseChange(_ action: @escaping (ScrollPhase, ScrollPhase) -> Void) -> some View {
        self
    }

    func navigationDestination<D: Hashable, C: View>(for data: D.Type, @ViewBuilder destination: @escaping (D) -> C) -> some View {
        self
    }
    @_disfavoredOverload
    func fontWeight(_ weight: Font.Weight?) -> some View {
        self
    }

    func onScrollGeometryChange<T: Equatable>(
        for type: T.Type,
        of transform: @escaping (ScrollGeometry) -> T,
        action: @escaping (T, T) -> Void
    ) -> some View {
        self
    }

    func onChange<V: Equatable>(
        of value: V,
        _ action: @escaping () -> Void
    ) -> some View {
        self.onChange(of: value) { _ in action() }
    }

    func onChange<V: Equatable>(
        of value: V,
        _ action: @escaping (_ oldValue: V, _ newValue: V) -> Void
    ) -> some View {
        self.modifier(TwoArgOnChangeModifier(value: value, action: action))
    }

    func onChange<V: Equatable>(
        of value: V,
        initial: Bool,
        _ action: @escaping (_ oldValue: V, _ newValue: V) -> Void
    ) -> some View {
        self.modifier(TwoArgOnChangeModifier(value: value, action: action))
    }

    func onChange<V: Equatable>(
        of value: V,
        initial: Bool,
        _ action: @escaping () -> Void
    ) -> some View {
        self.onChange(of: value) { _ in action() }
    }
}

private struct TwoArgOnChangeModifier<V: Equatable>: ViewModifier {
    let value: V
    let action: (V, V) -> Void

    @State private var oldValue: V

    init(value: V, action: @escaping (V, V) -> Void) {
        self.value = value
        self.action = action
        self._oldValue = State(initialValue: value)
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: value) { newValue in
                let old = oldValue
                oldValue = newValue
                action(old, newValue)
            }
    }
}

// MARK: - Environment Overloads for iOS 15

private struct MiniPlayerScrollStateKey: EnvironmentKey {
    static let defaultValue: MiniPlayerScrollState = MiniPlayerScrollState()
}

extension EnvironmentValues {
    var miniPlayerScrollState: MiniPlayerScrollState {
        get { self[MiniPlayerScrollStateKey.self] }
        set { self[MiniPlayerScrollStateKey.self] = newValue }
    }
}

extension Environment where Value == SettingsStore {
    init(_ objectType: SettingsStore.Type) {
        self.init(\.settingsStore)
    }
}

extension Environment where Value == MiniPlayerScrollState {
    init(_ objectType: MiniPlayerScrollState.Type) {
        self.init(\.miniPlayerScrollState)
    }
}

// MARK: - Observation tracking shim

func withObservationTracking<T>(
    _ apply: () -> T,
    onChange: @escaping () -> Void
) -> T {
    let result = apply()
    let cancellable = SettingsStore.shared.objectWillChange
        .first()
        .sink { _ in
            onChange()
        }
    _ = cancellable
    return result
}
