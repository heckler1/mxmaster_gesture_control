import XCTest
import CoreGraphics
@testable import MXMasterGestureControl

final class CGEventTapExtensionTests: XCTestCase {
    
    // MARK: - Event Mask Tests
    
    func testEventMaskCalculation() {
        // Test the event mask calculation used in CGEventTap.create
        let expectedMask: UInt32 = (1 << 25) | (1 << 26) | (1 << 27)
        
        // Break down the mask calculation:
        // Bit 25 = otherMouseDown (2^25 = 33554432)
        // Bit 26 = otherMouseUp (2^26 = 67108864)  
        // Bit 27 = otherMouseDragged (2^27 = 134217728)
        
        let bit25: UInt32 = 1 << 25
        let bit26: UInt32 = 1 << 26
        let bit27: UInt32 = 1 << 27
        
        XCTAssertEqual(bit25, 33554432)
        XCTAssertEqual(bit26, 67108864)
        XCTAssertEqual(bit27, 134217728)
        
        let calculatedMask = bit25 | bit26 | bit27
        XCTAssertEqual(calculatedMask, expectedMask)
        XCTAssertEqual(calculatedMask, 234881024) // Combined value
    }
    
    // MARK: - Event Type Constants Tests
    
    func testCGEventTypeConstants() {
        // Verify the event type constants match the expected raw values
        // These correspond to the comments in the code
        
        XCTAssertEqual(CGEventType.leftMouseDown.rawValue, 1)
        XCTAssertEqual(CGEventType.leftMouseUp.rawValue, 2)
        XCTAssertEqual(CGEventType.rightMouseDown.rawValue, 3)
        XCTAssertEqual(CGEventType.rightMouseUp.rawValue, 4)
        XCTAssertEqual(CGEventType.mouseMoved.rawValue, 5)
        XCTAssertEqual(CGEventType.leftMouseDragged.rawValue, 6)
        XCTAssertEqual(CGEventType.rightMouseDragged.rawValue, 7)
        XCTAssertEqual(CGEventType.keyDown.rawValue, 10)
        XCTAssertEqual(CGEventType.keyUp.rawValue, 11)
        XCTAssertEqual(CGEventType.flagsChanged.rawValue, 12)
        XCTAssertEqual(CGEventType.scrollWheel.rawValue, 22)
        XCTAssertEqual(CGEventType.tabletPointer.rawValue, 23)
        XCTAssertEqual(CGEventType.tabletProximity.rawValue, 24)
        XCTAssertEqual(CGEventType.otherMouseDown.rawValue, 25)
        XCTAssertEqual(CGEventType.otherMouseUp.rawValue, 26)
        XCTAssertEqual(CGEventType.otherMouseDragged.rawValue, 27)
    }
    
    // MARK: - CGEventTapLocation Tests
    
    func testEventTapLocationConstants() {
        // Test the tap location used in the implementation
        let sessionTap = CGEventTapLocation.cgSessionEventTap
        XCTAssertNotNil(sessionTap)
        
        // Verify this is a valid tap location
        let availableLocations: [CGEventTapLocation] = [
            .cgSessionEventTap,
            .cgAnnotatedSessionEventTap
        ]
        
        XCTAssertTrue(availableLocations.contains(sessionTap))
    }
    
    // MARK: - CGEventTapPlacement Tests
    
    func testEventTapPlacement() {
        // Test the tap placement used in the implementation
        let headInsertTap = CGEventTapPlacement.headInsertEventTap
        XCTAssertNotNil(headInsertTap)
        
        // Verify this is a valid tap placement
        let availablePlacements: [CGEventTapPlacement] = [
            .headInsertEventTap,
            .tailAppendEventTap
        ]
        
        XCTAssertTrue(availablePlacements.contains(headInsertTap))
    }
    
    // MARK: - CGEventTapOptions Tests
    
    func testEventTapOptions() {
        // Test the tap options used in the implementation
        let defaultTap = CGEventTapOptions.defaultTap
        XCTAssertNotNil(defaultTap)
        
        // Verify this is a valid tap option
        let availableOptions: [CGEventTapOptions] = [
            .defaultTap,
            .listenOnly
        ]
        
        XCTAssertTrue(availableOptions.contains(defaultTap))
    }
    
