import ArgumentParser

@main
struct OrganizeMyIPhone: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "organize-my-iphone",
        abstract: "Scan the apps on a connected iPhone, sort them into categories, and propose a tidier Home Screen.",
        discussion: """
            Start with `organize-my-iphone doctor`, then `organize-my-iphone run`. Nothing on the \
            phone changes until you run `apply`, and `restore` puts the previous layout back.

            Twelve layouts are built: category-pages, folder-board, alphabetical, most-used, \
            time-of-day, verb-folders, rainbow, thumb-reach, places, new-and-review, essentials and \
            life-areas. `organize-my-iphone schemes` describes each one and the data it uses.
            """,
        version: "0.1.0",
        subcommands: [
            RunCommand.self,
            DoctorCommand.self,
            ScanCommand.self,
            EnrichCommand.self,
            ClassifyCommand.self,
            PlanCommand.self,
            PreviewCommand.self,
            ApplyCommand.self,
            RestoreCommand.self,
            SchemesCommand.self,
        ]
    )
}
