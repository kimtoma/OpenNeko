public struct CatStateMachine {
    public enum CatInput {
        case typingStarted, typingStopped
        case hoverBegan, hoverEnded
        case clicked
        case dragBegan, dragEnded
        case idleTimeout
    }

    public private(set) var current: CatState = .idle

    public init() {}

    public mutating func handle(_ input: CatInput) {
        // 드래그 중에는 드래그 종료 외 모든 입력 무시
        if current == .dragging {
            if case .dragEnded = input { current = .idle }
            return
        }
        switch input {
        case .typingStarted: current = .typing
        case .typingStopped: current = .idle
        case .hoverBegan: current = .hover
        case .hoverEnded: current = .idle
        case .clicked: current = .click
        case .dragBegan: current = .dragging
        case .dragEnded: current = .idle
        case .idleTimeout: current = .nap
        }
    }
}
