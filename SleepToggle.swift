import Cocoa
import Carbon
import IOKit
import IOKit.pwr_mgt

private struct LidSession {
    enum Phase: String {
        case waitingForClose
        case waitingForOpen
        case restoringSleep
    }

    private(set) var phase: Phase?

    var needsRestore: Bool { phase == .restoringSleep }

    mutating func arm(isClosed: Bool) {
        phase = isClosed ? .waitingForOpen : .waitingForClose
    }

    mutating func observe(isClosed: Bool) {
        if phase == .waitingForClose, isClosed {
            phase = .waitingForOpen
        } else if phase == .waitingForOpen, !isClosed {
            phase = .restoringSleep
        }
    }

    mutating func cancel() {
        phase = nil
    }
}

private func lidIsClosed(messageFlags: UInt) -> Bool {
    messageFlags & UInt(kClamshellStateBit) != 0
}

private final class LidStateMonitor {
    var onChange: ((Bool) -> Void)?
    private var rootDomain: io_service_t = 0
    private var notification: io_object_t = 0
    private var port: IONotificationPortRef?

    var isClosed: Bool? {
        guard rootDomain != 0,
              let value = IORegistryEntryCreateCFProperty(
                rootDomain, kAppleClamshellStateKey as CFString,
                kCFAllocatorDefault, 0
              )?.takeRetainedValue() else {
            return nil
        }
        return value as? Bool
    }

    func start() -> Bool {
        stop()
        rootDomain = IOServiceGetMatchingService(
            kIOMainPortDefault, IOServiceMatching("IOPMrootDomain")
        )
        guard rootDomain != 0, isClosed != nil,
              let port = IONotificationPortCreate(kIOMainPortDefault) else {
            stop()
            return false
        }
        self.port = port

        let callback: IOServiceInterestCallback = { context, _, type, argument in
            guard type == UInt32(SleepToggleClamshellStateChange),
                  let context else { return }
            let monitor = Unmanaged<LidStateMonitor>
                .fromOpaque(context).takeUnretainedValue()
            // Capture the message's state, rather than a later registry read:
            // a fast close/open cycle must retain both ordered transitions.
            let flags = argument.map { UInt(bitPattern: $0) } ?? 0
            monitor.onChange?(lidIsClosed(messageFlags: flags))
        }

        let result = IOServiceAddInterestNotification(
            port, rootDomain, kIOGeneralInterest, callback,
            Unmanaged.passUnretained(self).toOpaque(), &notification
        )
        guard result == KERN_SUCCESS else {
            print("Не удалось подключить датчик крышки: \(result)")
            stop()
            return false
        }
        IONotificationPortSetDispatchQueue(port, DispatchQueue.main)
        return true
    }

    func stop() {
        if notification != 0 { IOObjectRelease(notification) }
        notification = 0
        if let port { IONotificationPortDestroy(port) }
        port = nil
        if rootDomain != 0 { IOObjectRelease(rootDomain) }
        rootDomain = 0
    }

    deinit { stop() }
}

private struct HotKey: Equatable {
    let keyCode: UInt32
    let modifiers: UInt32
    let keyLabel: String

    var displayString: String {
        var value = ""

        if modifiers & UInt32(controlKey) != 0 {
            value += "⌃"
        }
        if modifiers & UInt32(optionKey) != 0 {
            value += "⌥"
        }
        if modifiers & UInt32(shiftKey) != 0 {
            value += "⇧"
        }
        if modifiers & UInt32(cmdKey) != 0 {
            value += "⌘"
        }

        return value + keyLabel
    }
}

private final class ShortcutRecorderField: NSTextField {
    var hotKey: HotKey? {
        didSet {
            stringValue = hotKey?.displayString ?? "Не задано"
            onChange?(hotKey)
        }
    }

    var onChange: ((HotKey?) -> Void)?

