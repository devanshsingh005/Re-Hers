/// Axis-aligned box (x1, y1, x2, y2) as used throughout oemer. Whether x2/y2 are inclusive
/// depends on where the box came from, exactly as in the Python code.
public struct BBox: Equatable, Hashable, CustomStringConvertible {
    public var x1: Int
    public var y1: Int
    public var x2: Int
    public var y2: Int

    public init(_ x1: Int, _ y1: Int, _ x2: Int, _ y2: Int) {
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
    }

    @inline(__always) public subscript(i: Int) -> Int {
        switch i {
        case 0: return x1
        case 1: return y1
        case 2: return x2
        default: return y2
        }
    }

    public var width: Int { x2 - x1 }
    public var height: Int { y2 - y1 }

    /// oemer `get_center`: rounded (half to even) center as (x, y).
    public var center: (x: Int, y: Int) {
        (pyRound(Double(x1 + x2) / 2), pyRound(Double(y1 + y2) / 2))
    }

    public var description: String { "(\(x1), \(y1), \(x2), \(y2))" }
}
