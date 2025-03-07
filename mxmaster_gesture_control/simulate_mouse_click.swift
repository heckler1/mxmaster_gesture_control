// Handles a full button press: up and down
func simulateMouseClick(_ mouseButtonClicked: CGMouseButton) {

  var mouseLocation = NSEvent.mouseLocation
  var mouseTypeUp: CGEventType!
  var mouseTypeDown: CGEventType!

  switch mouseButtonClicked {
  case .left:
    mouseTypeUp = .leftMouseUp
    mouseTypeDown = .leftMouseDown
  case .right:
    mouseTypeUp = .rightMouseUp
    mouseTypeDown = .rightMouseDown
  default:
    mouseTypeUp = .otherMouseUp
    mouseTypeDown = .otherMouseDown
  }

  mouseLocation.y = NSHeight(NSScreen.screens[0].frame) - mouseLocation.y
  let point = CGPoint(x: mouseLocation.x, y: mouseLocation.y)
  let mouseDown = CGEvent(
    mouseEventSource: nil, mouseType: mouseTypeDown, mouseCursorPosition: point,
    mouseButton: CGMouseButton(rawValue: mouseButtonClicked.rawValue)!)
  let mouseUp = CGEvent(
    mouseEventSource: nil, mouseType: mouseTypeUp, mouseCursorPosition: point,
    mouseButton: CGMouseButton(rawValue: mouseButtonClicked.rawValue)!)

  mouseDown?.post(tap: .cgSessionEventTap)
  usleep(500)
  mouseUp?.post(tap: .cgSessionEventTap)
}