    init(hotKey: HotKey?) {
        self.hotKey = hotKey
        super.init(frame: NSRect(x: 0, y: 0, width: 280, height: 34))

        stringValue = hotKey?.displayString ?? "Не задано"
        alignment = .center
        font = NSFont.monospacedSystemFont(ofSize: 16, weight: .medium)
        isEditable = false
        isSelectable = false
        isBezeled = true
        bezelStyle = .roundedBezel
        focusRingType = .exterior
        toolTip = "Нажмите желаемое сочетание клавиш"
        setAccessibilityLabel("Сочетание клавиш")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let hasPrimaryModifier = flags.contains(.command)
            || flags.contains(.option)
            || flags.contains(.control)

        guard hasPrimaryModifier else {
            if event.keyCode == UInt16(kVK_Escape)
                || event.keyCode == UInt16(kVK_Tab)
                || event.keyCode == UInt16(kVK_Return) {
                super.keyDown(with: event)
                return
            }

            NSSound.beep()
            return
        }

        guard let keyLabel = Self.keyLabel(for: event) else {
            NSSound.beep()
            return
        }

        var modifiers: UInt32 = 0
        if flags.contains(.control) {
            modifiers |= UInt32(controlKey)
        }
        if flags.contains(.option) {
            modifiers |= UInt32(optionKey)
        }
        if flags.contains(.shift) {
            modifiers |= UInt32(shiftKey)
        }
        if flags.contains(.command) {
            modifiers |= UInt32(cmdKey)
        }

        hotKey = HotKey(
            keyCode: UInt32(event.keyCode),
            modifiers: modifiers,
            keyLabel: keyLabel
        )
    }

    private static func keyLabel(for event: NSEvent) -> String? {
        if let functionKey = functionKeyLabel(for: Int(event.keyCode)) {
            return functionKey
        }

        switch Int(event.keyCode) {
        case kVK_Return:
            return "↩"
        case kVK_Tab:
            return "⇥"
        case kVK_Space:
            return "Space"
        case kVK_Delete:
            return "⌫"
        case kVK_Escape:
            return "⎋"
        case kVK_ForwardDelete:
            return "⌦"
        case kVK_Home:
            return "↖"
        case kVK_End:
            return "↘"
        case kVK_PageUp:
            return "⇞"
        case kVK_PageDown:
            return "⇟"
        case kVK_LeftArrow:
            return "←"
        case kVK_RightArrow:
            return "→"
        case kVK_DownArrow:
            return "↓"
        case kVK_UpArrow:
            return "↑"
        default:
            guard let characters = event.charactersIgnoringModifiers,
                  !characters.isEmpty else {
                return nil
            }

            return characters.uppercased()
        }
    }

    private static func functionKeyLabel(for keyCode: Int) -> String? {
        let functionKeys = [
            kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4",
            kVK_F5: "F5", kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8",
            kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
            kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15", kVK_F16: "F16",
            kVK_F17: "F17", kVK_F18: "F18", kVK_F19: "F19", kVK_F20: "F20"
        ]

        return functionKeys[keyCode]
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private enum DefaultsKey {
        static let hotKeyCode = "hotKeyCode"
        static let hotKeyModifiers = "hotKeyModifiers"
        static let hotKeyLabel = "hotKeyLabel"
        static let lidSessionPhase = "lidSessionPhase"
    }

    private let hotKeySignature = OSType(0x534C5054) // "SLPT"
    private let statusMenu = NSMenu()

    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var configuredHotKey: HotKey?
    private var activeHotKey: HotKey?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var lidMonitor: LidStateMonitor?
    private var lidSession = LidSession()
    private var restoreErrorShown = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        configureStatusMenu()

        let monitor = LidStateMonitor()
        monitor.onChange = { [weak self] closed in
            self?.handleLidChange(isClosed: closed)
        }
        if monitor.start() { lidMonitor = monitor }
        if let saved = UserDefaults.standard.string(forKey: DefaultsKey.lidSessionPhase) {
            lidSession = LidSession(phase: LidSession.Phase(rawValue: saved))
        }

        configuredHotKey = loadHotKey()
        if let configuredHotKey, !registerHotKey(configuredHotKey) {
            print(
                "Не удалось зарегистрировать горячую клавишу "
                    + configuredHotKey.displayString
            )
        }

        pollState()

        timer = Timer.scheduledTimer(
            timeInterval: 2,
            target: self,
            selector: #selector(pollState),
            userInfo: nil,
            repeats: true
        )
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )

