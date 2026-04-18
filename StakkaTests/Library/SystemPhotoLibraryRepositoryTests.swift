import XCTest
@testable import Stakka

final class SystemPhotoLibraryRepositoryTests: XCTestCase {
    func testLoadFramesFromFileURLsCreatesFileBackedFrames() async throws {
        let repository = SystemPhotoLibraryRepository()
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        let image = TestImageFactory.starField(stars: [CGPoint(x: 15, y: 19), CGPoint(x: 48, y: 52)])
        let fileURL = tempDirectory.appendingPathComponent("sample.png")
        try XCTUnwrap(image.pngData()).write(to: fileURL)

        let frames = await repository.loadFrames(from: [fileURL], kind: .light)

        XCTAssertEqual(frames.count, 1)
        XCTAssertEqual(frames.first?.name, "sample")
        XCTAssertEqual(frames.first?.kind, .light)
        XCTAssertEqual(frames.first?.source, .fileURL(fileURL))
    }
}
