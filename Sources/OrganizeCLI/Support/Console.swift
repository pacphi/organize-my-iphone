import Foundation
import OrganizeCore

/// A message meant for the person at the keyboard. ArgumentParser prints `errorDescription`.
struct UserError: LocalizedError {
    var message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        message
    }
}

/// Terminal input and output. All output goes through `LiveStatus` so that messages and the
/// live step timer never overwrite each other.
enum Console {
    static func say(_ message: String) {
        LiveStatus.shared.write("\(message)\n", to: .standardOutput)
    }

    static func warn(_ message: String) {
        LiveStatus.shared.write("warning: \(message)\n", to: .standardError)
    }

    /// Asks a yes/no question. Anything other than "y" or "yes" is a no, including end of input.
    static func confirm(_ question: String) -> Bool {
        LiveStatus.shared.write("\(question) [y/N] ", to: .standardOutput)
        guard let answer = readLine() else {
            return false
        }
        let normalized = answer.trimmingCharacters(in: .whitespaces).lowercased()
        return normalized == "y" || normalized == "yes"
    }

    /// Runs one step of work with a live timer.
    ///
    /// In a terminal the step's line shows a spinner and the seconds elapsed, updating in
    /// place, and is replaced by a final line with the total when the step ends:
    ///
    ///     ⠹ Classify 142 apps with llm:qwen3 · 50/142 apps · 12s
    ///     ✓ Classify 142 apps with llm:qwen3 · 142/142 apps · 42.3s
    ///
    /// A step that throws ends with `✗ … · failed after 3.1s` and the error is rethrown.
    static func step<Value>(_ title: String, _ work: () async throws -> Value) async throws -> Value {
        let status = LiveStatus.shared
        status.begin(title)
        let ticker = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                status.redraw()
            }
        }
        defer {
            ticker.cancel()
        }

        do {
            let value = try await work()
            status.finish(succeeded: true)
            return value
        } catch {
            status.finish(succeeded: false)
            throw error
        }
    }

    /// Adds a short progress note to the running step, such as "50/142 apps".
    static func detail(_ text: String?) {
        LiveStatus.shared.setDetail(text)
    }

    /// Times a whole command. Call `elapsed()` on the result when it is done.
    static func stopwatch() -> Stopwatch {
        Stopwatch()
    }
}

struct Stopwatch {
    private let clock = ContinuousClock()
    private let start: ContinuousClock.Instant

    init() {
        start = clock.now
    }

    /// Time since the stopwatch was made, formatted like a finished step ("42.3s", "1m 05s").
    func elapsed() -> String {
        ElapsedTime.total(ElapsedTime.seconds(clock.now - start))
    }
}