        guard let button = statusItem.button else {
            return
        }

        button.target = self
        button.action = #selector(handleStatusItemClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configureStatusMenu() {
        statusMenu.autoenablesItems = false

        let shortcutItem = NSMenuItem(
            title: "Сменить сочетание клавиш…",
            action: #selector(showShortcutEditor),
            keyEquivalent: ""
        )
        shortcutItem.target = self
        statusMenu.addItem(shortcutItem)

        let quitItem = NSMenuItem(
            title: "Выйти из SleepToggle",
            action: #selector(quitApplication),
            keyEquivalent: ""
        )
        quitItem.target = self
        statusMenu.addItem(quitItem)
    }

    // MARK: - Обработка значка и меню

    @objc private func handleStatusItemClick() {
        switch NSApp.currentEvent?.type {
        case .leftMouseUp:
            toggleSleep()
        case .rightMouseUp:
            showStatusMenu()
        default:
            break
        }
    }

    private func showStatusMenu() {
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            self.statusItem.menu = self.statusMenu
            self.statusItem.button?.performClick(nil)
            self.statusItem.menu = nil
        }
    }

    @objc private func quitApplication() {
        NSApp.terminate(nil)
    }

    // MARK: - Проверка текущего состояния

    private func sleepDisabled() -> Bool? {
        let task = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        task.arguments = ["-g"]
        task.standardOutput = outputPipe
        task.standardError = errorPipe

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            print("Ошибка запуска pmset: \(error)")
            return nil
        }

        guard task.terminationStatus == 0 else {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let error = String(data: data, encoding: .utf8) ?? ""
            print("Ошибка pmset (код \(task.terminationStatus)): \(error)")
            return nil
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        for line in output.components(separatedBy: .newlines) {
            if line.contains("SleepDisabled") {
                let parts = line.split(whereSeparator: { $0.isWhitespace })

                if let value = parts.last, value == "0" || value == "1" {
                    return value == "1"
                }
            }
        }

        print("pmset не вернул значение SleepDisabled")
        return nil
    }

    // MARK: - Иконка

    private func saveLidSession() {
        if let phase = lidSession.phase {
            UserDefaults.standard.set(phase.rawValue, forKey: DefaultsKey.lidSessionPhase)
        } else {
            UserDefaults.standard.removeObject(forKey: DefaultsKey.lidSessionPhase)
        }
    }

    private func cancelLidSession() {
        guard lidSession.phase != nil else { return }
        lidSession.cancel()
        restoreErrorShown = false
        saveLidSession()
    }

    private func handleLidChange(isClosed: Bool) {
        let previous = lidSession.phase
        lidSession.observe(isClosed: isClosed)
        if lidSession.phase != previous { saveLidSession() }
        restoreSleepIfNeeded()
        updateIcon()
    }

    @objc private func pollState() {
        // Reconcile external pmset changes before retrying a failed restore.
        if sleepDisabled() == false { cancelLidSession() }
        if let closed = lidMonitor?.isClosed {
            handleLidChange(isClosed: closed)
        } else {
            restoreSleepIfNeeded()
            updateIcon()
        }
    }

    private func restoreSleepIfNeeded() {
        guard lidSession.needsRestore else { return }
        if setSleepDisabled(false) {
            cancelLidSession()
        } else if !restoreErrorShown {
            restoreErrorShown = true
            showSessionError(
                "Крышка открыта, но вернуть обычный сон не удалось. "
                    + "Проверьте правило sudoers для pmset. "
                    + "SleepToggle продолжит попытки восстановления."
            )
        }
    }

    @objc private func updateIcon() {
        guard let sleepIsDisabled = sleepDisabled() else {
            statusItem.button?.title = "❔"
            statusItem.button?.toolTip =
                "Не удалось определить состояние сна — правый клик: меню"
            return
        }

        statusItem.button?.title = sleepIsDisabled ? "☕" : "💤"

        if !sleepIsDisabled { cancelLidSession() }

        var state = sleepIsDisabled
            ? "Спящий режим отключён"
            : "Спящий режим включён"

        switch lidSession.phase {
        case .waitingForClose:
            state += " до первого закрытия и открытия крышки"
        case .waitingForOpen:
            state += " до открытия крышки"
        case .restoringSleep:
            state += " — повторная попытка восстановления"
        case nil:
            break
        }

        if let activeHotKey {
            statusItem.button?.toolTip =
                "\(state) — \(activeHotKey.displayString); правый клик: меню"
        } else if configuredHotKey != nil {
            statusItem.button?.toolTip =
                "\(state) — сочетание недоступно; правый клик: меню"
        } else {
            statusItem.button?.toolTip = "\(state) — правый клик: меню"
        }
    }

    // MARK: - Переключение сна

    @objc private func toggleSleep() {
        guard let current = sleepDisabled() else {
            return
        }

        if current {
            if setSleepDisabled(false) { cancelLidSession() }
        } else {
            guard let closed = lidMonitor?.isClosed else {
                showSessionError("Датчик крышки недоступен. Режим до открытия крышки не включён.")
                return
            }
            if setSleepDisabled(true) {
                lidSession.arm(isClosed: closed)
                restoreErrorShown = false
                saveLidSession()
            }
        }
        updateIcon()
    }

    @discardableResult
    private func setSleepDisabled(_ disabled: Bool) -> Bool {
        let newValue = disabled ? "1" : "0"
        let task = Process()

        task.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        task.arguments = [
            "-n",
            "/usr/bin/pmset",
            "-a",
            "disablesleep",
            newValue
        ]

        let errorPipe = Pipe()
        task.standardError = errorPipe

        do {
            try task.run()
            task.waitUntilExit()

            if task.terminationStatus != 0 {
                let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let error = String(data: data, encoding: .utf8) ?? ""
                print("Ошибка pmset: \(error)")
                return false
            }

            return sleepDisabled() == disabled
        } catch {
            print("Ошибка запуска sudo/pmset: \(error)")
            return false
        }
    }

    private func showSessionError(_ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Режим до открытия крышки"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - Настройка глобальной горячей клавиши

    @objc private func showShortcutEditor() {
        NSApp.activate(ignoringOtherApps: true)

        let hotKeyWasActive = activeHotKey != nil
        if hotKeyWasActive {
            unregisterHotKey()
        }

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Сочетание клавиш"
        alert.informativeText =
            "Нажмите новое сочетание. Используйте хотя бы один из модификаторов "
            + "⌘, ⌥ или ⌃."

        let recorder = ShortcutRecorderField(hotKey: configuredHotKey)
        alert.accessoryView = recorder

        let saveButton = alert.addButton(withTitle: "Сохранить")
        let cancelButton = alert.addButton(withTitle: "Отмена")
        let disableButton = alert.addButton(withTitle: "Отключить")

        saveButton.isEnabled = recorder.hotKey != nil
        cancelButton.keyEquivalent = "\u{1b}"
        disableButton.isEnabled = configuredHotKey != nil

        recorder.onChange = { hotKey in
            saveButton.isEnabled = hotKey != nil
        }
        alert.window.initialFirstResponder = recorder

        let response = alert.runModal()

        if response == .alertFirstButtonReturn, let hotKey = recorder.hotKey {
            if !replaceHotKey(with: hotKey) {
                showHotKeyRegistrationError(hotKey)
            }
        } else if response == .alertThirdButtonReturn {
            disableHotKey()
        } else if hotKeyWasActive, let configuredHotKey {
            _ = registerHotKey(configuredHotKey)
            updateIcon()
        }
    }

    private func replaceHotKey(with hotKey: HotKey) -> Bool {
        if configuredHotKey == hotKey, activeHotKey == hotKey {
            return true
        }

        let previousHotKey = configuredHotKey
        unregisterHotKey()

        guard registerHotKey(hotKey) else {
            if let previousHotKey {
                _ = registerHotKey(previousHotKey)
            }
            updateIcon()
            return false
        }

        configuredHotKey = hotKey
        saveHotKey(hotKey)
        updateIcon()
        return true
    }

    private func disableHotKey() {
        unregisterHotKey()
        configuredHotKey = nil

        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: DefaultsKey.hotKeyCode)
        defaults.removeObject(forKey: DefaultsKey.hotKeyModifiers)
        defaults.removeObject(forKey: DefaultsKey.hotKeyLabel)

        updateIcon()
    }

    private func installHotKeyEventHandlerIfNeeded() -> Bool {
        if eventHandlerRef != nil {
            return true
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handler: EventHandlerUPP = { _, _, userData in
            guard let userData else {
                return noErr
            }

            let delegate = Unmanaged<AppDelegate>
                .fromOpaque(userData)
                .takeUnretainedValue()

            DispatchQueue.main.async {
                delegate.toggleSleep()
            }

            return noErr
        }

        let result = InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )

        if result != noErr {
            eventHandlerRef = nil
            print("Не удалось установить обработчик хоткея: \(result)")
            return false
        }

        return true
    }

    private func registerHotKey(_ hotKey: HotKey) -> Bool {
        guard installHotKeyEventHandlerIfNeeded() else {
            return false
        }

        let hotKeyID = EventHotKeyID(signature: hotKeySignature, id: 1)
        var newHotKeyRef: EventHotKeyRef?

        let result = RegisterEventHotKey(
            hotKey.keyCode,
            hotKey.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &newHotKeyRef
        )

        guard result == noErr, let newHotKeyRef else {
            print(
                "Не удалось зарегистрировать \(hotKey.displayString): \(result)"
            )
            return false
        }

        hotKeyRef = newHotKeyRef
        activeHotKey = hotKey
        print("Горячая клавиша \(hotKey.displayString) зарегистрирована")
        return true
    }

    private func unregisterHotKey() {
        if let hotKeyRef {
            let result = UnregisterEventHotKey(hotKeyRef)
            if result != noErr {
                print("Не удалось снять регистрацию хоткея: \(result)")
            }
        }

        hotKeyRef = nil
        activeHotKey = nil
    }

    private func saveHotKey(_ hotKey: HotKey) {
        let defaults = UserDefaults.standard
        defaults.set(Int(hotKey.keyCode), forKey: DefaultsKey.hotKeyCode)
        defaults.set(Int(hotKey.modifiers), forKey: DefaultsKey.hotKeyModifiers)
        defaults.set(hotKey.keyLabel, forKey: DefaultsKey.hotKeyLabel)
    }

    private func loadHotKey() -> HotKey? {
        let defaults = UserDefaults.standard

        guard defaults.object(forKey: DefaultsKey.hotKeyCode) != nil,
              defaults.object(forKey: DefaultsKey.hotKeyModifiers) != nil,
              let keyLabel = defaults.string(forKey: DefaultsKey.hotKeyLabel),
              !keyLabel.isEmpty else {
            return nil
        }

        let keyCode = defaults.integer(forKey: DefaultsKey.hotKeyCode)
        let modifiersValue = defaults.integer(
            forKey: DefaultsKey.hotKeyModifiers
        )

        guard keyCode >= 0,
              keyCode <= Int(UInt16.max),
              modifiersValue >= 0,
              modifiersValue <= Int(UInt32.max) else {
            return nil
        }

        let modifiers = UInt32(modifiersValue)
        let primaryModifiers = UInt32(controlKey | optionKey | cmdKey)

        guard modifiers & primaryModifiers != 0 else {
            return nil
        }

        return HotKey(
            keyCode: UInt32(keyCode),
            modifiers: modifiers,
            keyLabel: keyLabel
        )
    }

    private func showHotKeyRegistrationError(_ hotKey: HotKey) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Не удалось назначить сочетание"
        alert.informativeText =
            "Сочетание \(hotKey.displayString) может быть занято системой или "
            + "другим приложением либо недоступно. Выберите другое сочетание."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard lidSession.phase != nil else { return .terminateNow }
        guard setSleepDisabled(false) else {
            showSessionError("Не удалось вернуть обычный сон. Проверьте права pmset перед выходом.")
            return .terminateCancel
        }
        cancelLidSession()
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        lidMonitor?.stop()
        unregisterHotKey()

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()

app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
