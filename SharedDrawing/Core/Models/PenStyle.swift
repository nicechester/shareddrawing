import Foundation

enum PenStyle: String, Codable, CaseIterable, Identifiable, Hashable {
    case ballpoint, marker, highlighter, calligraphy, pencil

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ballpoint: return "Ballpoint"
        case .marker: return "Marker"
        case .highlighter: return "Highlighter"
        case .calligraphy: return "Calligraphy"
        case .pencil: return "Pencil"
        }
    }

    var minWidth: Double {
        switch self {
        case .ballpoint: return 2.0
        case .marker: return 4.0
        case .highlighter: return 8.0
        case .calligraphy: return 2.0
        case .pencil: return 2.5
        }
    }

    var maxWidth: Double {
        switch self {
        case .ballpoint: return 2.0
        case .marker: return 4.0
        case .highlighter: return 8.0
        case .calligraphy: return 5.0
        case .pencil: return 2.5
        }
    }

    var baseWidth: Double { minWidth }

    var opacity: Double {
        switch self {
        case .ballpoint: return 1.0
        case .marker: return 0.6
        case .highlighter: return 0.3
        case .calligraphy: return 0.85
        case .pencil: return 0.8
        }
    }

    var usesScreenBlend: Bool {
        switch self {
        case .marker, .highlighter: return true
        default: return false
        }
    }

    static let `default`: PenStyle = .ballpoint
}
