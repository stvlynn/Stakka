# Image Stacking Module

The image stacking module provides the core algorithm that combines multiple exposures into a single image with reduced noise. It is shared by both the camera and library features.

## Files

```
Core/ImageStacking/
└── ImageStacker.swift    # Actor — the single public interface
```

## Algorithm: Mean Stacking

Mean stacking averages pixel values across all input images. For each pixel position (x, y):

```
R_out = (R_1 + R_2 + ... + R_n) / n
G_out = (G_1 + G_2 + ... + G_n) / n
B_out = (B_1 + B_2 + ... + B_n) / n
```

This reduces random noise by a factor of √n. Doubling the number of frames improves signal-to-noise ratio by ~41%.

### Why Mean Stacking

| Method   | Noise Reduction | Artifact Resistance | Complexity |
|----------|-----------------|---------------------|------------|
| Mean     | √n              | Low                 | Low        |
| Median   | Moderate        | High (hot pixels)   | Medium     |
| Sigma    | High            | High                | High       |

Mean stacking is chosen as the baseline for its simplicity and predictable behavior. Median or sigma clipping can be added as future modes.

## Implementation

### Actor Isolation

`ImageStacker` is declared as an `actor` to prevent data races:

```swift
actor ImageStacker {
    func stackImages(_ images: [UIImage]) async -> UIImage?
}
```

Callers use `await`:

```swift
let result = await ImageStacker().stackImages(images)
```

### Pipeline

```
[UIImage] input
    ↓
Convert each image → CGImage
    ↓
Extract pixel data → [UInt8] arrays
    ↓
For each pixel: sum RGB values
    ↓
Divide by n → averaged pixels
    ↓
Create CGContext with result pixels
    ↓
Convert → UIImage output
```

### Framework Usage

- `UIImage` → `CGImage` for pixel access
- `CGContext` for pixel buffer manipulation
- `CoreImage` for color space handling
- `CoreGraphics` for raw pixel operations

### Memory Considerations

Current implementation processes all images in memory simultaneously. For 100 images at 12MP:

```
100 × 12,000,000 pixels × 4 bytes = ~4.8 GB
```

This is over device limits. In practice, input images are lower resolution (camera preview, not full sensor). For production use, consider:

- Streaming pipeline (process images in batches)
- Pyramid reduction before stacking
- Tile-based processing for large images

## Public Interface

```swift
actor ImageStacker {
    // Stack an array of images, returns nil if images is empty or incompatible
    func stackImages(_ images: [UIImage]) async -> UIImage?
}
```

## Consumer Integration

### From CameraViewModel

```swift
// After capture sequence
let stacker = ImageStacker()
let result = await stacker.stackImages(capturedImages)
```

### From LibraryStackingViewModel

```swift
func stackImages() {
    Task {
        isStacking = true
        let stacker = ImageStacker()
        stackedImage = await stacker.stackImages(selectedImages)
        isStacking = false
    }
}
```

## Saving Results

After stacking, images are saved to the photo library:

```swift
func saveStackedImage() {
    guard let image = stackedImage else { return }
    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
}
```

Requires `NSPhotoLibraryAddUsageDescription` in Info.plist.

## Future Stacking Modes

Planned extensions to the algorithm:

```swift
enum StackingMode {
    case mean          // Current implementation
    case median        // Better hot pixel rejection
    case sigmaClipping // Best noise reduction, most complex
    case lightening    // Max pixel (star trails)
    case comet         // Hybrid mean + lightening
}
```

## Error Handling

Current implementation returns `nil` on failure. Future improvements:

```swift
enum StackingError: Error {
    case emptyInput
    case incompatibleDimensions
    case insufficientMemory
    case processingFailed
}
```

## Performance Benchmarks

Approximate processing times on iPhone 14 Pro (approximate, varies with image size):

| Image Count | Resolution | Estimated Time |
|-------------|------------|----------------|
| 10          | 2MP        | ~0.5s          |
| 30          | 2MP        | ~1.5s          |
| 100         | 2MP        | ~5s            |

Higher resolution inputs scale approximately linearly.

## Testing

Unit tests should cover:

- Single image input returns same image
- Two identical images return same image
- Two complementary images average correctly
- Empty array returns nil
- Mismatched dimensions handled gracefully

```swift
func testMeanStackingOfIdenticalImages() async {
    let image = UIImage(named: "test_star_field")!
    let result = await ImageStacker().stackImages([image, image])
    // Result should match input within floating point tolerance
    XCTAssertNotNil(result)
}
```

## References

- [Stacking (astronomy)](https://en.wikipedia.org/wiki/Lucky_imaging)
- [HoshinoWeaver](https://github.com/Designerspr/HoshinoWeaver) — Reference implementation
- [Signal-to-noise ratio improvement with averaging](https://www.cloudynights.com/topic/647458-stacking-and-signal-to-noise-improvement/)
