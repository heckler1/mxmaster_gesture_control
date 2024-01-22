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

//
// https://jjrscott.com/how-to-convert-ascii-character-to-cgkeycode/
//  CGKeyCodeInitializers.swift START
//
//  Created by John Scott on 09/02/2022.
//

extension CGKeyCode {
  public init?(character: String) {
    if let keyCode = Initializers.shared.characterKeys[character] {
      self = keyCode
    } else {
      return nil
    }
  }

  public init?(modifierFlag: NSEvent.ModifierFlags) {
    if let keyCode = Initializers.shared.modifierFlagKeys[modifierFlag] {
      self = keyCode
    } else {
      return nil
    }
  }

  public init?(specialKey: NSEvent.SpecialKey) {
    if let keyCode = Initializers.shared.specialKeys[specialKey] {
      self = keyCode
    } else {
      return nil
    }
  }

  private struct Initializers {
    let specialKeys: [NSEvent.SpecialKey: CGKeyCode]
    let characterKeys: [String: CGKeyCode]
    let modifierFlagKeys: [NSEvent.ModifierFlags: CGKeyCode]

    static let shared = Initializers()

    init() {
      var specialKeys = [NSEvent.SpecialKey: CGKeyCode]()
      var characterKeys = [String: CGKeyCode]()
      var modifierFlagKeys = [NSEvent.ModifierFlags: CGKeyCode]()

      for keyCode in (0..<128).map({ CGKeyCode($0) }) {
        guard
          let cgevent = CGEvent(
            keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: true)
        else { continue }
        guard let nsevent = NSEvent(cgEvent: cgevent) else { continue }

        var hasHandledKeyCode = false
        if nsevent.type == .keyDown {
          if let specialKey = nsevent.specialKey {
            hasHandledKeyCode = true
            specialKeys[specialKey] = keyCode
          } else if let characters = nsevent.charactersIgnoringModifiers,
            !characters.isEmpty && characters != "\u{0010}"
          {
            hasHandledKeyCode = true
            characterKeys[characters] = keyCode
          }
        } else if nsevent.type == .flagsChanged,
          let modifierFlag = nsevent.modifierFlags.first(
            .capsLock, .shift, .control, .option, .command, .help, .function)
        {
          hasHandledKeyCode = true
          modifierFlagKeys[modifierFlag] = keyCode
        }
        if !hasHandledKeyCode {
          #if DEBUG
            print("Unhandled keycode \(keyCode): \(nsevent)")
          #endif
        }
      }
      self.specialKeys = specialKeys
      self.characterKeys = characterKeys
      self.modifierFlagKeys = modifierFlagKeys
    }
  }

}

extension NSEvent.ModifierFlags: Hashable {}

extension OptionSet {
  public func first(_ options: Self.Element...) -> Self.Element? {
    for option in options {
      if contains(option) {
        return option
      }
    }
    return nil
  }
}
//  CGKeyCodeInitializers.swift END


class EventTap {
  
  static var rloop_source: CFRunLoopSource! = nil
  // could use .cghidEventTap for accessing events entering the window server, instead of this tap that events enter a login server
  // https://developer.apple.com/documentation/coregraphics/cgeventtaplocation
  static var tap: CGEventTapLocation! = .cgSessionEventTap
  static var dragging: Bool = false
  
  class func create() {
    if rloop_source != nil { EventTap.remove() }

    let tap = CGEventTap.create(tap: self.tap, callback: tap_callback)

    rloop_source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, CFIndex(0))
    CFRunLoopAddSource(CFRunLoopGetCurrent(), rloop_source, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
    CFRunLoopRun()
  }

  class func remove() {
    if rloop_source != nil {
      CFRunLoopRemoveSource(CFRunLoopGetCurrent(), rloop_source, .commonModes)
      rloop_source = nil
    }
  }

  class func keyPress(_ key: CGKeyCode, _ command: Bool) {
    let source = CGEventSource(stateID: .privateState)

    if let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true) {
      if command {
        event.flags = CGEventFlags.maskCommand
      }

      event.post(tap: self.tap)
    }

    if let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false) {
      if command {
        event.flags = CGEventFlags.maskCommand
      }

      event.post(tap: self.tap)
    }
  }

  @objc class func handle_event(
    proxy: CGEventTapProxy, type: CGEventType, event immutable_event: CGEvent!,
    refcon: UnsafeMutableRawPointer?
  ) -> CGEvent? {

    guard let event = immutable_event else { return nil }

    switch type {
    case .otherMouseUp:
      // eventButtonNumber is 0-indexed, most other software displays it as 1-indexed though
      switch event.getIntegerValueField(.mouseEventButtonNumber) {
      case 26:
        // If the user was in the middle of a drag, now they've lifted the button and are done
        if self.dragging {
          self.dragging = false
          // eat the event if they were in the middle of a drag
          return nil
        }
        // otherwise they weren't dragging, let's open mission control
        let missionControl: UInt16 = 160
        self.keyPress(missionControl, false)
        return nil
      default:
        return event
      }
    case .otherMouseDragged:
      // eventButtonNumber is 0-indexed: this is button27 in Karabiner
      if event.getIntegerValueField(.mouseEventButtonNumber) == 26 {
        let delta_x = event.getIntegerValueField(.mouseEventDeltaX)
        // Very small movements are likely a button press with a slight shake of the mouse, do nothing
        if abs(delta_x) < 1 {
          return nil
        }
        // Ensure we set a successful drag, so that the button presses don't interfere with the gesturing
        self.dragging = true

        // These must be remapped in the system keyboard shortcut settings
        // Then Karabiner can be used to map the standard ctrl-arrow system shortcuts to f18/19
        guard let f18 = CGKeyCode(specialKey: .f18) else { fatalError() }
        guard let f19 = CGKeyCode(specialKey: .f19) else { fatalError() }

        let key: CGKeyCode = (delta_x > 0) ? f19 : ((delta_x < 0) ? f18 : f19)
        self.keyPress(key, false)
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

    let tap: CFMachPort! = CGEvent.tapCreate(
      tap: tap,
      place: .headInsertEventTap,
      options: .defaultTap,
      eventsOfInterest: CGEventMask(mask),
      callback: callback,
      userInfo: nil
    )
    assert(tap != nil, "Failed to create event tap")
    return tap
  }

}

let tap_callback: CGEventTapCallBack = {
  proxy, type, event, refcon in
  guard let event = EventTap.handle_event(proxy: proxy, type: type, event: event, refcon: refcon)
  else { return nil }
  return Unmanaged<CGEvent>.passRetained(event)
}

EventTap.create()
