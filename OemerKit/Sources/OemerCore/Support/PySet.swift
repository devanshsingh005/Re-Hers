/// Emulation of CPython 3.12's `set` for integer keys (Objects/setobject.c). oemer often
/// takes "an arbitrary element" of a set (`set.pop()`, or the first match while iterating),
/// and which element that is depends on CPython's hash-table layout. Reproducing it keeps
/// the Swift port's choices identical to the Python reference.
struct PySet {
    private static let linearProbes = 9
    private static let perturbShift: UInt = 5
    private static let minSize = 8

    private enum Slot: Equatable {
        case empty
        case active(key: Int, hash: Int)
        case dummy
    }

    private var table: [Slot]
    private var mask: Int
    private(set) var fill = 0
    private(set) var used = 0
    private var finger = 0

    init() {
        table = Array(repeating: .empty, count: PySet.minSize)
        mask = PySet.minSize - 1
    }

    /// `set(iterable)` — keys are inserted in iteration order.
    init<S: Sequence>(_ seq: S) where S.Element == Int {
        self.init()
        for k in seq { add(k) }
    }

    var count: Int { used }
    var isEmpty: Bool { used == 0 }

    /// CPython hash of a small int.
    @inline(__always) static func hash(_ v: Int) -> Int { v == -1 ? -2 : v }

    /// Iteration order (slot order).
    var elements: [Int] {
        var out: [Int] = []
        out.reserveCapacity(used)
        for s in table { if case .active(let k, _) = s { out.append(k) } }
        return out
    }

    func contains(_ key: Int) -> Bool { lookup(key, PySet.hash(key)).found }

    private func lookup(_ key: Int, _ hash: Int) -> (index: Int, found: Bool) {
        var perturb = UInt(bitPattern: hash)
        var i = UInt(bitPattern: hash) & UInt(mask)
        while true {
            var idx = Int(i)
            var probes = (Int(i) + PySet.linearProbes <= mask) ? PySet.linearProbes : 0
            while true {
                switch table[idx] {
                case .empty:
                    return (idx, false)
                case .active(let k, let h):
                    if h == hash && k == key { return (idx, true) }
                case .dummy:
                    break
                }
                idx += 1
                if probes == 0 { break }
                probes -= 1
            }
            perturb >>= PySet.perturbShift
            i = (i &* 5 &+ 1 &+ perturb) & UInt(mask)
        }
    }

    /// set_add_entry
    mutating func add(_ key: Int) {
        addEntry(key, PySet.hash(key))
    }

    private mutating func addEntry(_ key: Int, _ hash: Int) {
        var perturb = UInt(bitPattern: hash)
        var i = UInt(bitPattern: hash) & UInt(mask)
        var freeslot: Int? = nil
        while true {
            var idx = Int(i)
            var probes = (Int(i) + PySet.linearProbes <= mask) ? PySet.linearProbes : 0
            while true {
                switch table[idx] {
                case .empty:
                    if let fs = freeslot {
                        used += 1
                        table[fs] = .active(key: key, hash: hash)
                        return
                    }
                    fill += 1
                    used += 1
                    table[idx] = .active(key: key, hash: hash)
                    if fill * 5 < mask * 3 { return }
                    tableResize(used > 50000 ? used * 2 : used * 4)
                    return
                case .active(let k, let h):
                    if h == hash && k == key { return }
                case .dummy:
                    freeslot = idx
                }
                idx += 1
                if probes == 0 { break }
                probes -= 1
            }
            perturb >>= PySet.perturbShift
            i = (i &* 5 &+ 1 &+ perturb) & UInt(mask)
        }
    }

    private static func insertClean(_ table: inout [Slot], _ mask: Int, _ key: Int, _ hash: Int) {
        var perturb = UInt(bitPattern: hash)
        var i = UInt(bitPattern: hash) & UInt(mask)
        while true {
            var idx = Int(i)
            if table[idx] == .empty {
                table[idx] = .active(key: key, hash: hash)
                return
            }
            if Int(i) + linearProbes <= mask {
                for _ in 0..<linearProbes {
                    idx += 1
                    if table[idx] == .empty {
                        table[idx] = .active(key: key, hash: hash)
                        return
                    }
                }
            }
            perturb >>= perturbShift
            i = (i &* 5 &+ 1 &+ perturb) & UInt(mask)
        }
    }

    /// set_table_resize
    private mutating func tableResize(_ minused: Int) {
        var newsize = PySet.minSize
        while newsize <= minused { newsize <<= 1 }
        if newsize == PySet.minSize && mask == PySet.minSize - 1 && fill == used { return }
        let old = table
        var newTable = [Slot](repeating: .empty, count: newsize)
        let newMask = newsize - 1
        for s in old {
            if case .active(let k, let h) = s { PySet.insertClean(&newTable, newMask, k, h) }
        }
        table = newTable
        mask = newMask
        fill = used
    }

    /// set.discard / set.remove (without the KeyError)
    mutating func discard(_ key: Int) {
        let r = lookup(key, PySet.hash(key))
        guard r.found else { return }
        table[r.index] = .dummy
        used -= 1
    }

    /// set.pop()
    mutating func pop() -> Int? {
        if used == 0 { return nil }
        var idx = finger & mask
        while true {
            if case .active(let k, _) = table[idx] {
                table[idx] = .dummy
                used -= 1
                finger = idx + 1
                return k
            }
            idx += 1
            if idx > mask { idx = 0 }
        }
    }

    /// set_intersection(self, other) with `other` a set.
    func intersection(_ other: PySet) -> PySet {
        var a = self, b = other
        if b.used > a.used { swap(&a, &b) }
        // iterate b (the smaller), test membership in a
        var result = PySet()
        for s in b.table {
            if case .active(let k, let h) = s, a.lookup(k, h).found { result.addEntry(k, h) }
        }
        return result
    }

    /// set.update(other_set) — set_merge
    mutating func update(_ other: PySet) {
        if other.used == 0 { return }
        if (fill + other.used) * 5 >= mask * 3 { tableResize((used + other.used) * 2) }
        if fill == 0 && mask == other.mask && other.fill == other.used {
            table = other.table
            fill = other.fill
            used = other.used
            return
        }
        if fill == 0 {
            fill = other.used
            used = other.used
            for s in other.table {
                if case .active(let k, let h) = s { PySet.insertClean(&table, mask, k, h) }
            }
            return
        }
        for s in other.table {
            if case .active(let k, let h) = s { addEntry(k, h) }
        }
    }

    /// set.difference(iterable) — only membership matters to callers.
    func subtracting<S: Sequence>(_ other: S) -> [Int] where S.Element == Int {
        let o = Set(other)
        return elements.filter { !o.contains($0) }
    }
}

/// Reference-semantics wrapper, for places where oemer shares one set object between entries.
final class PySetRef {
    var set: PySet
    init(_ s: PySet = PySet()) { set = s }
}
