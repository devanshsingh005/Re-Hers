//
//  MusicXMLDocument.swift
//  Re-Hearse_v1
//
//  A small MusicXML element tree: parse, merge pages, write back, and convert to the JSON
//  shape the app reads everywhere (Play Along, Animation, key/tempo/chord readers).
//

import Foundation

/// One XML element with its attributes, children and text.
nonisolated final class XMLElementNode {
    let name: String
    var attributes: [(name: String, value: String)]
    var children: [XMLElementNode] = []
    var text = ""

    init(name: String, attributes: [(name: String, value: String)] = []) {
        self.name = name
        self.attributes = attributes
    }

    func firstChild(named name: String) -> XMLElementNode? {
        children.first { $0.name == name }
    }

    func children(named name: String) -> [XMLElementNode] {
        children.filter { $0.name == name }
    }

    func setAttribute(_ name: String, _ value: String) {
        if let i = attributes.firstIndex(where: { $0.name == name }) {
            attributes[i].value = value
        } else {
            attributes.append((name, value))
        }
    }
}

nonisolated enum MusicXMLDocument {
    enum ParseError: Error {
        case invalidXML(String)
    }

    /// Parses an XML document and returns its root element. External entities (the MusicXML
    /// DTD) are never loaded.
    static func parse(_ xml: String) throws -> XMLElementNode {
        let parser = XMLParser(data: Data(xml.utf8))
        parser.shouldResolveExternalEntities = false
        let builder = TreeBuilder()
        parser.delegate = builder
        guard parser.parse(), let root = builder.root else {
            throw ParseError.invalidXML(parser.parserError?.localizedDescription ?? "no root element")
        }
        return root
    }

    /// Joins the pages of one score: every page's measures are appended to the first page's
    /// part and renumbered 1, 2, 3, … The first page keeps its header (title, part list, tempo).
    static func merge(pages: [XMLElementNode]) -> XMLElementNode? {
        guard let first = pages.first, let part = first.firstChild(named: "part") else { return nil }
        for page in pages.dropFirst() {
            guard let pagePart = page.firstChild(named: "part") else { continue }
            part.children.append(contentsOf: pagePart.children(named: "measure"))
        }
        for (i, measure) in part.children(named: "measure").enumerated() {
            measure.setAttribute("number", String(i + 1))
        }
        return first
    }

    /// Writes the tree back as a MusicXML 4.0 partwise document.
    static func serialize(_ root: XMLElementNode) -> String {
        var out = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        out += "<!DOCTYPE score-partwise PUBLIC \"-//Recordare//DTD MusicXML 4.0 Partwise//EN\" "
        out += "\"http://www.musicxml.org/dtds/partwise.dtd\">\n"
        write(root, depth: 0, into: &out)
        return out
    }

    /// The JSON shape of the old server output (MusicXML run through `xmltodict`):
    /// `{"score-partwise": {...}}`, attributes as `"@name"`, a child that occurs more than once
    /// as an array, text-only elements as strings, text next to attributes as `"#text"`, and
    /// empty elements such as `<chord/>` or `<dot/>` as `null`.
    static func jsonObject(_ root: XMLElementNode) -> [String: Any] {
        [root.name: jsonValue(root)]
    }

    // MARK: - Private

    private static func jsonValue(_ e: XMLElementNode) -> Any {
        let text = e.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if e.attributes.isEmpty && e.children.isEmpty {
            return text.isEmpty ? NSNull() : text
        }
        var dict: [String: Any] = [:]
        for a in e.attributes { dict["@" + a.name] = a.value }
        var order: [String] = []
        var grouped: [String: [Any]] = [:]
        for c in e.children {
            if grouped[c.name] == nil { order.append(c.name) }
            grouped[c.name, default: []].append(jsonValue(c))
        }
        for name in order {
            let values = grouped[name]!
            dict[name] = values.count == 1 ? values[0] : values
        }
        if !text.isEmpty { dict["#text"] = text }
        return dict
    }

    private static func write(_ e: XMLElementNode, depth: Int, into out: inout String) {
        let indent = String(repeating: "  ", count: depth)
        out += indent + "<" + e.name
        for a in e.attributes { out += " \(a.name)=\"\(escape(a.value))\"" }
        let text = e.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if e.children.isEmpty {
            out += text.isEmpty ? "/>\n" : ">\(escape(text))</\(e.name)>\n"
            return
        }
        out += ">\n"
        if !text.isEmpty { out += indent + "  " + escape(text) + "\n" }
        for c in e.children { write(c, depth: depth + 1, into: &out) }
        out += indent + "</\(e.name)>\n"
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private nonisolated final class TreeBuilder: NSObject, XMLParserDelegate {
        var root: XMLElementNode?
        private var stack: [XMLElementNode] = []

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                    qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
            // XMLParser hands attributes over unordered; sort them so output is stable
            let attrs = attributeDict.sorted { $0.key < $1.key }.map { (name: $0.key, value: $0.value) }
            let node = XMLElementNode(name: elementName, attributes: attrs)
            if let parent = stack.last { parent.children.append(node) } else { root = node }
            stack.append(node)
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            stack.last?.text += string
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                    qualifiedName qName: String?) {
            _ = stack.popLast()
        }
    }
}
