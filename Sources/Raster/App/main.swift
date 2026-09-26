import AppKit

if CommandLine.arguments.contains("--selftest") {
    exit(SelfTest.run())
}
if let index = CommandLine.arguments.firstIndex(of: "--ax-probe"), index + 1 < CommandLine.arguments.count,
   let pid = pid_t(CommandLine.arguments[index + 1]) {
    exit(Diagnostics.axProbe(pid: pid))
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

#if !APPSTORE
if let index = CommandLine.arguments.firstIndex(of: "--snapshot"), index + 1 < CommandLine.arguments.count {
    let snapshot = MainActor.assumeIsolated { Snapshot(directory: CommandLine.arguments[index + 1]) }
    MainActor.assumeIsolated { snapshot.start() }
    app.run()
}
#endif
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.run()
