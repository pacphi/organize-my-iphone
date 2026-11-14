import Foundation
import OrganizeCore

/// Owns the terminal's bottom line while a step runs: a spinner, the step's name and a count
/// of elapsed seconds that is redrawn in place.
///
/// Everything the tool prints goes through `write`, so ordinary messages and the live line
/// never overwrite each other: the live line is erased, the message is printed, and the live
/// line is drawn again underneath.
///
/// When output is not a terminal (piped to a file, CI logs, Xcode's console) nothing is
/// redrawn. Each step prints one line when it starts and one when it ends.
final class LiveStatus: @unchecked Sendable {
    static let shared = LiveStatus()

    enum Stream {
        case standardOutput
        case standardError
    }

    private let lock = NSLock()
    private let clock = ContinuousClock()
    private let isInteractive: Bool

    // All of the following are guarded by `lock`.
    private var title: String?
    private var detail: String?
    private var startedAt: ContinuousClock.Instant?
    private var frame = 0
    private var lineIsDrawn = false

    init(isInteractive: Bool = LiveStatus.standardOutputIsATerminal()) {
        self.isInteractive = isInteractive
    }

    // MARK: Steps

    func begin(_ title: String) {
        lock.withLock {
            if self.title != nil {
                finishLocked(succeeded: true)
            }
            self.title = title
            self.detail = nil
            self.startedAt = clock.now
            self.frame = 0
            if isInteractive {
                drawLocked()
            } else {
                emit("→ \(title)\n", to: .standardOutput)
            }
        }
    }

    /// Adds a short progress note to the running step, such as "50/142 apps".
    func setDetail(_ detail: String?) {
        lock.withLock {
            guard title != nil else {
                return
            }
            self.detail = detail
            if isInteractive {
                drawLocked()
            }
        }
    }

    /// Advances the spinner and the clock. Called a few times a second while a step runs.
    func redraw() {
        lock.withLock {
            guard title != nil, isInteractive else {
                return
            }
            frame += 1
            drawLocked()
        }
    }

    func finish(succeeded: Bool) {
        lock.withLock {
            finishLocked(succeeded: succeeded)
        }
    }

    // MARK: Ordinary output

    /// Prints text without disturbing the live line. Inside a step, lines are indented so
    /// they read as belonging to it.
    func write(_ text: String, to stream: Stream) {
        lock.withLock {
            if lineIsDrawn {
                eraseLocked()
            }
            emit(title == nil ? text : "  \(text)", to: stream)
            if title != nil, isInteractive {
                drawLocked()
            }
        }
    }

    // MARK: Drawing (call with the lock held)

    private func finishLocked(succeeded: Bool) {
        guard let title, let startedAt else {
            return
        }
        let seconds = ElapsedTime.seconds(clock.now - startedAt)
        if lineIsDrawn {
            eraseLocked()
        }
        let line = StatusLine.finished(title: title, detail: detail, seconds: seconds, succeeded: succeeded)
        emit("\(line)\n", to: .standardOutput)
        self.title = nil
        self.detail = nil
        self.startedAt = nil
    }

    private func drawLocked() {
        guard let title, let startedAt else {
            return
        }
        let line = StatusLine.running(
            frame: frame,
            title: title,
            detail: detail,
            seconds: ElapsedTime.seconds(clock.now - startedAt),
            width: LiveStatus.terminalColumns()
        )
        // Carriage return, clear the line, draw. No newline, so the next draw replaces it.
        emit("\r\u{1B}[2K\(line)", to: .standardOutput)
        lineIsDrawn = true
    }

    private func eraseLocked() {
        emit("\r\u{1B}[2K", to: .standardOutput)
        lineIsDrawn = false
    }

    private func emit(_ text: String, to stream: Stream) {
        let handle: FileHandle
        switch stream {
        case .standardOutput:
            handle = FileHandle.standardOutput
        case .standardError:
            handle = FileHandle.standardError
        }
        handle.write(Data(text.utf8))
    }

    // MARK: Terminal facts

    /// True when standard output is a terminal that can redraw a line. Set `OMI_NO_PROGRESS=1`
    /// to force plain line-by-line output.
    static func standardOutputIsATerminal() -> Bool {
        let environment = ProcessInfo.processInfo.environment
        if environment["OMI_NO_PROGRESS"] != nil || environment["TERM"] == "dumb" {
            return false
        }
        return isatty(STDOUT_FILENO) != 0
    }

    static func terminalColumns() -> Int {
        var size = winsize()
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &size) == 0, size.ws_col > 0 {
            return Int(size.ws_col)
        }
        return 80
    }
}
