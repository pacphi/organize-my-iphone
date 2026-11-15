import ArgumentParser
import Foundation
import OrganizeAdapters
import OrganizeCore

// The only two commands that change the phone.

struct ApplyCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "apply",
        abstract: "Write a saved proposal to the phone. Backs up the current layout first and asks before changing anything."
    )

    @OptionGroup var global: GlobalOptions

    @Argument(
        help: ArgumentHelp(
            "The proposal to apply.",
            discussion: "`organize-my-iphone schemes` describes each one.",
            valueName: "scheme"
        )
    )
    var scheme: OrganizationScheme

    @Flag(name: .long, help: "Do not ask for confirmation.")
    var yes = false

    @Flag(name: .long, help: "Check the plan against the phone and report what would change, then stop.")
    var dryRun = false

    func run() async throws {
        let workspace = global.makeWorkspace()
        let planURL = workspace.planURL(for: scheme)
        guard workspace.exists(planURL) else {
            throw UserError("No \(scheme.rawValue) proposal found. Run `organize-my-iphone run` first.")
        }
        let plan = try workspace.read(OrganizationPlan.self, from: planURL)

        let device = try global.makeDeviceClient()
        let (target, current) = try await ApplyCommand.readPhone(device, ecid: global.ecid)

        // The phone may have changed since the scan. Never push a plan that drops or invents icons.
        let issues = LayoutValidator.validate(plan.layout, against: current)
        for issue in issues {
            Console.say("  \(issue.description)")
        }
        guard !LayoutValidator.hasErrors(issues) else {
            throw UserError(
                "This proposal cannot be applied as it stands. If apps were installed or removed since "
                    + "the scan, run `organize-my-iphone run` again."
            )
        }

        let change = LayoutDiff.summarize(from: current, to: plan.layout)
        Console.say(
            "\(target.name): \(change.moved) of \(change.totalIcons) icons will change page or folder "
                + "(\(plan.layout.pages.count) page(s), \(plan.layout.folders.count) folder(s))."
        )
        if dryRun {
            Console.say("Dry run: nothing was changed.")
            return
        }

        let backup = try workspace.saveBackup(current, reason: .beforeApply, at: Date())
        Console.say("Current layout saved to \(backup.path)")
        guard yes || Console.confirm("Apply the \(plan.scheme.title.lowercased()) layout to \(target.name)?") else {
            Console.say("Cancelled. Nothing was changed.")
            return
        }

        try await Console.step("Write the new layout to \(target.name)") {
            try await device.applyIconLayout(plan.layout, ecid: target.ecid)
        }
        Console.say("Done. To undo: organize-my-iphone restore")
    }

    /// Finds the phone and reads its current layout, as one timed step.
    static func readPhone(_ device: any DeviceClient, ecid: String?) async throws -> (ConnectedDevice, IconLayout) {
        try await Console.step("Read the current layout from the iPhone") {
            let devices = try await device.listDevices()
            let target = try DeviceSelector.select(from: devices, ecid: ecid)
            Console.detail(target.name)
            let layout = try await device.iconLayout(ecid: target.ecid)
            return (target, layout)
        }
    }
}

struct RestoreCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "restore",
        abstract: "Put a backed-up layout back on the phone. Defaults to the layout saved just before the last apply."
    )

    @OptionGroup var global: GlobalOptions

    @Option(name: .long, help: "A specific backup file to restore instead of the most recent one.")
    var backup: String?

    @Flag(name: .long, help: "List the available backups and stop.")
    var list = false

    @Flag(name: .long, help: "Do not ask for confirmation.")
    var yes = false

    func run() async throws {
        let workspace = global.makeWorkspace()
        if list {
            let backups = try workspace.backups()
            if backups.isEmpty {
                Console.say("No backups yet in \(workspace.backupsDirectory.path)")
            }
            for file in backups {
                Console.say(file.path)
            }
            return
        }

        let source: URL
        if let backup, !backup.isEmpty {
            source = URL(fileURLWithPath: GlobalOptions.expand(backup))
        } else if let latest = try workspace.latestBackup(reason: .beforeApply) ?? workspace.latestBackup() {
            source = latest
        } else {
            throw UserError("No backups found in \(workspace.backupsDirectory.path).")
        }
        let layout = try workspace.loadLayout(from: source)

        let device = try global.makeDeviceClient()
        let (target, current) = try await ApplyCommand.readPhone(device, ecid: global.ecid)

        // A backup taken before apps were installed or removed will not match exactly.
        // That is worth knowing, but it is the user's call.
        for issue in LayoutValidator.validate(layout, against: current) {
            Console.say("  \(issue.description)")
        }
        Console.say("Restoring \(source.lastPathComponent) to \(target.name).")
        guard yes || Console.confirm("Continue?") else {
            Console.say("Cancelled. Nothing was changed.")
            return
        }

        try workspace.saveBackup(current, reason: .beforeApply, at: Date())
        try await Console.step("Write the restored layout to \(target.name)") {
            try await device.applyIconLayout(layout, ecid: target.ecid)
        }
        Console.say("Done.")
    }
}
