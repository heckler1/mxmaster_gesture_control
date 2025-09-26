//
//  main.swift
//  scroll_to_plusminus
//
//  Created by uniqueidentifier on 2021-01-08.
//  Modified by alex on 2022-07-08 to use modifiers for scrolling
//  Modified by BalazsGyarmati on 2023-01-04 to use command instead of control + respect any keyboard layout for + and -
//  Modified by sheckler on 2024-01-18 to handle MX Master mouse gestures for VirtualDesktop switching

import AppKit
import CoreGraphics
import Foundation
import os.log

// MARK: - Error Handling

/// Errors that can occur during gesture processing and event handling.
enum GestureError: Error {
  /// Failed to create Core Graphics event tap due to insufficient permissions or system restrictions
  case eventTapCreationFailed
  /// Failed to create a keyboard event for simulation
  case keyboardEventCreationFailed(key: CGKeyCode)
  /// Failed to post an event to the system
  case eventPostingFailed
  /// Invalid event data received from system
  case invalidEventData
}

// MARK: - Logging

/// Centralized logging for the MXMaster gesture control application.
struct Logger {
  /// OSLog instance for gesture control events
  private static let gestureLog = OSLog(subsystem: "com.mxmaster.gesturecontrol", category: "gesture")
  
  /// OSLog instance for system events and errors
  private static let systemLog = OSLog(subsystem: "com.mxmaster.gesturecontrol", category: "system")
  
  /// Logs gesture-related events
  static func gesture(_ message: String, type: OSLogType = .default) {
    os_log("%{public}@", log: gestureLog, type: type, message)
  }
  
  /// Logs system-related events and errors
  static func system(_ message: String, type: OSLogType = .default) {
    os_log("%{public}@", log: systemLog, type: type, message)
  }
  
  /// Logs error conditions
  static func error(_ message: String) {
    os_log("%{public}@", log: systemLog, type: .error, message)
  }
  
  /// Logs debug information (only in debug builds)
  static func debug(_ message: String) {
    #if DEBUG
    os_log("%{public}@", log: gestureLog, type: .debug, message)
    #endif
  }
}

/// Virtual key codes for keyboard input simulation.
/// 
/// Maps to Carbon framework key codes for use with Core Graphics event generation.
/// These values correspond to physical key locations and are independent of keyboard layout.
/// Reference: https://github.com/phracker/MacOSX-SDKs/blob/master/MacOSX10.15.sdk/System/Library/Frameworks/Carbon.framework/Versions/A/Frameworks/HIToolbox.framework/Versions/A/Headers/Events.h#L275
/// See also: https://gist.github.com/chipjarred/cbb324c797aec865918a8045c4b51d14
enum Keys: CGKeyCode {
  /// Control key for modifier combinations
  /// kVK_Control from Carbon framework (0x3B)
  case control = 59
  
  /// Arrow keys for virtual desktop navigation
  case leftArrow = 123    /// Left arrow key for previous desktop
  case rightArrow = 124   /// Right arrow key for next desktop
  case downArrow = 125    /// Down arrow key
  case upArrow = 126      /// Up arrow key
  
  /// Mission Control key for macOS Spaces overview
  case missionControl = 160
}

/// Handles mouse gesture recognition and keyboard event simulation for MX Master mouse.
/// 
/// This class creates a Core Graphics event tap to intercept mouse events from button 27
/// (a virtual button mapped by Karabiner to the gesture button on MX Master mice)
/// and translates drag gestures into virtual desktop switching commands using keyboard shortcuts.
/// 
/// ## Gesture Recognition:
/// - **Left/Right gestures**: Switch between virtual desktops using simulated Control+Arrow keys
/// - **Up gesture**: Open Mission Control overview
/// - **Down gesture**: Show windows for current application on the current desktop using simulated Control+Down arrow
/// - **Button tap**: Open Mission Control (when not dragging)
class EventTap {
  
  // MARK: - Gesture Detection Constants
  
  /// Threshold to consider this an intentional mouse movement.
  /// Very small movements are likely a button press with a slight shake of the mouse.
  /// Use an average here to artificially increase the precision since we only have integer values.
  /// A threshold of 1 for each axis isn't sensitive enough to catch small but intentional flicks.
  /// A threshold of 0 has too many false positives that result in unintentional virtual desktop changes.
  private static let movementThreshold = 1
  
  /// Threshold to consider the movement clearly in the x or y direction
  private static let directionThreshold = 3
  
  /// Threshold for a "large" movement that we want to double check the validity of
  private static let largeMovementThreshold = 15
  
