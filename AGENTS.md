# AGENTS.md

## Project Purpose

SleepToggle is a small native macOS menu bar application. It displays whether
sleep is currently disabled and toggles that state when the user clicks the
status item or presses the global `Control-Option-Command-S` (`⌃⌥⌘S`) shortcut.

The project is intentionally minimal: it has no Xcode project, Swift Package
Manager configuration, third-party dependencies, or test framework. The
application is compiled directly from a single source file with `swiftc`.

## Repository Structure

- `SleepToggle.swift` contains all runtime code: the application lifecycle,
  status item, state polling, sleep toggling, and global hotkey registration.
- `IOKitMessages.h` exposes the SDK's clamshell notification macro as a constant
  Swift can import; it contains no runtime implementation.
- `Info.plist` contains the app bundle metadata. `LSUIElement = true` hides the
  application from the Dock and the regular application switcher.
- `build.sh` builds `SleepToggle.app`, copies `Info.plist`, applies an ad-hoc
  code signature, and verifies the signature.
- `install.sh` runs the build first and then copies the bundle to
  `/Applications/SleepToggle.app`, using `sudo` when required.
- `uninstall.sh` removes the installed bundle from `/Applications`.
- `README.md` contains Russian and English user documentation, including the
  `sudoers` setup instructions.
- `test.sh` runs state-machine checks in `Tests/LidSessionTests.swift` without
  modifying system sleep settings; an optional live check reads the lid sensor.
- `.build/` and `SleepToggle.app/` are generated local artifacts and must not
  be committed.

## Environment Requirements

- macOS;
- Xcode Command Line Tools (`xcrun`, `swiftc`, the macOS SDK, and `codesign`);
- the system Cocoa, Carbon, and IOKit frameworks;
- `/usr/bin/pmset` and `/usr/bin/sudo` at their standard system paths.

Do not add a third-party package manager or an Xcode project without a clear
reason. The current build method is part of the application's intentionally
simple architecture.

## Main Commands

Run all commands from the repository root.

```sh
# Validate the plist syntax
plutil -lint Info.plist

# Build the local app bundle
./build.sh

# Optionally verify the resulting signature again
codesign --verify --deep --strict SleepToggle.app

# Install the application (may request an administrator password)
./install.sh

# Remove the installed application (may request an administrator password)
./uninstall.sh
```

`build.sh` is the primary compilation and packaging check. Run `./test.sh` for
automated lid-session checks. There are no automated UI tests.
`install.sh` and `uninstall.sh` modify
`/Applications`, so agents must not run them without an explicit need or a user
request.

## How the Application Works

1. `AppDelegate.applicationDidFinishLaunching` creates an `NSStatusItem`,
   assigns the click handler, updates the icon, starts a two-second polling
   timer, and registers the global hotkey.
2. `sleepDisabled()` runs `/usr/bin/pmset -g` and looks for the
   `SleepDisabled` setting. A value of `1` means sleep is disabled; `0` means it
   is enabled.
3. `updateIcon()` displays `☕` when sleep is disabled and `💤` when sleep is
   enabled.
4. `toggleSleep()` runs
   `sudo -n /usr/bin/pmset -a disablesleep <0|1>`. The `-n` flag prevents an
   interactive password prompt, which would otherwise leave the menu bar
   application waiting for unavailable terminal input.
5. `LidStateMonitor` subscribes to `kIOPMMessageClamshellStateChange` on
   `IOPMrootDomain` using IOKit. The message's bit 0 is the lid state; bit 1
   describes whether the lid causes sleep and must not advance the cycle.
   Callbacks run on the main dispatch queue; two-second polling is a fallback.
6. `LidSession` waits for close, then open, then a confirmed `disablesleep 0`.
   Its phase is saved in UserDefaults. Failed restoration retains the phase
   for retries. A normal quit restores sleep and is cancelled on failure.
7. The Carbon API registers the system-wide `⌃⌥⌘S` shortcut. The hotkey and
   event handler are released when the application terminates.

The application changes the system setting for every power source (`-a`), not
only for battery power or the AC adapter.

## Critical Security Constraints

Toggling requires a separate `sudoers` rule, as documented in the README:

```text
USERNAME ALL=(root) NOPASSWD: /usr/bin/pmset
```

- Never create or modify `/etc/sudoers` or `/etc/sudoers.d/*` automatically.
- Do not remove `sudo -n`: the application has no terminal in which to request
  a password interactively and safely.
- Do not broaden the rule to permit arbitrary commands, and do not interpolate
  shell command strings.
- Keep absolute paths to system executables and pass arguments through
  `Process.arguments`, not through a shell.
- Do not run `pmset -a disablesleep ...` as part of a routine build check. It
  changes an actual system setting on the computer.

## Change Guidelines

- Preserve the minimal structure and the existing Swift style.
- UI work and calls that affect `NSStatusItem` must run on the main thread.
- Preserve the value semantics: `SleepDisabled == 1` corresponds to the `☕`
  icon, while `SleepDisabled == 0` corresponds to `💤`.
- Check `Process.terminationStatus` and report launch failures or nonzero exit
  codes. Do not treat a `pmset` read failure as a confirmed system state.
- When changing the hotkey, update the Carbon key code, modifiers, tooltip, and
  both language versions of the README together.
- When changing user-visible behavior, requirements, installation steps, or
  security guidance, update the Russian and English README sections equally.
- When changing the executable or bundle name, update the Swift source filename
  if needed, `Info.plist`, `build.sh`, `install.sh`, `uninstall.sh`, and the
  documentation together.
- For a release, update `CFBundleShortVersionString` and `CFBundleVersion`
  consistently.
- Do not commit `SleepToggle.app`, `.build`, local IDE settings, or other
  generated files.
- Keep shell scripts compatible with `zsh`, retain `set -euo pipefail`, and
  quote paths. The repository path may contain spaces.

## Verifying Changes

The minimum checks for every change are:

```sh
plutil -lint Info.plist
zsh -n build.sh install.sh uninstall.sh test.sh
./test.sh
./build.sh
```

For behavior changes, also perform the following manual checks on macOS:

1. Launch the built `SleepToggle.app`.
2. Confirm that the application does not appear in the Dock and that its status
   item is visible.
3. Compare the icon and tooltip with the output of `pmset -g`.
4. Test toggling by clicking the status item and by pressing `⌃⌥⌘S`.
5. Test both transitions (`0 → 1` and `1 → 0`), then restore the original sleep
   setting.
6. Test the first close/open cycle, confirm normal sleep is restored, then
   confirm a subsequent close uses normal macOS sleep rules. Verify that
   repeated open notifications before the first close do not cancel the mode.
7. Confirm that behavior is understandable when the required `sudoers` rule is
   absent.
8. Quit the application and confirm that the global shortcut is released.

Only perform manual checks that change the sleep state with the machine owner's
consent. If the full manual check was not performed, clearly report which parts
remain unverified.

## Definition of Done

A change is complete when the bundle builds successfully and passes signature
verification, `Info.plist` and the shell scripts are valid, the documentation
reflects user-visible changes, and generated artifacts have not been added to
git. Runtime behavior changes must also receive the relevant manual checks, or
the unverified checks must be explicitly documented.
