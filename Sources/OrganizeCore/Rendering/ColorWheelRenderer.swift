import Foundation

/// One app on the color-wheel page.
public struct ColorWheelApp: Codable, Hashable, Sendable {
    public var bundleID: String
    public var name: String
    /// `#RRGGBB`, or `nil` when no color is known.
    public var hex: String?
    /// Where the color came from: "built-in", "App Store icon", "your file", or `nil`.
    public var source: String?

    public init(bundleID: String, name: String, hex: String?, source: String?) {
        self.bundleID = bundleID
        self.name = name
        self.hex = hex
        self.source = source
    }
}

/// Renders `colors.html`: a color wheel showing how many apps fall in each slice, and a list
/// where each app's color can be corrected by clicking a slice. The page saves the corrections
/// as an `--icon-colors` file.
///
/// Unlike the preview, this page runs a small inline script, because it is a tool you click
/// in. It still loads nothing from the network.
public enum ColorWheelRenderer {
    public static func apps(
        bundleIDs: [String],
        names: [String: String],
        colors: IconColorSet
    ) -> [ColorWheelApp] {
        var seen: Set<String> = []
        let merged = colors.merged
        return bundleIDs.filter { seen.insert($0).inserted }.map { bundleID in
            ColorWheelApp(
                bundleID: bundleID,
                name: names[bundleID] ?? KnownApps.system[bundleID]?.name ?? KnownApps.fallbackName(for: bundleID),
                hex: merged[bundleID]?.hex,
                source: colors.source(of: bundleID)?.rawValue
            )
        }
        .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    public static func render(deviceName: String, apps: [ColorWheelApp], fileColors: [String: RGBColor]) -> String {
        struct Payload: Encodable {
            struct Band: Encodable {
                var name: String
                var hex: String
            }
            var bands: [Band]
            var apps: [ColorWheelApp]
            var fileColors: [String: String]
        }
        let payload = Payload(
            bands: ColorBand.allCases.map { Payload.Band(name: $0.rawValue, hex: $0.swatch.hex) },
            apps: apps,
            fileColors: fileColors.mapValues { $0.hex }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let json = (try? encoder.encode(payload)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
        // Keep the data from ending the script element early.
        let safeJSON = json.replacingOccurrences(of: "</", with: "<\\/")

        let known = apps.filter { $0.hex != nil }.count
        var html: [String] = []
        html.append("<!DOCTYPE html>")
        html.append("<html lang=\"en\"><head><meta charset=\"utf-8\">")
        html.append("<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">")
        html.append("<title>Icon colors for \(HTMLPreviewRenderer.escape(deviceName))</title>")
        html.append("<style>\(stylesheet)</style></head><body>")
        html.append("<h1>Icon colors for \(HTMLPreviewRenderer.escape(deviceName))</h1>")
        html.append(
            "<p class=\"meta\">\(known) of \(apps.count) apps have a color. The rainbow layout sorts apps by "
                + "these colors. Click a slice of the wheel to see the apps in it. To fix an app, click the "
                + "slice it belongs in on its row, then save your changes.</p>"
        )
        html.append("<div class=\"top\"><div class=\"wheel\">\(wheelSVG())</div>")
        html.append("<div class=\"save\"><p><strong id=\"edited\">0</strong> change(s) not saved yet.</p>")
        html.append("<button id=\"download\" type=\"button\">Save icon-colors.json</button>")
        html.append("<p class=\"meta\">Then rebuild the layouts with it:<br>")
        html.append("<code>organize-my-iphone plan --icon-colors ~/Downloads/icon-colors.json</code></p>")
        html.append("<p class=\"meta\">The file holds your changes and anything already in your file. ")
        html.append("Colors found automatically stay in the workspace and are not repeated.</p>")
        html.append("<p><button id=\"all\" type=\"button\">Show every app</button></p></div></div>")
        html.append("<h2 id=\"heading\">Every app</h2><div id=\"list\"></div>")
        html.append("<script type=\"application/json\" id=\"data\">\(safeJSON)</script>")
        html.append("<script>\(script)</script>")
        html.append("</body></html>")
        return html.joined(separator: "\n")
    }

    // MARK: The wheel

    /// Eight hue slices around the outside, starting with red at the top and running
    /// clockwise, and three neutral slices (white, gray, black) in the middle.
    static func wheelSVG() -> String {
        let center = 170.0
        let outer = 160.0
        let inner = 78.0
        let core = 72.0
        var parts: [String] = []
        parts.append(
            "<svg viewBox=\"0 0 340 340\" width=\"340\" height=\"340\" role=\"img\" "
                + "aria-label=\"Color wheel with the number of apps in each slice\">"
        )
        let hues: [ColorBand] = [.red, .orange, .yellow, .green, .teal, .blue, .purple, .pink]
        for (index, band) in hues.enumerated() {
            let middle = Double(index) * 45
            let start = middle - 22.5
            let end = middle + 22.5
            let path =
                "M \(point(inner, start, center)) L \(point(outer, start, center)) "
                + "A \(format(outer)) \(format(outer)) 0 0 1 \(point(outer, end, center)) "
                + "L \(point(inner, end, center)) A \(format(inner)) \(format(inner)) 0 0 0 \(point(inner, start, center)) Z"
            parts.append(slice(band: band, path: path, labelAt: point((outer + inner) / 2, middle, center)))
        }
        let neutrals: [ColorBand] = [.white, .gray, .black]
        for (index, band) in neutrals.enumerated() {
            let middle = Double(index) * 120
            let start = middle - 60
            let end = middle + 60
            let path =
                "M \(format(center)) \(format(center)) L \(point(core, start, center)) "
                + "A \(format(core)) \(format(core)) 0 0 1 \(point(core, end, center)) Z"
            parts.append(slice(band: band, path: path, labelAt: point(core * 0.55, middle, center)))
        }
        parts.append("</svg>")
        return parts.joined()
    }

    private static func slice(band: ColorBand, path: String, labelAt: String) -> String {
        let coordinates = labelAt.split(separator: " ")
        let x = coordinates.first.map(String.init) ?? "0"
        let y = coordinates.last.map(String.init) ?? "0"
        let ink = [ColorBand.yellow, .white].contains(band) ? "#1C1C1E" : "#FFFFFF"
        return "<g class=\"slice\" data-band=\"\(band.rawValue)\" tabindex=\"0\" role=\"button\">"
            + "<path d=\"\(path)\" fill=\"\(band.swatch.hex)\"></path>"
            + "<text x=\"\(x)\" y=\"\(y)\" fill=\"\(ink)\" text-anchor=\"middle\">"
            + "<tspan x=\"\(x)\" dy=\"-0.2em\">\(band.rawValue)</tspan>"
            + "<tspan x=\"\(x)\" dy=\"1.2em\" class=\"count\" data-count=\"\(band.rawValue)\">0</tspan></text></g>"
    }

    /// A point `radius` from the center at `degrees` clockwise from the top, as "x y".
    private static func point(_ radius: Double, _ degrees: Double, _ center: Double) -> String {
        let radians = degrees * Double.pi / 180
        return "\(format(center + radius * sin(radians))) \(format(center - radius * cos(radians)))"
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    // MARK: Page assets

    static let stylesheet = """
        :root { color-scheme: light dark; }
        body { font: 15px/1.45 -apple-system, system-ui, sans-serif; margin: 24px; max-width: 980px; }
        h1 { font-size: 22px; margin: 0 0 4px; }
        h2 { font-size: 18px; margin: 24px 0 8px; }
        .meta { opacity: .75; }
        .top { display: flex; flex-wrap: wrap; gap: 24px; align-items: center; }
        .wheel svg { max-width: 100%; height: auto; }
        .slice { cursor: pointer; }
        .slice path { stroke: rgba(128,128,128,.5); stroke-width: 1; }
        .slice:hover path, .slice:focus path, .slice.active path { stroke: currentColor; stroke-width: 3; }
        .slice text { font-size: 12px; font-weight: 600; pointer-events: none; }
        .save { flex: 1; min-width: 260px; }
        button { font: inherit; padding: 6px 12px; border-radius: 8px; border: 1px solid rgba(128,128,128,.5);
                 background: rgba(128,128,128,.12); color: inherit; cursor: pointer; }
        code { font-size: 13px; }
        .row { display: flex; align-items: center; gap: 10px; padding: 6px 0;
               border-bottom: 1px solid rgba(128,128,128,.2); flex-wrap: wrap; }
        .chip { width: 28px; height: 28px; border-radius: 7px; flex: none;
                box-shadow: inset 0 0 0 1px rgba(128,128,128,.4); }
        .chip.none { background: repeating-linear-gradient(45deg, rgba(128,128,128,.25) 0 4px, transparent 4px 8px); }
        .who { flex: 1 1 200px; min-width: 0; }
        .who small { display: block; opacity: .6; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
        .source { font-size: 12px; opacity: .7; width: 110px; }
        .source.edited { opacity: 1; font-weight: 600; }
        .picks { display: flex; gap: 4px; flex-wrap: wrap; }
        .picks button { width: 22px; height: 22px; padding: 0; border-radius: 50%; }
        .picks button.on { outline: 2px solid currentColor; outline-offset: 1px; }
        """

    /// Draws the list, keeps the wheel's counts current, and saves the changes as JSON.
    static let script = """
        const data = JSON.parse(document.getElementById('data').textContent);
        const original = {};
        data.apps.forEach(a => { original[a.bundleID] = a.hex; });
        const edits = {};
        let filter = null;

        function bandOf(hex) {
          if (!hex) return null;
          const n = parseInt(hex.slice(1), 16);
          const r = ((n >> 16) & 255) / 255, g = ((n >> 8) & 255) / 255, b = (n & 255) / 255;
          const hi = Math.max(r, g, b), lo = Math.min(r, g, b), d = hi - lo;
          let h = 0;
          if (d > 0) {
            if (hi === r) h = 60 * (((g - b) / d) % 6);
            else if (hi === g) h = 60 * ((b - r) / d + 2);
            else h = 60 * ((r - g) / d + 4);
          }
          if (h < 0) h += 360;
          const s = hi === 0 ? 0 : d / hi;
          if (hi < 0.22) return 'Black';
          if (s < 0.18) return hi > 0.85 ? 'White' : (hi < 0.3 ? 'Black' : 'Gray');
          if (h >= 15 && h < 45) return 'Orange';
          if (h >= 45 && h < 70) return 'Yellow';
          if (h >= 70 && h < 165) return 'Green';
          if (h >= 165 && h < 195) return 'Teal';
          if (h >= 195 && h < 255) return 'Blue';
          if (h >= 255 && h < 290) return 'Purple';
          if (h >= 290 && h < 345) return 'Pink';
          return 'Red';
        }
        function colorOf(app) { return edits[app.bundleID] || app.hex; }

        function draw() {
          const counts = {};
          data.bands.forEach(b => { counts[b.name] = 0; });
          let none = 0;
          data.apps.forEach(a => { const band = bandOf(colorOf(a)); if (band) counts[band]++; else none++; });
          document.querySelectorAll('[data-count]').forEach(el => { el.textContent = counts[el.dataset.count]; });
          document.querySelectorAll('.slice').forEach(el => { el.classList.toggle('active', el.dataset.band === filter); });
          document.getElementById('edited').textContent = Object.keys(edits).length;
          document.getElementById('heading').textContent =
            filter ? filter + ' (' + counts[filter] + ')' : 'Every app (' + data.apps.length + ', ' + none + ' with no color)';

          const list = document.getElementById('list');
          list.textContent = '';
          data.apps.filter(a => !filter || bandOf(colorOf(a)) === filter).forEach(app => {
            const hex = colorOf(app);
            const row = document.createElement('div');
            row.className = 'row';
            const chip = document.createElement('div');
            chip.className = 'chip' + (hex ? '' : ' none');
            if (hex) chip.style.background = hex;
            const who = document.createElement('div');
            who.className = 'who';
            who.textContent = app.name;
            const id = document.createElement('small');
            id.textContent = app.bundleID;
            who.appendChild(id);
            const source = document.createElement('div');
            source.className = 'source' + (edits[app.bundleID] ? ' edited' : '');
            source.textContent = edits[app.bundleID] ? 'changed by you' : (app.source || 'no color');
            const picks = document.createElement('div');
            picks.className = 'picks';
            const current = bandOf(hex);
            data.bands.forEach(band => {
              const button = document.createElement('button');
              button.type = 'button';
              button.title = band.name;
              button.setAttribute('aria-label', app.name + ': ' + band.name);
              button.style.background = band.hex;
              if (band.name === current) button.className = 'on';
              button.addEventListener('click', () => {
                if (bandOf(original[app.bundleID]) === band.name) delete edits[app.bundleID];
                else edits[app.bundleID] = band.hex;
                draw();
              });
              picks.appendChild(button);
            });
            row.append(chip, who, source, picks);
            list.appendChild(row);
          });
        }

        document.querySelectorAll('.slice').forEach(el => {
          const pick = () => { filter = filter === el.dataset.band ? null : el.dataset.band; draw(); };
          el.addEventListener('click', pick);
          el.addEventListener('keydown', e => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); pick(); } });
        });
        document.getElementById('all').addEventListener('click', () => { filter = null; draw(); });
        document.getElementById('download').addEventListener('click', () => {
          const out = Object.assign({}, data.fileColors, edits);
          const blob = new Blob([JSON.stringify(out, null, 2) + '\\n'], { type: 'application/json' });
          const link = document.createElement('a');
          link.href = URL.createObjectURL(blob);
          link.download = 'icon-colors.json';
          link.click();
          URL.revokeObjectURL(link.href);
        });
        draw();
        """
}
