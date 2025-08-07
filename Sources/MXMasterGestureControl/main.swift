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

enum Keys: CGKeyCode {
  // kVK_Control from Carbon 
  // https://github.com/phracker/MacOSX-SDKs/blob/master/MacOSX10.15.sdk/System/Library/Frameworks/Carbon.framework/Versions/A/Frameworks/HIToolbox.framework/Versions/A/Headers/Events.h#L275
  // See also: https://gist.github.com/chipjarred/cbb324c797aec865918a8045c4b51d14
  case control = 59 //0x3B
  case leftArrow = 123
  case rightArrow = 124
  case downArrow = 125
  case upArrow = 126
  case missionControl = 160
}

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

  static var runLoopSource: CFRunLoopSource? = nil
  static var tap: CGEventTapLocation = .cgSessionEventTap
  static var dragging: Bool = false

  class func create() {
    if runLoopSource != nil { EventTap.remove() }

    let tap = CGEventTap.create(tap: self.tap, callback: tapCallback)

    runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, CFIndex(0))
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
    CFRunLoopRun()
  }

  class func remove() {
    guard let source = runLoopSource else { return }
    CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
    runLoopSource = nil
  }

  class func keyPress(_ key: CGKeyCode, _ command: Bool, _ control: Bool) {
    let source = CGEventSource(stateID: .privateState)

    let arrow = (key == Keys.rightArrow.rawValue || key == Keys.leftArrow.rawValue || key == Keys.upArrow.rawValue || key == Keys.downArrow.rawValue)

    if control && arrow {
      // Specifically for use with arrow keys, the control key must be pressed "manually" like this,
      // and must also have the Control modifier flag
      // One or the other is not enough: adding the flag to the actual arrow events will not work
      if let event = CGEvent(keyboardEventSource: source, virtualKey: Keys.control.rawValue, keyDown: true) {
        event.flags = CGEventFlags.maskControl
        event.post(tap: self.tap)
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
    }

    if control && arrow {
        usleep(controlKeyReleaseDelay)
        if let event = CGEvent(keyboardEventSource: source, virtualKey: Keys.control.rawValue, keyDown: false) {
          event.flags = CGEventFlags.maskControl
          event.post(tap: self.tap)
        }
    }
  }

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
          self.dragging = false
          // eat the event if they were in the middle of a drag
          return nil
        }
        // otherwise they weren't dragging, let's open mission control
        self.keyPress(Keys.missionControl.rawValue, false, false)
        return nil
      default:
        return event
      }
    /*
    // We could set forward and back conversion here as well
    // These buttons should be converted to the proper keyboard shortcuts 
    // regardless of reversing the forward and back mapping, for proper interpretation by all apps
    // But, for now we just do all this in Karabiner. 
    // This could come in handy if we want to get fancy and try to find events from 
    // specific devices to move all reinterpretation out of Karabiner, but there's not much benefit to that
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
    */
    case .otherMouseDragged:
      // eventButtonNumber is 0-indexed: this is button27 in Karabiner
      if event.getIntegerValueField(.mouseEventButtonNumber) == gestureButtonNumber {
        let deltaX = event.getIntegerValueField(.mouseEventDeltaX)
        let deltaY = event.getIntegerValueField(.mouseEventDeltaY)

        // Use an average here to artificially increase the precision.
        // Because we only have an integer value, it's harder to accurately detect small movements
        // A movement threshold of 1 for each axis isn't sensitive enough to catch small but intentional flicks
        // A threshold of 0 has too many false positives that result in unintentional virtual desktop changes
        if (abs(deltaX) + abs(deltaY))/2 < Self.movementThreshold {
          return nil
        }

        // Ensure we set a successful drag, so that the button presses don't interfere with the gesturing
        self.dragging = true

        // If we have a large movement
        if abs(deltaX) > Self.largeMovementThreshold || abs(deltaY) > Self.largeMovementThreshold {
          // And the movement is sufficiently diagonal
          if (abs(deltaX) - abs(deltaY)) < Self.diagonalThreshold {
            // Do nothing, this isn't a good signal
            return nil
          }
        }
        
        // If we haven't reached the direction threshold, prefer X
        if  abs(deltaX) < Self.directionThreshold && abs(deltaY) < Self.directionThreshold {
          if deltaX < 0 { // negative movements are to the left, positive to the right
            self.keyPress(Keys.leftArrow.rawValue, false, true)
            return nil
          }
          self.keyPress(Keys.rightArrow.rawValue, false, true)
          return nil
        }
        
        // Otherwise, we need to decide if this is an X or a Y motion
        if ((abs(deltaX) - abs(deltaY)) > Self.directionThreshold) {
          // Probably an X movement
          if deltaX < 0 { // negative movements are to the left, positive to the right
            self.keyPress(Keys.leftArrow.rawValue, false, true)
            return nil
          }
          self.keyPress(Keys.rightArrow.rawValue, false, true)
          return nil
        }
            
        if deltaY < 0 { // negative movements are up, positive down
          self.keyPress(Keys.missionControl.rawValue, false, false)
          return nil
        }
        self.keyPress(Keys.downArrow.rawValue, false, true)
        return nil
      }
      return event

    default:
      return event

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
