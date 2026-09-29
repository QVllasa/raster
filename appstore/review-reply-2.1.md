# Antwort auf App Review, Guideline 2.1 – Information Needed (26.09.2026)

Entwurf. Wird erst nach Freigabe durch den User in App Store Connect gesendet und
zusätzlich in das Notes-Feld der App Review Information übernommen.

---

Hello App Review team,

thank you for the review. Below is the requested information for Raster 1.0.0 (build 33).

1. SCREEN RECORDING

The attached recording (Raster-review-demo.mp4) was captured on a physical MacBook Pro (Apple M5 Pro) running macOS 27, using TestFlight build 33, which is the exact build submitted for review. It starts with launching Raster from the Applications folder and shows the typical flow: opening the panel from the menu bar item, the Accessibility permission in System Settings, snapping windows with the keyboard shortcuts and with a tile in the panel, arranging all windows of a display at once (grid, side by side, focus + stack), and changing the gap between windows in the settings. English captions at the bottom explain each step and name every keyboard shortcut used. For the recording, the Accessibility permission had been granted beforehand; the video shows the enabled entry in System Settings.

Raster has no account registration or login, no user-generated content and no paid content or in-app purchases, so none of these flows exist.

2. PURPOSE AND TARGET AUDIENCE

Raster is a window manager for the Mac. It solves a common everyday problem: arranging windows side by side or in a grid on macOS takes a lot of dragging and resizing by hand. Raster does this with one keyboard shortcut or one click: halves, quarters, thirds, maximize, center, restore, moving windows between displays, and arranging all windows of a display at once.

The target audience is anyone who works with several windows at the same time, for example developers, writers, students and office workers, and in particular people who use a large or an additional external display. The value is less time spent on window management and a tidier screen. Raster is free, has no ads, no subscriptions and collects no data.

3. SETUP AND MAIN FEATURES

No login, credentials or sample files are required.

1. Launch Raster. It is a menu bar app (LSUIElement), so it does not appear in the Dock. On first launch the panel opens automatically below the Raster item in the top-right of the menu bar.
2. Grant the Accessibility permission: click "Open System Settings" in the panel and enable Raster in the Accessibility list under Privacy & Security. No restart is needed. If Raster does not appear in the list, click + below the list and choose Raster from the Applications folder; the panel shows this hint as well.
3. Click any window of another app, for example TextEdit, and press Command + Left Arrow or Command + Right Arrow to snap it to the left or right half, Command + Up Arrow to maximize it (press again to restore). Alternatively click a tile in the Raster panel.
4. Control + Option + A arranges all windows of the display as a grid, Control + Option + S side by side, Control + Option + M as "focus + stack".
5. The gear button in the panel opens the settings (shortcuts, gap between windows, open at login). Right-clicking the menu bar item offers Settings, Pause Shortcuts and Quit Raster.

4. EXTERNAL SERVICES

None. Raster does not use any external service, tool, platform, SDK, data provider, authentication service, payment processor or AI service. The app has no network entitlement and never opens a network connection. It only uses Apple system frameworks (AppKit, SwiftUI, Accessibility API, Carbon RegisterEventHotKey, ServiceManagement).

5. REGIONAL DIFFERENCES

There are none. Raster works identically in all regions. The only difference is the interface language, which follows the system language (German or English).

6. REGULATED INDUSTRY OR PROTECTED THIRD-PARTY MATERIAL

Not applicable. Raster does not operate in a regulated industry and does not contain or provide any protected third-party material. All code, icons and texts are our own; the source code is published under the MIT license at https://github.com/QVllasa/raster.

ACCESSIBILITY PERMISSION AND SANDBOX EXCEPTION

The Accessibility permission is used solely to read and set the position and size of windows of other apps, which is the core purpose of a window manager. Raster does not read window contents, does not observe or record keyboard input of other apps and does not install any event tap. The global shortcuts are registered with RegisterEventHotKey (Carbon), which does not require monitoring the keyboard. Only while the Raster panel is open, a global monitor for mouse clicks (NSEvent, left and right mouse down) is active so that the panel closes when the user clicks outside of it; the event content is not evaluated and the monitor is removed as soon as the panel closes.

The app runs in the App Sandbox and uses exactly one temporary exception: com.apple.security.temporary-exception.mach-lookup.local-name = com.apple.axserver. Without it the sandbox denies the mach-lookup to the accessibility server of the target app, and every Accessibility call fails with kAXErrorCannotComplete (-25204) even though the user has granted the permission. There are no other exceptions.

NOTE ON macOS 27

On macOS 27 some apps (we observed it with TextEdit) do not fully redraw a window that was resized and moved via the Accessibility API; the newly exposed area can stay black. Build 33 works around this by nudging the window size by one point shortly afterwards. In the recording you may still notice a black flicker for about a tenth of a second while windows are rearranged; this comes from the redraw of the respective app.

Kind regards,
Qendrim Vllasa
Vllasa Ventures UG (haftungsbeschränkt)
