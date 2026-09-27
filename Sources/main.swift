import Cocoa

freopen("/tmp/agentspeak.log", "a+", stdout)
freopen("/tmp/agentspeak.log", "a+", stderr)

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
