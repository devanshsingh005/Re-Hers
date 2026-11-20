/// Tiny XML element tree with a pretty printer matching Python's
/// `xml.dom.minidom ... toprettyxml(indent='  ', encoding='UTF-8')`.
final class XMLNode {
    let name: String
    var attributes: [(String, String)]
    var text: String?
    var children: [XMLNode] = []

    init(_ name: String, _ attributes: [(String, String)] = [], text: String? = nil) {
        self.name = name
        self.attributes = attributes
        self.text = text
    }

    @discardableResult
    func add(_ name: String, _ attributes: [(String, String)] = [], text: String? = nil) -> XMLNode {
        let n = XMLNode(name, attributes, text: text)
        children.append(n)
        return n
    }

    func append(_ n: XMLNode) { children.append(n) }
}

private func escapeXML(_ s: String) -> String {
    var out = ""
    out.reserveCapacity(s.count)
    for ch in s {
        switch ch {
        case "&": out += "&amp;"
        case "<": out += "&lt;"
        case "\"": out += "&quot;"
        case ">": out += "&gt;"
        default: out.append(ch)
        }
    }
    return out
}

private func write(_ n: XMLNode, indent: String, into out: inout String) {
    out += indent + "<" + n.name
    for (k, v) in n.attributes { out += " \(k)=\"\(escapeXML(v))\"" }
    let hasText = !(n.text ?? "").isEmpty
    if !n.children.isEmpty || hasText {
        out += ">"
        if n.children.isEmpty {
            out += escapeXML(n.text!)
        } else {
            out += "\n"
            // ElementTree text before children is serialized as its own text node; oemer never does that.
            for c in n.children { write(c, indent: indent + "  ", into: &out) }
            out += indent
        }
        out += "</\(n.name)>\n"
    } else {
        out += "/>\n"
    }
}

/// `<?xml ...?>` + pretty-printed tree (minidom layout).
func prettyXML(_ root: XMLNode) -> String {
    var out = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
    write(root, indent: "", into: &out)
    return out
}
