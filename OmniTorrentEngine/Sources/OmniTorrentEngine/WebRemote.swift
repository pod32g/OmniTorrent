import Foundation
import Network

public actor WebRemote {
    private var listener: NWListener?
    private let port: UInt16
    private let getTorrents: @Sendable () async -> [Torrent]
    private let getGlobalStats: @Sendable () async -> GlobalStats
    private let addMagnet: @Sendable (String) async -> Void

    public init(
        port: UInt16 = 8080,
        getTorrents: @escaping @Sendable () async -> [Torrent],
        getGlobalStats: @escaping @Sendable () async -> GlobalStats,
        addMagnet: @escaping @Sendable (String) async -> Void
    ) {
        self.port = port
        self.getTorrents = getTorrents
        self.getGlobalStats = getGlobalStats
        self.addMagnet = addMagnet
    }

    public func start() throws {
        let params = NWParameters.tcp
        listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        listener?.newConnectionHandler = { [weak self] connection in
            Task { await self?.handleConnection(connection) }
        }
        listener?.start(queue: .global())
    }

    public func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global())
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, _ in
            guard let self, let data, let request = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }
            Task {
                let response = await self.handleRequest(request)
                let responseData = response.data(using: .utf8) ?? Data()
                connection.send(content: responseData, completion: .contentProcessed { _ in
                    connection.cancel()
                })
            }
        }
    }

    private func handleRequest(_ raw: String) async -> String {
        let lines = raw.split(separator: "\r\n")
        guard let firstLine = lines.first else { return httpResponse(400, "Bad Request") }
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else { return httpResponse(400, "Bad Request") }
        let method = String(parts[0])
        let path = String(parts[1])

        switch (method, path) {
        case ("GET", "/"):
            return await serveDashboard()
        case ("GET", "/api/torrents"):
            return await serveJSON()
        case ("POST", "/api/add"):
            let body = extractBody(from: raw)
            if let magnet = body, !magnet.isEmpty {
                await addMagnet(magnet)
                return httpResponse(200, "{\"status\":\"ok\"}", contentType: "application/json")
            }
            return httpResponse(400, "{\"error\":\"no magnet\"}", contentType: "application/json")
        default:
            return httpResponse(404, "Not Found")
        }
    }

    private func extractBody(from raw: String) -> String? {
        guard let range = raw.range(of: "\r\n\r\n") else { return nil }
        let body = String(raw[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return body.isEmpty ? nil : body
    }

    private func serveJSON() async -> String {
        let torrents = await getTorrents()
        let stats = await getGlobalStats()
        var json = "{\"stats\":{\"down\":\(stats.downloadRate),\"up\":\(stats.uploadRate)},\"torrents\":["
        let items = torrents.map { t in
            "{\"name\":\"\(escapeJSON(t.name))\",\"progress\":\(t.progress),\"state\":\"\(t.state.jsonValue)\",\"downRate\":\(t.stats.downloadRate),\"upRate\":\(t.stats.uploadRate)}"
        }
        json += items.joined(separator: ",")
        json += "]}"
        return httpResponse(200, json, contentType: "application/json")
    }

    private func serveDashboard() async -> String {
        let html = dashboardHTML()
        return httpResponse(200, html, contentType: "text/html")
    }

    private func dashboardHTML() -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>OmniTorrent</title>
        <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: -apple-system, system-ui, sans-serif; background: #1a1a2e; color: #e0e0e0; padding: 20px; }
        h1 { font-size: 20px; margin-bottom: 16px; color: #79c0ff; }
        .stats { font-size: 14px; color: #8b949e; margin-bottom: 20px; }
        .add { display: flex; gap: 8px; margin-bottom: 20px; }
        .add input { flex: 1; padding: 10px; border-radius: 8px; border: 1px solid #333; background: #0d1117; color: #e0e0e0; font-size: 14px; }
        .add button { padding: 10px 20px; border-radius: 8px; border: none; background: #388bfd; color: white; font-size: 14px; cursor: pointer; }
        .torrent { background: #161b22; border-radius: 10px; padding: 14px; margin-bottom: 8px; }
        .torrent .name { font-size: 14px; font-weight: 500; }
        .torrent .meta { font-size: 12px; color: #8b949e; margin-top: 4px; }
        .bar { height: 4px; background: #21262d; border-radius: 2px; margin-top: 8px; overflow: hidden; }
        .bar .fill { height: 100%; border-radius: 2px; background: #388bfd; }
        .empty { text-align: center; color: #484f58; padding: 40px; }
        </style>
        </head>
        <body>
        <h1>OmniTorrent</h1>
        <div class="stats" id="stats"></div>
        <div class="add">
            <input id="magnet" placeholder="Paste magnet link..." />
            <button onclick="addMagnet()">Add</button>
        </div>
        <div id="list"></div>
        <script>
        function fmt(b) {
            if (b > 1048576) return (b/1048576).toFixed(1) + ' MB/s';
            if (b > 1024) return (b/1024).toFixed(0) + ' KB/s';
            return b + ' B/s';
        }
        function esc(s) {
            var d = document.createElement('div');
            d.textContent = s;
            return d.textContent;
        }
        async function refresh() {
            try {
                var r = await fetch('/api/torrents');
                var d = await r.json();
                document.getElementById('stats').textContent = '\\u2193 ' + fmt(d.stats.down) + '  \\u2191 ' + fmt(d.stats.up);
                var list = document.getElementById('list');
                list.textContent = '';
                if (d.torrents.length === 0) {
                    var empty = document.createElement('div');
                    empty.className = 'empty';
                    empty.textContent = 'No torrents';
                    list.appendChild(empty);
                } else {
                    d.torrents.forEach(function(t) {
                        var card = document.createElement('div');
                        card.className = 'torrent';
                        var nameEl = document.createElement('div');
                        nameEl.className = 'name';
                        nameEl.textContent = t.name;
                        card.appendChild(nameEl);
                        var meta = document.createElement('div');
                        meta.className = 'meta';
                        meta.textContent = Math.round(t.progress*100) + '% \\u00b7 ' + t.state + ' \\u00b7 \\u2193' + fmt(t.downRate) + ' \\u2191' + fmt(t.upRate);
                        card.appendChild(meta);
                        var bar = document.createElement('div');
                        bar.className = 'bar';
                        var fill = document.createElement('div');
                        fill.className = 'fill';
                        fill.style.width = (t.progress*100) + '%';
                        bar.appendChild(fill);
                        card.appendChild(bar);
                        list.appendChild(card);
                    });
                }
            } catch(e) {}
        }
        async function addMagnet() {
            var m = document.getElementById('magnet').value;
            if (!m) return;
            await fetch('/api/add', { method: 'POST', body: m });
            document.getElementById('magnet').value = '';
            refresh();
        }
        refresh();
        setInterval(refresh, 2000);
        </script>
        </body>
        </html>
        """
    }

    private func httpResponse(_ code: Int, _ body: String, contentType: String = "text/plain") -> String {
        let status = code == 200 ? "OK" : code == 400 ? "Bad Request" : "Not Found"
        return "HTTP/1.1 \(code) \(status)\r\nContent-Type: \(contentType)\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
    }

    private func escapeJSON(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
         .replacingOccurrences(of: "\n", with: "\\n")
    }
}

extension TorrentState {
    var jsonValue: String {
        switch self {
        case .downloading: return "downloading"
        case .seeding: return "seeding"
        case .paused: return "paused"
        case .checking: return "checking"
        case .queued: return "queued"
        case .error: return "error"
        }
    }
}
