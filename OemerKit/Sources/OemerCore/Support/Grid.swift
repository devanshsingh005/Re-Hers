/// A dense 2-D array stored row-major (y, then x), the Swift stand-in for the
/// numpy arrays the original Python pipeline passes around.
public struct Grid<Element> {
    public let width: Int
    public let height: Int
    public var data: [Element]

    public init(width: Int, height: Int, repeating value: Element) {
        precondition(width >= 0 && height >= 0)
        self.width = width
        self.height = height
        self.data = Array(repeating: value, count: width * height)
    }

    public init(width: Int, height: Int, data: [Element]) {
        precondition(data.count == width * height)
        self.width = width
        self.height = height
        self.data = data
    }

    @inline(__always)
    public subscript(y: Int, x: Int) -> Element {
        get { data[y * width + x] }
        set { data[y * width + x] = newValue }
    }

    @inline(__always)
    public func contains(y: Int, x: Int) -> Bool {
        y >= 0 && y < height && x >= 0 && x < width
    }

    public func map<T>(_ transform: (Element) -> T) -> Grid<T> {
        Grid<T>(width: width, height: height, data: data.map(transform))
    }
}

/// Binary map: 0 = background, 1 = foreground.
public typealias Mask = Grid<UInt8>

extension Grid where Element == UInt8 {
    public static func zeros(width: Int, height: Int) -> Mask {
        Mask(width: width, height: height, repeating: 0)
    }

    /// Number of non-zero pixels inside the half-open rectangle (numpy slice semantics).
    public func countNonZero(x1: Int, y1: Int, x2: Int, y2: Int) -> Int {
        let r = clampSlice(x1: x1, y1: y1, x2: x2, y2: y2, width: width, height: height)
        if r.x1 >= r.x2 || r.y1 >= r.y2 { return 0 }
        var c = 0
        data.withUnsafeBufferPointer { p in
            for y in r.y1..<r.y2 {
                let row = y * width
                for x in r.x1..<r.x2 where p[row + x] != 0 { c += 1 }
            }
        }
        return c
    }
}

/// Resolves numpy-style slice bounds `a[y1:y2, x1:x2]` (negative indices count from the end,
/// out-of-range bounds are clipped) into concrete half-open ranges.
@inline(__always)
public func clampSlice(x1: Int, y1: Int, x2: Int, y2: Int, width: Int, height: Int)
    -> (x1: Int, y1: Int, x2: Int, y2: Int)
{
    (pySliceStart(x1, width), pySliceStart(y1, height), pySliceStop(x2, width), pySliceStop(y2, height))
}

@inline(__always)
func pySliceStart(_ v: Int, _ n: Int) -> Int {
    if v < 0 { return max(0, n + v) }
    return min(v, n)
}

@inline(__always)
func pySliceStop(_ v: Int, _ n: Int) -> Int {
    if v < 0 { return max(0, n + v) }
    return min(v, n)
}
