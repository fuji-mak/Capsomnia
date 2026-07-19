import AppKit

let app = NSApplication.shared
app.appearance = NSAppearance(named: .darkAqua)
let delegate = Capsomnia()
app.delegate = delegate
app.run()
