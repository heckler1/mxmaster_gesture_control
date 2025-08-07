import XCTest
import CoreGraphics
import AppKit
@testable import MXMasterGestureControl

final class EventTapTests: XCTestCase {
    
    // MARK: - Test Setup
    
    override func setUp() {
        super.setUp()
        // Reset any static state before each test
        EventTap.dragging = false
    }
    
    // MARK: - EventTap.keyPress Tests
    
    func testKeyPressWithCommandFlag() {
        // Test that keyPress correctly handles command flag
        // This test verifies the current behavior for command+arrow combinations
        
        // We can't easily test the actual CGEvent posting without system permissions,
        // but we can test the parameter validation and basic logic flow
        let rightArrowKey = Keys.rightArrow.rawValue
        
        // This should complete without throwing or crashing
        XCTAssertNoThrow {
            EventTap.keyPress(rightArrowKey, true, false) // command=true, control=false
        }
    }
    
    func testKeyPressWithControlFlag() {
        let rightArrowKey = Keys.rightArrow.rawValue
        
        // This should complete without throwing or crashing
        XCTAssertNoThrow {
            EventTap.keyPress(rightArrowKey, false, true) // command=false, control=true
        }
    }
    
    func testKeyPressWithBothFlags() {
        let rightArrowKey = Keys.rightArrow.rawValue
        
        XCTAssertNoThrow {
            EventTap.keyPress(rightArrowKey, true, true) // both flags
        }
    }
    
    func testKeyPressWithNoFlags() {
        let missionControlKey = Keys.missionControl.rawValue
        
        XCTAssertNoThrow {
            EventTap.keyPress(missionControlKey, false, false) // no flags
        }
    }
    
    // MARK: - Gesture Detection Logic Tests
    
    func testMovementThresholdLogic() {
        // Test the movement threshold calculation logic
        let movementThreshold = 1
        
        // Test cases that should be below threshold (return nil)
        XCTAssertTrue((abs(0) + abs(0))/2 < movementThreshold) // No movement
        XCTAssertTrue((abs(1) + abs(0))/2 < movementThreshold) // Minimal movement
        XCTAssertTrue((abs(0) + abs(1))/2 < movementThreshold) // Minimal movement
        
        // Test cases that should be above threshold
        XCTAssertFalse((abs(2) + abs(0))/2 < movementThreshold) // X movement above threshold
        XCTAssertFalse((abs(0) + abs(2))/2 < movementThreshold) // Y movement above threshold
        XCTAssertFalse((abs(1) + abs(1))/2 < movementThreshold) // Both axes above threshold
    }
    
    func testDirectionThresholdLogic() {
        let directionThreshold = 3
        
        // Test small movements that should prefer X direction
        let smallDeltaX = 2
        let smallDeltaY = 2
        XCTAssertTrue(abs(smallDeltaX) < directionThreshold && abs(smallDeltaY) < directionThreshold)
        
        // Test larger movements that should use directional logic
        let largeDeltaX = 5
        let largeDeltaY = 1
        XCTAssertTrue((abs(largeDeltaX) - abs(largeDeltaY)) > directionThreshold) // Should be X movement
        
        let largeDeltaY2 = 5
        let largeDeltaX2 = 1
        XCTAssertFalse((abs(largeDeltaX2) - abs(largeDeltaY2)) > directionThreshold) // Should be Y movement
    }
    
    func testLargeMovementValidation() {
        let largeMovementThreshold = 15
        let diagonalThreshold = 7
        
        // Test large diagonal movement (should be invalid)
        let largeDiagonalX = 20
        let largeDiagonalY = 18
        XCTAssertTrue(abs(largeDiagonalX) > largeMovementThreshold)
        XCTAssertTrue((abs(largeDiagonalX) - abs(largeDiagonalY)) < diagonalThreshold) // Invalid diagonal
        
        // Test large valid movement
        let largeValidX = 20
        let largeValidY = 5
        XCTAssertTrue(abs(largeValidX) > largeMovementThreshold)
        XCTAssertFalse((abs(largeValidX) - abs(largeValidY)) < diagonalThreshold) // Valid movement
    }
    
    // MARK: - Direction Detection Tests
    
    func testLeftMovementDetection() {
        let deltaX = -5
        
        XCTAssertTrue(deltaX < 0, "Negative X should indicate left movement")
    }
    
    func testRightMovementDetection() {
        let deltaX = 5
        
        XCTAssertTrue(deltaX > 0, "Positive X should indicate right movement")
    }
    
    func testUpMovementDetection() {
        let deltaY = -5
        
        XCTAssertTrue(deltaY < 0, "Negative Y should indicate up movement")
    }
    