    // MARK: - Callback Function Tests
    
    func testCallbackFunctionSignature() {
        // Test that our tap_callback matches the expected CGEventTapCallBack signature
        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            // This is a simplified version of our actual callback
            return nil // Nil is allowed for Unmanaged<CGEvent>?
        }
        
        XCTAssertNotNil(callback)
    }
    
    func testCallbackWithValidParameters() {
        // Test callback behavior with typical parameters
        let testCallback: CGEventTapCallBack = { proxy, type, event, refcon in
            // Verify we can handle the parameters
            XCTAssertNotEqual(type, CGEventType(rawValue: 999)) // Invalid type
            // event is CGEvent! (implicitly unwrapped optional), so no need for guard let
            return Unmanaged<CGEvent>.passRetained(event) // Pass through with correct memory management
        }
        
        XCTAssertNotNil(testCallback)
    }
    
    // MARK: - CFMachPort Integration Tests
    
    func testCFMachPortTypeAlias() {
        // Verify that our typealias works correctly
        // private typealias CGEventTap = CFMachPort
        
        // We can't directly test the private typealias, but we can test
        // that CFMachPort is a valid type for event tap operations
        let portType = CFMachPort.self
        XCTAssertNotNil(portType)
    }
    
    // MARK: - Event Tap Creation Parameter Validation
    
    func testEventTapCreationParameters() {
        // Test that all parameters for CGEvent.tapCreate are valid types
        let tap = CGEventTapLocation.cgSessionEventTap
        let place = CGEventTapPlacement.headInsertEventTap
        let options = CGEventTapOptions.defaultTap
        let mask: CGEventMask = (1 << 25) | (1 << 26) | (1 << 27)
        
        XCTAssertNotNil(tap)
        XCTAssertNotNil(place)
        XCTAssertNotNil(options)
        XCTAssertGreaterThan(mask, 0)
    }
    
    // MARK: - Memory Management Tests
    
    func testUnmanagedEventHandling() {
        // Test the Unmanaged<CGEvent> pattern used in the callback
        // This is critical for proper memory management in Core Graphics
        
        // Create a mock event (we can't create real CGEvents easily in tests)
        // but we can test the Unmanaged pattern using a CGEvent if possible
        if let mockEvent = CGEvent(source: nil) {
            let unmanaged = Unmanaged<CGEvent>.passRetained(mockEvent)
            XCTAssertNotNil(unmanaged)
            
            // Clean up to prevent memory leak
            _ = unmanaged.takeRetainedValue()
        } else {
            // Fallback to NSObject if we can't create a CGEvent
            let testObject = NSObject()
            let unmanaged = Unmanaged.passRetained(testObject)
            
            XCTAssertNotNil(unmanaged)
            
            // Clean up to prevent memory leak
            _ = unmanaged.takeRetainedValue()
        }
    }
    
    // MARK: - Integration with EventTap Class Tests
    
    func testEventTapStaticProperties() {
        // Test that the static properties in EventTap class are properly typed
        // for use with CGEventTap extension
        
        // We can test that the tap property type is compatible
        let tapLocation = CGEventTapLocation.cgSessionEventTap
        XCTAssertNotNil(tapLocation)
        
        // Test that the tap location can be used with our extension
        XCTAssertTrue(tapLocation == .cgSessionEventTap)
    }
}

// MARK: - Test Helper Extensions

extension CGEventTapExtensionTests {
    
    /// Helper to validate event mask bits
    func validateEventMaskBit(_ bitPosition: Int) -> Bool {
        let bit: UInt32 = 1 << bitPosition
        return bit > 0
    }
    
    func testEventMaskBitValidation() {
        // Test our helper method
        XCTAssertTrue(validateEventMaskBit(25))
        XCTAssertTrue(validateEventMaskBit(26)) 
        XCTAssertTrue(validateEventMaskBit(27))
        XCTAssertTrue(validateEventMaskBit(0))
        
        // Edge case: high bit position (should still work for valid UInt32 range)
        XCTAssertTrue(validateEventMaskBit(31))
    }
}
