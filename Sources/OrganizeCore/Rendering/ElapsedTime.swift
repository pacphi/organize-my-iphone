import Foundation

/// Formats how long something has taken, for people watching a terminal.
public enum ElapsedTime {
    /// Whole seconds, for a counter that ticks: "7s", "59s", "1m 05s".
    public static func ticking(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else {
            return "0s"
        }
        let whole = Int(seconds)
        if whole < 60 {
            return "\(whole)s"
        }
        return "\(whole / 60)m \(twoDigits(whole % 60))s"
    }

    /// A finished total: tenths below a minute ("0.4s", "42.3s"), then "1m 05s".
    public static func total(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else {
            return "0.0s"
        }
        if seconds < 59.95 {
            return String(format: "%.1fs", seconds)
        }
        let whole = Int(seconds.rounded())
        return "\(whole / 60)m \(twoDigits(whole % 60))s"
    }

    /// A `Duration` as fractional seconds.
    public static func seconds(_ duration: Duration) -> Double {
        let parts = duration.components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1_000_000_000_000_000_000
    }

    private static func twoDigits(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}

/// Composes the one-line status shown for a step of work: while it runs, and when it ends.
public enum StatusLine {
    public static let spinnerFrames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

    /// The line for a step in progress, for example `⠹ Classify 142 apps · 50/142 apps · 12s`.
    /// It is cut to fit `width` columns so that redrawing it in place never wraps.
    public static func running(frame: Int, title: String, detail: String?, seconds: Double, width: Int) -> String {
        let spinner = spinnerFrames[abs(frame) % spinnerFrames.count]
        let time = ElapsedTime.ticking(seconds)
        let middle = body(title: title, detail: detail)

        // Keep the spinner and the clock; shorten the words between them if space is tight.
        let fixed = spinner.count + 1 + 3 + time.count  // "⠹ " + " · " + "12s"
        let room = max(8, width - 1 - fixed)
        let fitted = middle.count > room ? String(middle.prefix(max(1, room - 1))) + "…" : middle
        return "\(spinner) \(fitted) · \(time)"
    }

    /// The line left behind when a step ends, for example `✓ Classify 142 apps · 42.3s`.
    public static func finished(title: String, detail: String?, seconds: Double, succeeded: Bool) -> String {
        let mark = succeeded ? "✓" : "✗"
        let outcome = succeeded ? ElapsedTime.total(seconds) : "failed after \(ElapsedTime.total(seconds))"
        return "\(mark) \(body(title: title, detail: detail)) · \(outcome)"
    }

    /// The progress note for work done in batches, for example
    /// `batch 3/10 · 50/242 apps · about 40s left`.
    ///
    /// The time left is a straight-line estimate from the batches finished so far, so it is
    /// only shown once at least one batch is done.
    public static func batchProgress(completed: Int, total: Int, batchSize: Int, elapsedSeconds: Double) -> String {
        let count = "\(completed)/\(total) apps"
        guard total > 0, completed < total else {
            return count
        }
        let size = max(1, batchSize)
        let batches = (total + size - 1) / size
        let current = min(batches, completed / size + 1)
        var note = "batch \(current)/\(batches) · \(count)"
        if completed > 0, elapsedSeconds > 0 {
            let remaining = elapsedSeconds / Double(completed) * Double(total - completed)
            note += " · about \(ElapsedTime.ticking(remaining.rounded(.up))) left"
        }
        return note
    }

    private static func body(title: String, detail: String?) -> String {
        guard let detail, !detail.isEmpty else {
            return title
        }
        return "\(title) · \(detail)"
    }
}
