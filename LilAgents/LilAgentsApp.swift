import SwiftUI
import AppKit
import Sparkle

@main
struct LilAgentsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var controller: LilAgentsController?
    var statusItem: NSStatusItem?
    let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    private var displayChangeMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        controller = LilAgentsController()
        controller?.start()
        setupMenuBar()
        setupDisplayChangeMonitor()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.characters.forEach { $0.session?.terminate() }
        if let monitor = displayChangeMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // MARK: - Menu Bar

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(named: "MenuBarIcon") ?? NSImage(systemSymbolName: "figure.walk", accessibilityDescription: "lil agents")
        }

        let menu = NSMenu()
        buildCharacterMenuItems(menu)
        buildOptionsSubmenus(menu)
        buildUpdateAndQuitItems(menu)
        statusItem?.menu = menu
    }

    private func buildCharacterMenuItems(_ menu: NSMenu) {
        let char1Item = NSMenuItem(title: NSLocalizedString("menu.bruce", comment: ""), action: #selector(toggleChar1), keyEquivalent: "1")
        char1Item.state = .on
        menu.addItem(char1Item)

        let char2Item = NSMenuItem(title: NSLocalizedString("menu.jazz", comment: ""), action: #selector(toggleChar2), keyEquivalent: "2")
        char2Item.state = .on
        menu.addItem(char2Item)

        menu.addItem(NSMenuItem.separator())
    }

    private func buildOptionsSubmenus(_ menu: NSMenu) {
        // Sounds
        let soundItem = NSMenuItem(title: NSLocalizedString("menu.sounds", comment: ""), action: #selector(toggleSounds(_:)), keyEquivalent: "")
        soundItem.state = WalkerCharacter.soundsEnabled ? .on : .off
        menu.addItem(soundItem)

        // Provider submenu
        let providerItem = NSMenuItem(title: NSLocalizedString("menu.provider", comment: ""), action: nil, keyEquivalent: "")
        providerItem.submenu = buildProviderSubmenu()
        menu.addItem(providerItem)

        // Theme submenu
        let themeItem = NSMenuItem(title: NSLocalizedString("menu.style", comment: ""), action: nil, keyEquivalent: "")
        themeItem.submenu = buildThemeSubmenu()
        menu.addItem(themeItem)

        // Display submenu
        let displayItem = NSMenuItem(title: NSLocalizedString("menu.display", comment: ""), action: nil, keyEquivalent: "")
        displayItem.submenu = buildDisplaySubmenu()
        menu.addItem(displayItem)

        menu.addItem(NSMenuItem.separator())
    }

    private func buildProviderSubmenu() -> NSMenu {
        let providerMenu = NSMenu()
        for (i, provider) in AgentProvider.allCases.enumerated() {
            let item = NSMenuItem(title: provider.displayName, action: #selector(switchProvider(_:)), keyEquivalent: "")
            item.tag = i
            item.state = provider == AgentProvider.current ? .on : .off
            providerMenu.addItem(item)
        }
        return providerMenu
    }

    private func buildThemeSubmenu() -> NSMenu {
        let themeMenu = NSMenu()
        let currentThemeIndex = PopoverTheme.allThemes.firstIndex(where: { $0.id == PopoverTheme.current.id }) ?? 0
        for (i, theme) in PopoverTheme.allThemes.enumerated() {
            let item = NSMenuItem(title: theme.name, action: #selector(switchTheme(_:)), keyEquivalent: "")
            item.tag = i
            item.state = i == currentThemeIndex ? .on : .off
            themeMenu.addItem(item)
        }
        return themeMenu
    }

    private func buildDisplaySubmenu() -> NSMenu {
        let displayMenu = NSMenu()
        displayMenu.delegate = self
        let autoItem = NSMenuItem(title: NSLocalizedString("menu.autoMainDisplay", comment: ""), action: #selector(switchDisplay(_:)), keyEquivalent: "")
        autoItem.tag = -1
        autoItem.state = controller?.pinnedScreenIndex == -1 ? .on : .off
        displayMenu.addItem(autoItem)
        displayMenu.addItem(NSMenuItem.separator())
        for (i, screen) in NSScreen.screens.enumerated() {
            let name = screen.localizedName
            let item = NSMenuItem(title: name, action: #selector(switchDisplay(_:)), keyEquivalent: "")
            item.tag = i
            item.state = controller?.pinnedScreenIndex == i ? .on : .off
            displayMenu.addItem(item)
        }
        return displayMenu
    }

    private func buildUpdateAndQuitItems(_ menu: NSMenu) {
        let updateItem = NSMenuItem(title: NSLocalizedString("menu.checkForUpdates", comment: ""), action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)), keyEquivalent: "")
        updateItem.target = updaterController
        menu.addItem(updateItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: NSLocalizedString("menu.quit", comment: ""), action: #selector(quitApp), keyEquivalent: "q")
        menu.addItem(quitItem)
    }

    // MARK: - Display Change Monitor

    private func setupDisplayChangeMonitor() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(displayConfigurationChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func displayConfigurationChanged() {
        // Refresh display submenu if needed
        if let menu = statusItem?.menu,
           let displayItem = menu.items.first(where: { $0.title == NSLocalizedString("menu.display", comment: "") }) {
            displayItem.submenu = buildDisplaySubmenu()
        }
    }

    // MARK: - Menu Actions

    @objc func switchTheme(_ sender: NSMenuItem) {
        let idx = sender.tag
        guard idx < PopoverTheme.allThemes.count else { return }
        PopoverTheme.current = PopoverTheme.allThemes[idx]

        if let themeMenu = sender.menu {
            for item in themeMenu.items {
                item.state = item.tag == idx ? .on : .off
            }
        }

        controller?.characters.forEach { char in
            let wasOpen = char.isIdleForPopover
            let wasBubbleVisible = char.thinkingBubbleWindow?.isVisible ?? false
            if wasOpen { char.popoverWindow?.orderOut(nil) }
            char.popoverWindow = nil
            char.terminalView = nil
            char.thinkingBubbleWindow?.orderOut(nil)
            char.thinkingBubbleWindow = nil
            if wasOpen {
                char.createPopoverWindow()
                if let session = char.session, !session.history.isEmpty {
                    char.terminalView?.replayHistory(session.history)
                }
                char.updatePopoverPosition()
                char.popoverWindow?.orderFrontRegardless()
                char.popoverWindow?.makeKey()
                if let terminal = char.terminalView {
                    char.popoverWindow?.makeFirstResponder(terminal.inputField)
                }
            }
            if wasBubbleVisible {
                char.updateThinkingPhrase()
                char.showBubble(text: char.currentPhrase, isCompletion: false)
            }
        }
    }

    @objc func switchProvider(_ sender: NSMenuItem) {
        let idx = sender.tag
        let allProviders = AgentProvider.allCases
        guard idx < allProviders.count else { return }
        AgentProvider.current = allProviders[idx]

        if let providerMenu = sender.menu {
            for item in providerMenu.items {
                item.state = item.tag == idx ? .on : .off
            }
        }

        // Terminate existing sessions and clear UI so title/placeholder update
        controller?.characters.forEach { char in
            char.session?.terminate()
            char.session = nil
            if char.isIdleForPopover {
                char.closePopover()
            }
            // Always clear popover/bubble so they rebuild with new provider title/placeholder
            char.popoverWindow?.orderOut(nil)
            char.popoverWindow = nil
            char.terminalView = nil
            char.thinkingBubbleWindow?.orderOut(nil)
            char.thinkingBubbleWindow = nil
        }
    }

    @objc func switchDisplay(_ sender: NSMenuItem) {
        let idx = sender.tag
        controller?.pinnedScreenIndex = idx

        if let displayMenu = sender.menu {
            for item in displayMenu.items {
                item.state = item.tag == idx ? .on : .off
            }
        }
    }

    @objc func toggleChar1(_ sender: NSMenuItem) {
        guard let chars = controller?.characters, chars.count > 0 else { return }
        let char = chars[0]
        if char.window.isVisible {
            char.window.orderOut(nil)
            char.queuePlayer.pause()
            sender.state = .off
        } else {
            char.window.orderFrontRegardless()
            char.queuePlayer.play()
            sender.state = .on
        }
    }

    @objc func toggleChar2(_ sender: NSMenuItem) {
        guard let chars = controller?.characters, chars.count > 1 else { return }
        let char = chars[1]
        if char.window.isVisible {
            char.window.orderOut(nil)
            char.queuePlayer.pause()
            sender.state = .off
        } else {
            char.window.orderFrontRegardless()
            char.queuePlayer.play()
            sender.state = .on
        }
    }

    @objc func toggleDebug(_ sender: NSMenuItem) {
        guard let debugWin = controller?.debugWindow else { return }
        if debugWin.isVisible {
            debugWin.orderOut(nil)
            sender.state = .off
        } else {
            debugWin.orderFrontRegardless()
            sender.state = .on
        }
    }

    @objc func toggleSounds(_ sender: NSMenuItem) {
        WalkerCharacter.soundsEnabled.toggle()
        sender.state = WalkerCharacter.soundsEnabled ? .on : .off
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}

extension AppDelegate: NSMenuDelegate {}