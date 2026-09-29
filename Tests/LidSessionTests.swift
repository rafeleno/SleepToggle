
private func expect(_ value: @autoclosure () -> Bool, _ message: String) {
    precondition(value(), message)
}

private var session = LidSession()
session.observe(isClosed: true)
session.observe(isClosed: false)
expect(session.phase == nil, "Inactive lid events cannot arm a session")

session.arm(isClosed: false)
for _ in 0..<3 { session.observe(isClosed: false) }
expect(session.phase == .waitingForClose, "Open notifications before a close cannot finish")
session.observe(isClosed: true)
expect(session.phase == .waitingForOpen, "First close starts waiting for open")
session.observe(isClosed: true)
expect(!session.needsRestore, "Repeated close keeps sleep disabled")
session.observe(isClosed: false)
expect(session.needsRestore, "First reopen restores sleep")
session.observe(isClosed: true)
session.observe(isClosed: false)
expect(session.needsRestore, "Failed restoration stays pending for retries")
session.cancel()
session.observe(isClosed: true)
session.observe(isClosed: false)
expect(session.phase == nil, "A second cycle cannot reactivate the mode")

session.arm(isClosed: true)
expect(session.phase == .waitingForOpen, "Starting closed lasts until opening")
session.observe(isClosed: false)
expect(session.needsRestore, "Opening an initially closed lid ends the session")
session.cancel()

session.arm(isClosed: false)
session.cancel()
session.observe(isClosed: true)
session.observe(isClosed: false)
expect(session.phase == nil, "Manual cancellation prevents later automatic actions")
session.arm(isClosed: false)
expect(session.phase == .waitingForClose, "Reactivation starts a fresh cycle")

for phase in [LidSession.Phase.waitingForClose, .waitingForOpen, .restoringSleep] {
    expect(LidSession.Phase(rawValue: phase.rawValue) == phase, "Saved phase round trip")
}
private var resumed = LidSession(phase: .waitingForOpen)
resumed.observe(isClosed: false)
expect(resumed.needsRestore, "Relaunch with open lid completes an observed close")
resumed = LidSession(phase: .waitingForClose)
resumed.observe(isClosed: false)
expect(!resumed.needsRestore, "Relaunch before close keeps the session armed")
resumed.observe(isClosed: true)
expect(resumed.phase == .waitingForOpen, "Relaunch with lid closed remembers close")
expect(LidSession.Phase(rawValue: "invalid") == nil, "Invalid saved state is ignored")

expect(!lidIsClosed(messageFlags: 0), "Open lid flag")
expect(lidIsClosed(messageFlags: 1), "Closed lid flag")
expect(!lidIsClosed(messageFlags: 2), "Causes-sleep flag is not a closed lid")
expect(lidIsClosed(messageFlags: 3), "Closed lid with causes-sleep flag")
print("Lid session state and notification checks passed")

if ProcessInfo.processInfo.environment["SLEEP_TOGGLE_LIVE_SENSOR_CHECK"] == "1" {
    let monitor = LidStateMonitor()
    expect(monitor.start(), "Actual lid sensor subscription")
    expect(monitor.isClosed != nil, "Actual lid sensor read")
    print("Live lid sensor subscription and read passed; closed=\(monitor.isClosed!)")
    monitor.stop()
    expect(monitor.isClosed == nil, "Monitor releases its registry handle")
}

private let powerCases: [(String, Bool?)] = [
    ("System-wide power settings:\nCurrently in use:\n sleep 1\n", false),
    ("System-wide power settings:\n SleepDisabled\t\t1\n", true),
    ("System-wide power settings:\n SleepDisabled 0\n", false),
    ("System-wide power settings:\n SleepDisabled invalid\n", nil),
    ("System-wide power settings:\n SleepDisabled\n", nil),
    ("", nil),
    ("error: cannot read preferences", nil),
    ("Currently in use:\n sleep 0\n", nil)
]
for (index, item) in powerCases.enumerated() {
    expect(parseSleepDisabled(in: item.0) == item.1, "Power state parser case \(index)")
}
print("8 sleep state parser regression checks passed")
