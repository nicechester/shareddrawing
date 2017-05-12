//
//  Stack.swift
//  SharedDrawing
//
//  Created by Chester Kim on 5/10/17.
//  Copyright © 2017 Chester Kim. All rights reserved.
//

import Foundation

struct Stack<Element> {
    var items = [Element]()

    mutating func push(_ item: Element) {
        items.append(item)
    }

    mutating func pop() -> Element {
        return items.removeLast()
    }

    func isEmpty() -> Bool {
        return items.isEmpty
    }

    func isNotEmpty() -> Bool {
        return !items.isEmpty
    }
}
