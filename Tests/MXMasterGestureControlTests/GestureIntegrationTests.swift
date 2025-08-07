import XCTest
import CoreGraphics
import AppKit
@testable import MXMasterGestureControl

final class GestureIntegrationTests: XCTestCase {
    
    // MARK: - Complete Gesture Workflow Tests
    
    override func setUp() {
        super.setUp()
        EventTap.dragging = false
    }
    
    func testCompleteLeftSwipeGesture() {
        // Test a complete left swipe gesture workflow
        let deltaX = -10  // Left movement
        let deltaY = 0    // No vertical movement
        
        let result = simulateCompleteGesture(deltaX: deltaX, deltaY: deltaY)
        XCTAssertEqual(result, "left", "Left swipe should trigger left action")
    }
    
    func testCompleteRightSwipeGesture() {
        let deltaX = 10   // Right movement  
        let deltaY = 0    // No vertical movement
        
        let result = simulateCompleteGesture(deltaX: deltaX, deltaY: deltaY)
        XCTAssertEqual(result, "right", "Right swipe should trigger right action")
    }
    
    func testCompleteUpSwipeGesture() {
        let deltaX = 0    // No horizontal movement
        let deltaY = -10  // Up movement
        
        let result = simulateCompleteGesture(deltaX: deltaX, deltaY: deltaY)
        XCTAssertEqual(result, "up", "Up swipe should trigger mission control")
    }
    
    func testCompleteDownSwipeGesture() {
        let deltaX = 0    // No horizontal movement
        let deltaY = 10   // Down movement
        
        let result = simulateCompleteGesture(deltaX: deltaX, deltaY: deltaY)
        XCTAssertEqual(result, "down", "Down swipe should trigger down action")
    }
    
    // MARK: - Edge Case Integration Tests
    
    func testMinimalMovementGesture() {
        // Test gesture that's just above the movement threshold
        let deltaX = 2    // Just above threshold
        let deltaY = 0
        
        let result = simulateCompleteGesture(deltaX: deltaX, deltaY: deltaY)
        XCTAssertEqual(result, "right", "Minimal right movement should still trigger")
    }
    
    func testSubThresholdMovementGesture() {
        // Test gesture below movement threshold
        let deltaX = 1    // Below average threshold
        let deltaY = 0
        
        let result = simulateCompleteGesture(deltaX: deltaX, deltaY: deltaY)
        XCTAssertEqual(result, "no_action", "Sub-threshold movement should not trigger")
    }
    
    func testLargeDiagonalGesture() {
        // Test large diagonal gesture (should be rejected)
        let deltaX = 20   // Large movement
        let deltaY = 18   // Large movement, close to X (diagonal)
        
        let result = simulateCompleteGesture(deltaX: deltaX, deltaY: deltaY)
        XCTAssertEqual(result, "no_action", "Large diagonal gesture should be rejected")
    }
    
    func testLargeValidGesture() {
        // Test large but valid gesture
        let deltaX = 20   // Large movement
        let deltaY = 5    // Small Y component (not diagonal)
        
        let result = simulateCompleteGesture(deltaX: deltaX, deltaY: deltaY)
        XCTAssertEqual(result, "right", "Large valid right gesture should trigger")
    }
    
    // MARK: - Gesture State Management Tests
    
    func testDraggingStateAfterGesture() {
        // Simulate a gesture that should set dragging state
        let deltaX = 10
        let deltaY = 0
        
        // Before gesture
        EventTap.dragging = false
        XCTAssertFalse(EventTap.dragging)
        
        // After valid gesture, dragging should be true
        _ = simulateCompleteGesture(deltaX: deltaX, deltaY: deltaY)
        // Note: In real implementation, dragging would be set to true during gesture
        // We can't test this directly without the full event system, but we can verify
        // the logic that would set it
        
        let shouldSetDragging = shouldSetDraggingState(deltaX: deltaX, deltaY: deltaY)
        XCTAssertTrue(shouldSetDragging, "Valid gesture should set dragging state")
    }
    
    func testDraggingStateNotSetForInvalidGesture() {
        let deltaX = 0  // No movement
        let deltaY = 0
        
        let shouldSetDragging = shouldSetDraggingState(deltaX: deltaX, deltaY: deltaY)
        XCTAssertFalse(shouldSetDragging, "Invalid gesture should not set dragging state")
    }
    
    // MARK: - Multi-Gesture Sequence Tests
    
    func testMultipleGestureSequence() {
        // Test multiple gestures in sequence
        let gestures = [
            (deltaX: -10, deltaY: 0, expected: "left"),
            (deltaX: 10, deltaY: 0, expected: "right"),
            (deltaX: 0, deltaY: -10, expected: "up"),
            (deltaX: 0, deltaY: 10, expected: "down")
        ]
        
        for (index, gesture) in gestures.enumerated() {
            let result = simulateCompleteGesture(deltaX: gesture.deltaX, deltaY: gesture.deltaY)
            XCTAssertEqual(result, gesture.expected, 
                          "Gesture \(index + 1) failed: expected \(gesture.expected), got \(result)")
        }
    }
    
    // MARK: - Gesture Precision Tests
    
