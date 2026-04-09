import Foundation

public struct RSSItem: Sendable {
    public let title: String
    public let guid: String
    public let torrentURL: String?  // .torrent URL
    public let magnetURI: String?   // magnet: URI
}

public class RSSParser: NSObject, XMLParserDelegate, @unchecked Sendable {
    private var items: [RSSItem] = []
    private var currentElement = ""
    private var currentTitle = ""
    private var currentGUID = ""
    private var currentLink = ""
    private var currentEnclosureURL: String?
    private var inItem = false

    public func parse(data: Data) -> [RSSItem] {
        items = []
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return items
    }

    public func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        if elementName == "item" || elementName == "entry" {
            inItem = true
            currentTitle = ""
            currentGUID = ""
            currentLink = ""
            currentEnclosureURL = nil
        }
        if elementName == "enclosure", let url = attributeDict["url"] {
            if url.hasSuffix(".torrent") || attributeDict["type"] == "application/x-bittorrent" {
                currentEnclosureURL = url
            }
        }
    }

    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard inItem else { return }
        switch currentElement {
        case "title": currentTitle += string
        case "guid", "id": currentGUID += string
        case "link": currentLink += string
        default: break
        }
    }

    public func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" || elementName == "entry" {
            inItem = false
            let torrentURL: String?
            let magnetURI: String?

            if let enclosure = currentEnclosureURL {
                torrentURL = enclosure
                magnetURI = nil
            } else if currentLink.hasPrefix("magnet:") {
                torrentURL = nil
                magnetURI = currentLink.trimmingCharacters(in: .whitespacesAndNewlines)
            } else if currentLink.hasSuffix(".torrent") {
                torrentURL = currentLink.trimmingCharacters(in: .whitespacesAndNewlines)
                magnetURI = nil
            } else {
                torrentURL = nil
                magnetURI = nil
            }

            if torrentURL != nil || magnetURI != nil {
                let guid = currentGUID.isEmpty ? currentTitle : currentGUID
                items.append(RSSItem(
                    title: currentTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                    guid: guid.trimmingCharacters(in: .whitespacesAndNewlines),
                    torrentURL: torrentURL,
                    magnetURI: magnetURI
                ))
            }
        }
        currentElement = ""
    }
}
