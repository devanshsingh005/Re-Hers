/// Shared state of one recognition run — the Swift counterpart of oemer's global `layers`.
///
/// The five model maps are kept as Float32 grids. Without dewarping they hold 0/1 (oemer's
/// integer maps); after dewarping they hold the raw cubic-interpolated values cv2.remap
/// produces, and each consumer applies the same comparison numpy does in the original
/// (`> 0`, `.astype(np.uint8)` truncation, float32/float64 arithmetic).
final class OMRContext {
    let width: Int
    let height: Int
    let classifiers: SymbolClassifiers
    /// true when the maps are float32 (dewarped); false for oemer's int64 0/1 maps.
    let floatMaps: Bool

    let staffF: Grid<Float>
    /// symbols + clefs_keys + stems_rests, values above 1 clamped to 1
    let symbolsF: Grid<Float>
    let stemsF: Grid<Float>
    let noteheadF: Grid<Float>
    let clefsF: Grid<Float>

    // Commonly used binarized views
    /// staff_pred > 0
    lazy var staffPos: Mask = positive(staffF)
    /// symbols_pred > 0
    lazy var symbolsPos: Mask = positive(symbolsF)
    /// stems_rests_pred.astype(np.uint8)
    lazy var stemsTrunc: Mask = truncated(stemsF)
    /// notehead_pred.astype(np.uint8)
    lazy var noteheadTrunc: Mask = truncated(noteheadF)
    /// notehead_pred > 0
    lazy var noteheadPos: Mask = positive(noteheadF)
    /// clefs_keys_pred.astype(np.uint8)
    lazy var clefsTrunc: Mask = truncated(clefsF)
    /// staff_pred.astype(np.uint8)
    lazy var staffTrunc: Mask = truncated(staffF)

    // Extraction results
    var staffLayout = StaffLayout(grid: [], zones: [])
    var staffsFlat: [Staff] = []
    var notes: [NoteHead] = []
    var noteIdMap: Grid<Int32>
    var groups: [NoteGroup] = []
    var groupMap: Grid<Int32>
    var barlines: [Barline] = []
    var clefs: [Clef] = []
    var sfns: [Sfn] = []
    var rests: [Rest] = []

    init(staff: Grid<Float>, symbols: Grid<Float>, stemsRests: Grid<Float>, notehead: Grid<Float>, clefsKeys: Grid<Float>,
         floatMaps: Bool, classifiers: SymbolClassifiers)
    {
        width = staff.width
        height = staff.height
        self.classifiers = classifiers
        self.floatMaps = floatMaps
        staffF = staff
        stemsF = stemsRests
        noteheadF = notehead
        clefsF = clefsKeys
        // symbols = symbols + clefs_keys + stems_rests; symbols[symbols > 1] = 1   (float32, left to right)
        var merged = symbols
        for i in 0..<merged.data.count {
            let v = (symbols.data[i] + clefsKeys.data[i]) + stemsRests.data[i]
            merged.data[i] = v > 1 ? 1 : v
        }
        symbolsF = merged
        noteIdMap = Grid<Int32>(width: width, height: height, repeating: -1)
        groupMap = Grid<Int32>(width: width, height: height, repeating: -1)
    }

    /// zones[0][0] and zones[-1][-1] (inclusive end) used by several range filters.
    var zoneMinX: Int { staffLayout.zones.first!.lowerBound }
    var zoneMaxX: Int { staffLayout.zones.last!.upperBound - 1 }
}

/// `a > 0`
func positive(_ g: Grid<Float>) -> Mask {
    Mask(width: g.width, height: g.height, data: g.data.map { $0 > 0 ? 1 : 0 })
}

/// `a.astype(np.uint8)` as a 0/1 mask: truncation toward zero, so values in [1, 256) count.
func truncated(_ g: Grid<Float>) -> Mask {
    Mask(width: g.width, height: g.height, data: g.data.map { $0 >= 1 ? 1 : 0 })
}

func floatGrid(_ m: Mask) -> Grid<Float> {
    Grid<Float>(width: m.width, height: m.height, data: m.data.map { Float($0) })
}

/// Rows/columns a numpy slice `a[y1:y2, x1:x2]` actually covers.
@inline(__always)
func sliceRanges(_ b: BBox, width: Int, height: Int) -> (rows: Range<Int>, cols: Range<Int>) {
    let r = clampSlice(x1: b.x1, y1: b.y1, x2: b.x2, y2: b.y2, width: width, height: height)
    return (r.y1..<max(r.y1, r.y2), r.x1..<max(r.x1, r.x2))
}

/// Sorted unique values of a slice of an Int32 grid (`np.unique(a[y1:y2, x1:x2])`).
func uniqueValues(_ g: Grid<Int32>, rows: Range<Int>, cols: Range<Int>) -> [Int] {
    var s = Set<Int32>()
    for y in rows {
        let row = y * g.width
        for x in cols { s.insert(g.data[row + x]) }
    }
    return s.map { Int($0) }.sorted()
}