  /// For large movements to be considered invalid due to being mostly diagonal.
  /// This is a minimum delta between the absolute values of x and y.
  private static let diagonalThreshold = 7
  
  /// Mouse button number for gesture detection (0-indexed, corresponds to button 27 in Karabiner)
  private static let gestureButtonNumber: Int64 = 26
  
  // MARK: - Key Press Timing Constants
  private static let controlKeyDelay: UInt32 = 50  // microseconds
  private static let controlKeyReleaseDelay: UInt32 = 20  // microseconds

  /// Core Foundation run loop source for the event tap
  /// Set to nil when no event tap is active, non-nil when actively monitoring events
  static var runLoopSource: CFRunLoopSource? = nil
  
  /// Event tap location for intercepting mouse events at session level
  private static var tap: CGEventTapLocation = .cgSessionEventTap
  
  /// Tracks whether user is currently performing a drag gesture
  /// Used to differentiate between button taps and drag gestures
  static var dragging: Bool = false

  /// Creates and starts the event tap to monitor mouse gestures.
  /// 
  /// This method sets up a Core Graphics event tap that monitors mouse events from
  /// the MX Master gesture button. The event tap runs on the current run loop and
  /// will continue monitoring until `remove()` is called.
  /// 
  /// ## Behavior:
  /// - Removes any existing event tap before creating a new one
  /// - Creates event tap for mouse button events (down, up, dragged)
  /// - Starts the Core Foundation run loop to process events
  /// 
  /// ## Requirements:
  /// - Must be called from the main thread
  /// - Requires Accessibility permissions in System Preferences
  /// 
  /// - Warning: This method will call `fatalError()` if event tap creation fails,
  ///   typically due to insufficient permissions.
  static func create() {
    Logger.system("Starting event tap creation")
    
    if runLoopSource != nil { 
      Logger.system("Removing existing event tap before creating new one")
      EventTap.remove() 
    }

    do {
      let tap = try CGEventTap.createSafe(tap: self.tap, callback: tapCallback)
      
      runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, CFIndex(0))
      CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
      CGEvent.tapEnable(tap: tap, enable: true)
      
      Logger.system("Event tap created successfully, starting run loop")
      CFRunLoopRun()
    } catch {
      Logger.error("Failed to create event tap: \(error.localizedDescription)")
      Logger.system("Application will exit due to event tap creation failure")
      Logger.system("Please check: 1) Accessibility permissions in System Preferences 2) Application is not sandboxed 3) Running with appropriate user permissions")
      exit(1)
    }
  }

  /// Removes the active event tap and stops monitoring mouse gestures.
  /// 
  /// This method safely cleans up the event tap and removes it from the current
  /// run loop. It's safe to call this method multiple times or when no event tap
  /// is active.
  /// 
  /// ## Behavior:
  /// - Removes the run loop source from the current run loop
  /// - Sets `runLoopSource` to nil to indicate no active monitoring
  /// - Does nothing if no event tap is currently active
  static func remove() {
    guard let source = runLoopSource else { 
      Logger.debug("No active event tap to remove")
      return 
    }
    
    Logger.system("Removing event tap and stopping run loop monitoring")
    CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
    runLoopSource = nil
    Logger.system("Event tap removed successfully")
  }

  /// Simulates a keyboard key press with optional modifier keys.
  /// 
  /// This method creates and posts Core Graphics keyboard events to simulate
  /// key presses. It handles the complexity of modifier key timing, particularly
  /// for Control+Arrow combinations which require special sequencing.
  /// 
  /// - Parameters:
  ///   - key: The virtual key code to press (see `Keys` enum)
  ///   - command: Whether to hold the Command (⌘) key during the press
  ///   - control: Whether to hold the Control (⌃) key during the press
  /// 
  /// ## Special Handling:
  /// - **Control+Arrow keys**: Control is pressed separately with timing delays
  ///   to ensure proper system recognition for virtual desktop switching
  /// - **Other combinations**: Modifier flags are applied to the main key events
  /// 
  /// ## Timing:
  /// - Uses `controlKeyDelay` (50μs) between Control press and arrow key
  /// - Uses `controlKeyReleaseDelay` (20μs) before Control release
  static func keyPress(_ key: CGKeyCode, _ command: Bool, _ control: Bool) {
    let source = CGEventSource(stateID: .privateState)

    let arrow = (key == Keys.rightArrow.rawValue || key == Keys.leftArrow.rawValue || key == Keys.upArrow.rawValue || key == Keys.downArrow.rawValue)

    if control && arrow {
      // Specifically for use with arrow keys, the control key must be pressed "manually" like this,
      // and must also have the Control modifier flag
      // One or the other is not enough: adding the flag to the actual arrow events will not work
      if let event = CGEvent(keyboardEventSource: source, virtualKey: Keys.control.rawValue, keyDown: true) {
        event.flags = CGEventFlags.maskControl
        event.post(tap: self.tap)
        Logger.debug("Posted Control key down event for arrow key combination")
      } else {
        Logger.error("Failed to create Control key down event for key combination")
      }
      // The sleeps are necessary to allow the system to recognize the control key has been pressed before sending the arrows
      // usleep(100) is very reliable but 50 seems pretty close to the minimum value
      usleep(controlKeyDelay)
    }

    // Button down
    if let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true) {
      if command {
        event.flags = CGEventFlags.maskCommand
      }
      if control && !arrow {
        if command {
          event.flags = [CGEventFlags.maskCommand, CGEventFlags.maskControl]
        } else {
          event.flags = CGEventFlags.maskControl
        }
      }

      event.post(tap: self.tap)
      Logger.debug("Posted key down event for key: \(key)")
    } else {
      Logger.error("Failed to create key down event for key: \(key)")
    }

    // Button up
    if let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false) {
      if command {
        event.flags =  CGEventFlags.maskCommand
      }
      if control && !arrow {
        if command {
          event.flags = [CGEventFlags.maskCommand, CGEventFlags.maskControl]
        } 
        else {
          event.flags = CGEventFlags.maskControl
        }
      }

      event.post(tap: self.tap)
      Logger.debug("Posted key up event for key: \(key)")
    } else {
      Logger.error("Failed to create key up event for key: \(key)")
    }

    if control && arrow {
        usleep(controlKeyReleaseDelay)
        if let event = CGEvent(keyboardEventSource: source, virtualKey: Keys.control.rawValue, keyDown: false) {
          event.flags = CGEventFlags.maskControl
          event.post(tap: self.tap)
          Logger.debug("Posted Control key up event for arrow key combination")
        } else {
          Logger.error("Failed to create Control key up event for key combination")
        }
    }
  }

  /// Core event handler for intercepted mouse events.
  /// 
  /// This method is called by the Core Graphics framework whenever a monitored
  /// mouse event occurs. It processes gesture button events and determines the
  /// appropriate response based on the event type and user gesture.
  /// 
  /// - Parameters:
  ///   - proxy: Event tap proxy (TODO: unused in current implementation)
  ///   - type: The type of mouse event that occurred
  ///   - immutableEvent: The mouse event data, or nil if event creation failed
  ///   - refcon: User-defined reference data (TODO: unused)
  /// 
  /// - Returns: The event to pass through to other applications, or nil to consume the event
  /// 
  /// ## Event Handling:
  /// - **`.otherMouseUp`**: Handles gesture button release (tap vs drag completion)
  /// - **`.otherMouseDragged`**: Processes ongoing drag gestures for direction detection
  /// - **Other events**: Passed through unchanged
  /// 
  /// ## Button Mapping:
  /// - Only processes events from button 26 (0-indexed) which corresponds to
  ///   button 27 mapped by Karabiner to the gesture button on MX Master mice
  /// 
  /// - Note: This method must be marked `@objc class func` to be compatible
  ///   with the Core Graphics C callback system.
  @objc class func handleEvent(
    proxy: CGEventTapProxy, type: CGEventType, event immutableEvent: CGEvent?,
    refcon: UnsafeMutableRawPointer?
  ) -> CGEvent? {

    guard let event = immutableEvent else { return nil }

    switch type {
    case .otherMouseUp:
      // eventButtonNumber is 0-indexed, most other software displays it as 1-indexed though
      switch event.getIntegerValueField(.mouseEventButtonNumber) {
      case gestureButtonNumber:
        // If the user was in the middle of a drag, now they've lifted the button and are done
        if self.dragging {
          Logger.gesture("Gesture drag completed, consuming button release event")
          self.dragging = false
          // eat the event if they were in the middle of a drag
          return nil
        }
        // otherwise they weren't dragging, let's open mission control
        Logger.gesture("Gesture button tap detected, opening Mission Control")
        self.keyPress(Keys.missionControl.rawValue, false, false)
        return nil
      default:
        return event
      }
    
    // We set forward and back conversion here as well
    // These buttons should be converted to the proper keyboard shortcuts 
    // regardless of reversing the forward and back mapping, for proper interpretation by all apps
    // We used to just do all this in Karabiner, but recent IT policy changes
    // prevent Karabiner's virtual device driver from being loaded
    case .otherMouseDown:
      // eventButtonNumber is 0-indexed, most other software displays it as 1-indexed though
      switch event.getIntegerValueField(.mouseEventButtonNumber) {
      case 3:
        // forward
        // TODO: Make the swapping behavior here configurable
        self.keyPress(Keys.rightArrow.rawValue, true, false)
        return nil
      case 4:
        // back
        self.keyPress(Keys.leftArrow.rawValue, true, false)
        return nil
      default:
        return event
      }
    case .otherMouseDragged:
      // eventButtonNumber is 0-indexed: this is button27 in Karabiner
      if event.getIntegerValueField(.mouseEventButtonNumber) == gestureButtonNumber {
        return handleGestureEvent(event: event)
      }
      return event

    default:
      return event

    }
  }
  
  // MARK: - Private Gesture Handling Methods
  
  /// Handles gesture detection and processing for mouse drag events.
  /// 
  /// This method processes mouse drag movements to determine if they constitute
  /// a valid gesture and executes the appropriate keyboard command. It implements
  /// a multi-stage validation process to filter out accidental movements.
  /// 
  /// - Parameter event: The mouse drag event containing movement delta information
  /// - Returns: nil (event is always consumed for gesture button drags)
  /// 
  /// ## Processing Pipeline:
  /// 1. **Movement Validation**: Checks if movement exceeds minimum threshold
  /// 2. **Diagonal Filtering**: Rejects large diagonal movements as invalid
  /// 3. **Direction Analysis**: Determines intended gesture direction
  /// 4. **Action Execution**: Triggers appropriate keyboard shortcut
  /// 
  /// ## State Management:
  /// - Sets `dragging = true` when valid movement is detected
  /// - This prevents button release from triggering Mission Control
  private static func handleGestureEvent(event: CGEvent) -> CGEvent? {
    let deltaX = event.getIntegerValueField(.mouseEventDeltaX)
    let deltaY = event.getIntegerValueField(.mouseEventDeltaY)
    
    Logger.debug("Processing gesture drag: deltaX=\(deltaX), deltaY=\(deltaY)")
    
    // Check if movement meets minimum threshold
    guard isMovementSignificant(deltaX: deltaX, deltaY: deltaY) else {
      Logger.debug("Movement below threshold, ignoring gesture")
      return nil
    }
    
    // Set dragging state for successful gesture detection
    dragging = true
    
    // Validate large movements aren't too diagonal
    guard isValidLargeMovement(deltaX: deltaX, deltaY: deltaY) else {
      Logger.debug("Large diagonal movement detected, ignoring as invalid gesture")
      return nil
    }
    
    // Execute the appropriate gesture action
    executeGestureAction(deltaX: deltaX, deltaY: deltaY)
    return nil
  }
  
  /// Checks if mouse movement meets the minimum threshold for gesture detection.
  /// 
  /// Uses an averaged threshold calculation to improve precision with integer values.
  /// This helps distinguish between intentional gestures and accidental hand tremor
  /// or minor mouse movements during button presses.
  /// 
  /// - Parameters:
  ///   - deltaX: Horizontal mouse movement since last event
  ///   - deltaY: Vertical mouse movement since last event
  /// - Returns: true if movement is significant enough to be considered a gesture
  /// 
  /// ## Threshold Logic:
  // Use averaging here to artificially increase the precision.
  // Because we only have an integer value, it's harder to accurately detect small movements
  // A movement threshold of 1 for each axis isn't sensitive enough to catch small but intentional flicks
  // A threshold of 0 has too many false positives that result in unintentional virtual desktop changes
  private static func isMovementSignificant(deltaX: Int64, deltaY: Int64) -> Bool {
    return (abs(deltaX) + abs(deltaY))/2 >= movementThreshold
  }
  
  /// Validates that large movements aren't too diagonal to be considered valid gestures.
  /// 
  /// Large diagonal movements are often accidental (like moving the mouse while
  /// clicking) rather than intentional directional gestures. This method filters
  /// out such movements to prevent unintended desktop switching.
  /// 
  /// - Parameters:
  ///   - deltaX: Horizontal mouse movement delta
  ///   - deltaY: Vertical mouse movement delta
  /// - Returns: true if the movement is valid, false if too diagonal
  /// 
  /// ## Validation Logic:
  /// - Only applies to movements exceeding `largeMovementThreshold`
  /// - Rejects movements where `abs(deltaX) - abs(deltaY) < diagonalThreshold`
  /// - Allows clearly directional movements through
  private static func isValidLargeMovement(deltaX: Int64, deltaY: Int64) -> Bool {
    // If we have a large movement
    if abs(deltaX) > largeMovementThreshold || abs(deltaY) > largeMovementThreshold {
      // And the movement is sufficiently diagonal
      if (abs(deltaX) - abs(deltaY)) < diagonalThreshold {
        // Do nothing, this isn't a good signal
        return false
      }
    }
    return true
  }
  
  /// Determines direction and executes the appropriate key press for the gesture.
  /// 
  /// Analyzes the movement vector to determine the user's intended direction and
  /// triggers the corresponding virtual desktop or Mission Control command.
  /// 
  /// - Parameters:
  ///   - deltaX: Horizontal movement delta (negative = left, positive = right)
  ///   - deltaY: Vertical movement delta (negative = up, positive = down)
  /// 
  /// ## Direction Priority:
  /// 1. **Small movements**: Always prefer horizontal (left/right) direction
  /// 2. **Clear directional movements**: Use the dominant axis
  /// 3. **Ambiguous movements**: Default to vertical (up/down) direction
  /// 
  /// ## Keyboard Commands:
  /// - **Left**: `Ctrl+Left Arrow` (previous virtual desktop)
  /// - **Right**: `Ctrl+Right Arrow` (next virtual desktop)
  /// - **Up**: `Mission Control` (Spaces overview)
  /// - **Down**: `Ctrl+Down Arrow` (Show windows for current application on the current desktop)
  private static func executeGestureAction(deltaX: Int64, deltaY: Int64) {
    // If we haven't reached the direction threshold, prefer X
    if abs(deltaX) < directionThreshold && abs(deltaY) < directionThreshold {
      if deltaX < 0 { // negative movements are to the left, positive to the right
        Logger.gesture("Small gesture detected: LEFT (previous desktop)")
        keyPress(Keys.leftArrow.rawValue, false, true)
      } else {
        Logger.gesture("Small gesture detected: RIGHT (next desktop)")
        keyPress(Keys.rightArrow.rawValue, false, true)
      }
      return
    }
    
    // Otherwise, we need to decide if this is an X or a Y motion
    if (abs(deltaX) - abs(deltaY)) > directionThreshold {
      // Probably an X movement
      if deltaX < 0 { // negative movements are to the left, positive to the right
        Logger.gesture("Directional gesture detected: LEFT (previous desktop)")
        keyPress(Keys.leftArrow.rawValue, false, true)
      } else {
        Logger.gesture("Directional gesture detected: RIGHT (next desktop)")
        keyPress(Keys.rightArrow.rawValue, false, true)
      }
      return
    }
    
    // Y movement
    if deltaY < 0 { // negative movements are up, positive down
      Logger.gesture("Vertical gesture detected: UP (Mission Control)")
      keyPress(Keys.missionControl.rawValue, false, false)
    } else {
      Logger.gesture("Vertical gesture detected: DOWN (Show windows for current application on the current desktop)")
      keyPress(Keys.downArrow.rawValue, false, true)
    }
  }
}