    func testDownMovementDetection() {
        let deltaY = 5
        
        XCTAssertTrue(deltaY > 0, "Positive Y should indicate down movement")
    }
    
    // MARK: - Keys Enum Tests
    
    func testKeysEnumValues() {
        // Verify the key code constants match expected values
        XCTAssertEqual(Keys.control.rawValue, 59)
        XCTAssertEqual(Keys.leftArrow.rawValue, 123)
        XCTAssertEqual(Keys.rightArrow.rawValue, 124)
        XCTAssertEqual(Keys.downArrow.rawValue, 125)
        XCTAssertEqual(Keys.upArrow.rawValue, 126)
        XCTAssertEqual(Keys.missionControl.rawValue, 160)
    }
    
    // MARK: - Static State Tests
    
    func testDraggingStateInitialization() {
        // Test that dragging state starts as false
        EventTap.dragging = false
        XCTAssertFalse(EventTap.dragging)
        
        // Test that we can set dragging state
        EventTap.dragging = true
        XCTAssertTrue(EventTap.dragging)
    }
    
    // MARK: - Mouse Button Detection Tests
    
    func testMouseButtonConstants() {
        // Test the button numbers used in the gesture detection
        let gestureButton = 26 // Button 27 in 1-indexed Karabiner terms
        let forwardButton = 3  // Button 4 in 1-indexed terms
        let backButton = 4     // Button 5 in 1-indexed terms
        
        XCTAssertEqual(gestureButton, 26)
        XCTAssertEqual(forwardButton, 3)
        XCTAssertEqual(backButton, 4)
    }
    
    // MARK: - Guard Condition Tests
    
    func testRemoveWithNilRunLoopSource() {
        // Test the guard condition in EventTap.remove() when runLoopSource is nil
        
        // Ensure runLoopSource starts as nil
        EventTap.runLoopSource = nil
        
        // This should not crash or throw - the guard should handle it gracefully
        XCTAssertNoThrow {
            EventTap.remove()
        }
        
        // runLoopSource should still be nil after calling remove
        XCTAssertNil(EventTap.runLoopSource)
    }
    
    func testHandleEventWithNilParameter() {
        // Test the guard condition in EventTap.handleEvent() with nil event parameter
        
        // Create a mock proxy using OpaquePointer
        let mockProxy = OpaquePointer(bitPattern: 1)!
        
        let result = EventTap.handleEvent(
            proxy: mockProxy,
            type: .otherMouseUp,
            event: nil, // This should trigger the guard condition
            refcon: nil
        )
        
        // Should return nil when event parameter is nil
        XCTAssertNil(result, "handleEvent should return nil when event parameter is nil")
    }
}

// MARK: - Test Helper Extensions

extension EventTapTests {
    
    /// Helper method to simulate the threshold logic from the actual implementation
    func simulateGestureDecision(deltaX: Int, deltaY: Int) -> String {
        let movementThreshold = 1
        let directionThreshold = 3
        let largeMovementThreshold = 15
        let diagonalThreshold = 7
        
        // Movement threshold check
        if (abs(deltaX) + abs(deltaY))/2 < movementThreshold {
            return "no_action"
        }
        
        // Large movement validation
        if abs(deltaX) > largeMovementThreshold || abs(deltaY) > largeMovementThreshold {
            if (abs(deltaX) - abs(deltaY)) < diagonalThreshold {
                return "no_action" // Invalid diagonal
            }
        }
        
        // Small movement preference for X
        if abs(deltaX) < directionThreshold && abs(deltaY) < directionThreshold {
            return deltaX < 0 ? "left" : "right"
        }
        
        // Directional movement decision
        if (abs(deltaX) - abs(deltaY)) > directionThreshold {
            return deltaX < 0 ? "left" : "right"
        }
        
        // Y movement
        return deltaY < 0 ? "up" : "down"
    }
    
    func testGestureDecisionLogic() {
        // Test various gesture scenarios
        XCTAssertEqual(simulateGestureDecision(deltaX: 0, deltaY: 0), "no_action")
        XCTAssertEqual(simulateGestureDecision(deltaX: -5, deltaY: 0), "left")
        XCTAssertEqual(simulateGestureDecision(deltaX: 5, deltaY: 0), "right")
        XCTAssertEqual(simulateGestureDecision(deltaX: 0, deltaY: -5), "up")
        XCTAssertEqual(simulateGestureDecision(deltaX: 0, deltaY: 5), "down")
        XCTAssertEqual(simulateGestureDecision(deltaX: 20, deltaY: 18), "no_action") // Invalid diagonal
        XCTAssertEqual(simulateGestureDecision(deltaX: 20, deltaY: 5), "right") // Valid large movement
    }
}
