import Foundation

enum UndoableAction {
    case stroke(Stroke)
    case textObject(TextObject)
}
