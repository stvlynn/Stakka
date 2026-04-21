import CoreGraphics
import XCTest
@testable import Stakka

/// Tests ported from `DeepSkyStackerTest/DssRectTest.cpp`
/// (https://github.com/deepskystacker/DSS/blob/master/DeepSkyStackerTest/DssRectTest.cpp).
///
/// DSS introduced its own `DSSRect` (Qt-based) to standardise the
/// "left-inclusive / right-exclusive, top-inclusive / bottom-exclusive"
/// rectangle semantics.  Stakka does not have a bespoke rectangle type —
/// it relies on Swift's `CGRect` plus the value-type `PixelPoint` /
/// `PixelSize` from `StackingTypes.swift`.
///
/// These tests pin the same behavioural contract so that future
/// refactors (e.g. adopting an integer pixel rectangle) cannot regress
/// the half-open-interval semantics that the stacking pipeline depends
/// on.
final class DSSRectParityTests: XCTestCase {

    private let leftEdge: CGFloat = 1
    private let topEdge: CGFloat = 2
    private let rightEdge: CGFloat = 7
    private let bottomEdge: CGFloat = 10

    private var rect: CGRect {
        CGRect(
            x: leftEdge,
            y: topEdge,
            width: rightEdge - leftEdge,
            height: bottomEdge - topEdge
        )
    }

    // MARK: - DSS: "Width and height return correct values"

    func testWidthAndHeightMatchDssRectArithmetic() {
        XCTAssertEqual(rect.width, rightEdge - leftEdge)
        XCTAssertEqual(rect.height, bottomEdge - topEdge)
    }

    // MARK: - DSS: "contains() returns true for a pixel in the middle"

    func testContainsCentrePixel() {
        let pixel = CGPoint(x: (rightEdge + leftEdge) / 2,
                            y: (bottomEdge + topEdge) / 2)
        XCTAssertTrue(rect.contains(pixel))
    }

    // MARK: - DSS: "contains() returns true for a pixel in the last row and column"

    func testContainsLastInteriorPixel() {
        let pixel = CGPoint(x: rightEdge - 1, y: bottomEdge - 1)
        XCTAssertTrue(rect.contains(pixel))
    }

    // MARK: - DSS: "contains() returns false for a pixel in the rightEdge column"

    func testRejectsPixelOnRightEdgeColumn() {
        let pixel = CGPoint(x: rightEdge, y: bottomEdge - 1)
        XCTAssertFalse(rect.contains(pixel),
                       "Half-open interval: x == rightEdge must be outside the rectangle.")
    }

    // MARK: - DSS: "contains() returns false for a point in the rightEdge column"

    func testRejectsPointOnRightEdgeColumn() {
        let point = CGPoint(x: rightEdge, y: bottomEdge)
        XCTAssertFalse(rect.contains(point))
    }

    // MARK: - DSS: "contains() returns false just outside the rightEdge column"

    func testRejectsPointJustOutsideRightEdge() {
        let offset: CGFloat = 1e-10
        let point = CGPoint(x: rightEdge + offset, y: bottomEdge)
        XCTAssertFalse(rect.contains(point))
    }

    // MARK: - DSS: "DSSRect::contains and CPointExt::IsInRect identical (false)
    //              just outside the border"

    func testRejectsPointJustOutsideBottomEdge() {
        let offset: CGFloat = 1e-10
        let point = CGPoint(x: rightEdge, y: bottomEdge + offset)
        XCTAssertFalse(rect.contains(point))
    }

    // MARK: - PixelPoint / PixelSize equivalence with DSSRect axes

    func testPixelPointAndPixelSizeMatchCGRectGeometry() {
        let origin = PixelPoint(x: Double(leftEdge), y: Double(topEdge))
        let size = PixelSize(
            width: Double(rightEdge - leftEdge),
            height: Double(bottomEdge - topEdge)
        )

        XCTAssertEqual(size.width, Double(rect.width))
        XCTAssertEqual(size.height, Double(rect.height))
        XCTAssertEqual(origin.x, Double(rect.minX))
        XCTAssertEqual(origin.y, Double(rect.minY))
    }
}
