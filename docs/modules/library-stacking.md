# Library Stacking Module

The library stacking module allows users to select existing photos and combine them using the image stacking algorithm. It shares the stacking engine with the camera module.

## Files

```
Domains/Library/
├── Presentation/
│   ├── LibraryStackingView.swift
│   ├── LibraryStackingViewModel.swift
│   └── Components/
│       ├── PhotoGridView.swift
│       └── StackedResultCard.swift
├── Application/
│   ├── ImportPhotosUseCase.swift
│   └── ExportStackedImageUseCase.swift
├── Domain/
│   ├── ImportedImage.swift
│   └── PhotoLibraryRepository.swift
└── Infrastructure/
    └── PhotoKit/
        └── SystemPhotoLibraryRepository.swift
```

## LibraryStackingViewModel

```swift
@MainActor
class LibraryStackingViewModel: ObservableObject {
    @Published var selectedItems: [PhotosPickerItem] = []
    @Published var selectedImages: [ImportedImage] = []
    @Published var isStacking: Bool = false
    @Published var stackedImage: UIImage? = nil
}
```

### Operations

```swift
// Triggered by PhotosPickerItem changes
// Loads UIImage from each PhotosPickerItem
func loadImages() async

// Runs ImageStacker on selectedImages
func stackImages()

// Saves stackedImage to photo library
func saveStackedImage()
```

## LibraryStackingView

Three states the view can be in:

### 1. Empty State

When `selectedImages.isEmpty`:

```
        [📷]              ← large icon
   选择照片开始堆栈         ← single line, no description
```

### 2. Images Selected

When images are loaded, shows:

```
[📷 12]                [×]    ← count + clear button (icon, not "Clear" text)
┌──┬──┬──┬──┐
│  │  │  │  │
└──┴──┴──┴──┘          ← LazyVGrid, 100×100 thumbnails
[  开始堆栈  ]          ← bottom bar button
```

### 3. Stacking In Progress

```
        [⟳]              ← ProgressView
       处理中...          ← minimal text
```

### 4. Result Ready

```
[✨ 堆栈完成]             ← header with breathing glow icon
┌────────────────────┐
│                    │
│   stacked image    │  ← gradient border (cosmicBlue → nebulaPurple)
│                    │
└────────────────────┘
[       保存         ]  ← save button
```

## PhotosPicker Integration

Uses `PhotosPickerItem` binding for multi-selection:

```swift
PhotosPicker(
    selection: $viewModel.selectedItems,
    maxSelectionCount: 100,
    matching: .images
) {
    Image(systemName: "photo.badge.plus")
}
```

Loading images from `PhotosPickerItem`:

```swift
for item in selectedItems {
    if let data = try? await item.loadTransferable(type: Data.self),
       let image = UIImage(data: data) {
        selectedImages.append(image)
    }
}
```

## Data Flow

```
User taps [photo.badge.plus]
    → PhotosPicker sheet appears
    → User selects photos
    → selectedItems updates
    
selectedItems onChange
    → loadImages() runs
    → UIImages loaded async
    → selectedImages populates
    → LazyVGrid renders thumbnails

User taps [开始堆栈]
    → stackImages() called
    → isStacking = true
    → ImageStacker.stackImages() runs async
    → stackedImage set
    → isStacking = false
    → Result view appears

User taps [保存]
    → saveStackedImage()
    → UIImageWriteToSavedPhotosAlbum()
    → Photo saved to library
```

## Clear Behavior

Clear button removes all state:

```swift
withAnimation(AnimationPreset.smooth) {
    viewModel.selectedItems.removeAll()
    viewModel.selectedImages.removeAll()
    viewModel.stackedImage = nil
}
```

## Image Grid

```swift
LazyVGrid(
    columns: [GridItem(.adaptive(minimum: 100), spacing: Spacing.sm)],
    spacing: Spacing.sm
)
```

Each thumbnail:
- 100×100 fixed frame
- `.scaledToFill()` crop
- Continuous corners (CornerRadius.md)
- cosmicBlue border overlay

## Toolbar Structure

```swift
// Top trailing
PhotosPicker(...)           // always visible

// Bottom bar (conditional)
if !selectedImages.isEmpty && stackedImage == nil {
    Button("开始堆栈")       // only when images loaded and not yet stacked
}
```

## Navigation

- Title: "图库堆栈"
- `.ultraThinMaterial` navigation bar
- Dark color scheme

## Future Work

- Progress reporting per-image during loading
- Remove individual images from selection
- Alignment before stacking (important for handheld shots)
- Multiple stacking algorithm modes (median, sigma clipping)
- Comparison view (before/after)
- Export to Files app
- Batch processing multiple output images
