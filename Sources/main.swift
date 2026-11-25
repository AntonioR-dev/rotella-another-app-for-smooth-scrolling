if CommandLine.arguments.dropFirst().first == "--service" {
    avviaMotore()
} else {
    RotellaApp.main()
}
