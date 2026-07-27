import Foundation

struct Stack<Element> {
    private var items: [Element] = []

    mutating func push(_ element: Element) {
        items.append(element)
    }

    mutating func pop() -> Element? {
        items.popLast()
    }

    func peek() -> Element? {
        items.last
    }

    var isEmpty: Bool {
        items.isEmpty
    }

    var count: Int {
        items.count
    }
}
