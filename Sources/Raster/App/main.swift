import AppKit

if CommandLine.arguments.contains("--selftest") {
    exit(SelfTest.run())
}
