import Foundation
struct Cell {
    var ch: Character
    var fg: Console.Color
    var bg: Console.Color
    init(_ ch: Character, fg: Console.Color = .defaultColor, bg: Console.Color = .defaultColor) {
        self.ch = ch; self.fg = fg; self.bg = bg
    }
}