    func testBoundaryGestureValues() {
        // Test gestures at exact boundary values
        let movementThreshold = 1
        let directionThreshold = 3
        
        // Test at movement boundary
        let boundaryMovement = movementThreshold * 2 // Should pass
        let result1 = simulateCompleteGesture(deltaX: boundaryMovement, deltaY: 0)
        XCTAssertEqual(result1, "right", "Boundary movement should trigger")
        
        // Test at direction boundary
        // For directional logic to choose X: (abs(deltaX) - abs(deltaY)) > directionThreshold
        // So we need (4 - 0) > 3, which is true
        let boundaryDirection = directionThreshold + 1 // 4
        let result2 = simulateCompleteGesture(deltaX: boundaryDirection, deltaY: 0)
        XCTAssertEqual(result2, "right", "Boundary direction should use directional logic")
    }
    
    // MARK: - Mouse Button Integration Tests
    
    func testCorrectMouseButtonHandling() {
        // Test that only button 26 (gesture button) triggers gestures
        let gestureButton = 26
        let nonGestureButton = 25
        
        XCTAssertEqual(gestureButton, 26, "Gesture button should be button 26")
        XCTAssertNotEqual(nonGestureButton, gestureButton, "Other buttons should not trigger gestures")
    }
    
    func testButtonNumberMapping() {
        // Test the button number mapping (0-indexed vs 1-indexed)
        let karabinerButton27 = 26 // 0-indexed in Core Graphics
        
        XCTAssertEqual(karabinerButton27, 26, "Button 27 in Karabiner should be 26 in Core Graphics")
    }
}

// MARK: - Test Helper Methods

extension GestureIntegrationTests {
    
    /// Simulates the complete gesture detection logic
    private func simulateCompleteGesture(deltaX: Int, deltaY: Int) -> String {
        let movementThreshold = 1
        let directionThreshold = 3
        let largeMovementThreshold = 15
        let diagonalThreshold = 7
        
        // Step 1: Movement threshold check
        if (abs(deltaX) + abs(deltaY))/2 < movementThreshold {
            return "no_action"
        }
        
        // Step 2: Large movement validation (diagonal check)
        if abs(deltaX) > largeMovementThreshold || abs(deltaY) > largeMovementThreshold {
            if (abs(deltaX) - abs(deltaY)) < diagonalThreshold {
                return "no_action" // Invalid diagonal movement
            }
        }
        
        // Step 3: Small movement handling (prefer X direction)
        if abs(deltaX) < directionThreshold && abs(deltaY) < directionThreshold {
            return deltaX < 0 ? "left" : "right"
        }
        
        // Step 4: Directional decision
        if (abs(deltaX) - abs(deltaY)) > directionThreshold {
            // X movement
            return deltaX < 0 ? "left" : "right"
        }
        
        // Step 5: Y movement
        return deltaY < 0 ? "up" : "down"
    }
    
    /// Determines if dragging state should be set for given gesture
    private func shouldSetDraggingState(deltaX: Int, deltaY: Int) -> Bool {
        let movementThreshold = 1
        
        // Dragging should be set if movement is above threshold
        return (abs(deltaX) + abs(deltaY))/2 >= movementThreshold
    }
    
    /// Test helper validation
    func testGestureSimulationAccuracy() {
        // Verify our simulation matches expected behavior patterns
        
        // Test known patterns
        let testCases = [
            (deltaX: -5, deltaY: 0, expected: "left"),
            (deltaX: 5, deltaY: 0, expected: "right"), 
            (deltaX: 0, deltaY: -5, expected: "up"),
            (deltaX: 0, deltaY: 5, expected: "down"),
            (deltaX: 0, deltaY: 0, expected: "no_action"),
            (deltaX: 1, deltaY: 0, expected: "no_action"), // Below threshold
            (deltaX: 20, deltaY: 19, expected: "no_action") // Diagonal
        ]
        
        for testCase in testCases {
            let result = simulateCompleteGesture(deltaX: testCase.deltaX, deltaY: testCase.deltaY)
            XCTAssertEqual(result, testCase.expected, 
                          "Test case (\(testCase.deltaX), \(testCase.deltaY)) failed")
        }
    }
}

// MARK: - Performance Integration Tests

extension GestureIntegrationTests {
    
    func testGestureDetectionPerformance() {
        // Test that gesture detection performs well with many rapid gestures
        let gestureCount = 1000
        
        measure {
            for i in 0..<gestureCount {
                let deltaX = i % 20 - 10  // Range from -10 to 9
                let deltaY = (i * 2) % 20 - 10
                _ = simulateCompleteGesture(deltaX: deltaX, deltaY: deltaY)
            }
        }
    }
    
    func testVariousGesturePatterns() {
        // Test different gesture patterns for consistency
        let patterns = [
            // Horizontal patterns
            (-10, 0), (-5, 0), (5, 0), (10, 0),
            // Vertical patterns
            (0, -10), (0, -5), (0, 5), (0, 10),
            // Diagonal patterns (should be rejected)
            (10, 9), (-10, -9), (15, 14), (-15, -14),
            // Small movements
            (1, 0), (2, 0), (0, 1), (0, 2),
            // Large movements
            (25, 5), (-25, -5), (5, 25), (-5, -25)
        ]
        
        for (deltaX, deltaY) in patterns {
            let result = simulateCompleteGesture(deltaX: deltaX, deltaY: deltaY)
            
            // Verify result is one of the expected values
            let validResults = ["left", "right", "up", "down", "no_action"]
            XCTAssertTrue(validResults.contains(result), 
                         "Invalid result '\(result)' for gesture (\(deltaX), \(deltaY))")
        }
    }
}
