import Foundation

/// Unterschiede zwischen der freien GitHub-Version und der Mac-App-Store-Version.
/// Die Store-Version läuft in der App-Sandbox, fragt vor dem Autostart und enthält keinen Snapshot-Modus.
/// Gebaut wird sie mit `-DAPPSTORE` (siehe scripts/build-appstore.sh).
enum Flavor {
    #if APPSTORE
    static let isAppStore = true
    #else
    static let isAppStore = false
    #endif
}