private typealias CGEventTap = CFMachPort
extension CGEventTap {

  fileprivate class func create(
    tap: CGEventTapLocation,
    callback: @escaping CGEventTapCallBack
  ) -> CGEventTap {

    /*
     leftMouseDown = 1
     leftMouseUp = 2
     rightMouseDown = 3
     rightMouseUp = 4
     mouseMoved = 5
     leftMouseDragged = 6
     rightMouseDragged = 7
     keyDown = 10
     keyUp = 11
     flagsChanged = 12
     scrollWheel = 22
     tabletPointer = 23
     tabletProximity = 24
     otherMouseDown = 25
     otherMouseUp = 26
     otherMouseDragged = 27
     */

    let mask: UInt32 = (1 << 25) | (1 << 26) | (1 << 27)

    guard let tap = CGEvent.tapCreate(
      tap: tap,
      place: .headInsertEventTap,
      options: .defaultTap,
      eventsOfInterest: CGEventMask(mask),
      callback: callback,
      userInfo: nil
    ) else {
      fatalError("Failed to create event tap. This may be due to insufficient permissions or system restrictions.")
    }
    return tap
  }

}

let tapCallback: CGEventTapCallBack = {
  proxy, type, event, refcon in
  guard let event = EventTap.handleEvent(proxy: proxy, type: type, event: event, refcon: refcon)
  else { return nil }
  return Unmanaged<CGEvent>.passRetained(event)
}

EventTap.create()
