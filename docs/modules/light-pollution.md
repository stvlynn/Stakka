# Light Pollution Module

The light pollution module helps users find dark sky observation sites. It combines MapKit with real WMTS light pollution tiles from darkmap.cn and provides detailed observation condition data aligned with the darkmap.cn reference.

## Files

```
Domains/DarkSky/
├── Presentation/
│   ├── DarkSkyMapView.swift            # Root view + inline search bar + search results
│   ├── DarkSkyViewModel.swift          # Map state, search completer, result resolution
│   └── Components/
│       ├── DarkSkyInfoCard.swift        # Bottom info card with 7 data fields
│       └── LightPollutionMapView.swift  # UIViewRepresentable wrapping MKMapView
├── Application/
│   ├── CenterOnUserLocationUseCase.swift
│   └── FetchPollutionAtLocationUseCase.swift
├── Domain/
│   ├── BortleLevel.swift               # 9-level enum + SQM, brightness, visibility, dark sky grade
│   ├── DarkSkyRepository.swift         # Protocol
│   └── LightPollution.swift            # Value object
└── Infrastructure/
    ├── Location/
    │   └── CoreLocationService.swift
    ├── Tiles/
    │   ├── WMTSLightPollutionTileOverlay.swift   # darkmap.cn WMTS tile source
    │   └── LocalLightPollutionTileOverlay.swift   # Offline fallback tile renderer
    └── Remote/
        ├── VIIRSDarkSkyRepository.swift   # Distance-based Bortle estimation
        └── MockDarkSkyRepository.swift    # Preview/test mock
```

## Components

### DarkSkyMapView

Root view. Full-screen MKMapView with a bottom search bar and info card overlay.

**Layout:**
```
NavigationStack
└── ZStack
    ├── LightPollutionMapView (UIViewRepresentable)   ← full screen, ignores safe area
    │   ├── WMTSLightPollutionTileOverlay             ← darkmap.cn tiles, aboveRoads level
    │   └── MKPointAnnotation (when selected)          ← blue sparkle pin
    └── VStack (bottom-aligned)
        ├── Search results list                        ← shown when focused + has results
        ├── Search bar                                 ← always visible, native material style
        └── DarkSkyInfoCard                            ← slides up on pin selection
```

### LightPollutionMapView (UIViewRepresentable)

Wraps `MKMapView` directly instead of using SwiftUI Map. This enables:
- WMTS tile overlay from darkmap.cn at `.aboveRoads` level
- Tap gesture → coordinate → pin placement via `MKPointAnnotation`
- Custom pin annotation: `MKMarkerAnnotationView` with blue tint + sparkle glyph

### DarkSkyInfoCard

The info card displays 7 fields aligned with darkmap.cn's popup content:

```
┌────────────────────────────────────────┐
│  [✨]  光污染等级       Bortle 3  [●]  │  ← title + bortle number + color dot
│  ──────────────────────────────────── │
│  [↑] 39.9042°  [⟲] 116.4074°  🌙 乡村暗空 │  ← coords + bortle description
│  ──────────────────────────────────── │
│  SQM 数值              21.79 mag/arcsec² │
│  暗夜等级              二级              │
│  地面亮度              0.11 mcd/m²       │
│  ──────────────────────────────────── │
│  银河可见度            清晰可见           │
│  M31/M33              M31 肉眼可见       │
│  黄道光                可见              │
└────────────────────────────────────────┘
```

The four sections are: header, coordinates + Bortle description, metrics (SQM / dark sky grade / ground brightness), and visibility (Milky Way / M31+M33 / zodiacal light).

When search results are visible, the info card hides to avoid overcrowding the bottom area.

### Search Bar

An always-visible native-style search bar above the info card. Implementation:

- `MKLocalSearchCompleter` provides real-time autocomplete as user types
- `SearchCompleterDelegate` (private NSObject in ViewModel) bridges delegate callbacks to `@Published searchResults`
- `MKLocalSearch` resolves a selected completion to a coordinate
- `@FocusState` in the view controls result list visibility
- `.ultraThinMaterial` background in `RoundedRectangle` for native frosted glass look

**Interaction flow:**
1. User taps search bar → keyboard appears, results show as user types
2. User taps a result → keyboard dismisses, map navigates (0.05° span), pin placed, reading fetched
3. User taps the map → keyboard dismisses, results hide, pin placed at tap location

## Map Configuration

The map uses `MKMapView` with WMTS tiles from darkmap.cn overlaid above roads:

```
https://lpm.darkmap.cn/gwc/service/wmts?SERVICE=WMTS&REQUEST=GetTile
  &VERSION=1.0.0&LAYER=PostGIS:World_Atlas_2015&STYLE=
  &TILEMATRIXSET=EPSG:900913&TILEMATRIX=EPSG:900913:{z}
  &TILEROW={y}&TILECOL={x}&FORMAT=image/png
```

Tile configuration: zoom 2–14, 256×256 tiles, `canReplaceMapContent = false`.

A `LocalLightPollutionTileOverlay` exists as an offline fallback that renders heatmap tiles from distance-to-city heuristics with bilinear upscaling.

## Pollution Level System

### Bortle Scale (9 levels)

| Level | EN                  | ZH       | Color        | SQM (mag/arcsec²) | Brightness (mcd/m²) | Dark Sky Grade |
|-------|---------------------|----------|--------------|--------------------|-----------------------|----------------|
| 1     | Excellent Dark Sky  | 优秀暗空 | Green        | 22.00              | 0.01                  | 1              |
| 2     | Truly Dark Sky      | 极佳暗空 | Mint         | 21.93              | 0.04                  | 1              |
| 3     | Rural Dark Sky      | 乡村暗空 | Yellow       | 21.79              | 0.11                  | 2              |
| 4     | Rural Transition    | 城郊过渡 | Orange       | 21.09              | 0.33                  | 3              |
| 5     | Suburban Sky        | 城郊天空 | Orange       | 20.00              | 1.00                  | 3              |
| 6     | Bright Suburban     | 明亮城郊 | Red (0.8)    | 19.22              | 3.00                  | 4              |
| 7     | Suburban Edge       | 近城区   | Red          | 18.66              | 10.0                  | 4              |
| 8     | City Sky            | 城市天空 | Red (0.9)    | 18.19              | 30.0                  | 5              |
| 9     | Inner City          | 市中心   | Pink         | 17.50              | 100.0                 | 5              |

### Visibility Descriptions

Derived from Bortle level as computed properties on `BortleLevel`:

**Milky Way (`milkyWayVisibility`):**
- Bortle 1–2: 极其壮观，结构清晰
- Bortle 3: 清晰可见
- Bortle 4: 部分可见
- Bortle 5–6: 仅银心可见
- Bortle 7–9: 肉眼不可见

**M31/M33 Galaxy (`galaxyVisibility`):**
- Bortle 1: M31、M33 肉眼可见
- Bortle 2–3: M31 肉眼可见
- Bortle 4: 勉强可辨
- Bortle 5–9: 肉眼不可见

**Zodiacal Light (`zodiacalLightVisibility`):**
- Bortle 1: 极其清晰
- Bortle 2: 清晰可见
- Bortle 3: 可见
- Bortle 4–9: 肉眼不可见

### Chinese Dark Sky Grade (`darkSkyGrade`)

5-level classification mapping from Bortle:

| Grade | Bortle Levels |
|-------|---------------|
| 一级   | 1, 2          |
| 二级   | 3             |
| 三级   | 4, 5          |
| 四级   | 6, 7          |
| 五级   | 8, 9          |

## Localization Formatters

Two formatters in `L10nFormat` support the info card:

- `L10nFormat.sqm(_:)` → "21.79 mag/arcsec²"
- `L10nFormat.brightness(_:)` → "0.11 mcd/m²"

All labels and visibility descriptions are localized through `L10n.DarkSky.*` keys with both zh-Hans and en translations.

## Navigation

- Title: "光污染地图" / "Light Pollution Map"
- `.ultraThinMaterial` navigation bar with `.dark` color scheme
- Location button (top trailing) → recenters on device location
- Search bar (bottom, always visible) → MKLocalSearch place lookup

## Current State

The module supports:

1. Real WMTS light pollution tile overlay from darkmap.cn (World Atlas 2015 data)
2. Tap-to-pin with blue sparkle marker
3. Bortle level estimation from distance to major cities
4. Full info card with SQM, dark sky grade, ground brightness, and 3 visibility indicators
5. Place search via MKLocalSearchCompleter with autocomplete
6. Device location centering
7. Offline fallback tile rendering

## Data Flow

```
User taps map / selects search result
    ↓
DarkSkyMapView sets coordinate on ViewModel
    ↓
ViewModel.selectCoordinate()
    ├── sets selectedCoordinate (pin updates on map)
    └── FetchPollutionAtLocationUseCase
        └── VIIRSDarkSkyRepository
            ├── finds nearest major city
            └── maps distance → BortleLevel
                ↓
        LightPollution (coordinate, pollutionLevel, bortleLevel, timestamp)
            ↓
    currentReading published → DarkSkyInfoCard renders
```

## Still Missing

1. Per-pixel light pollution data from the WMTS tile itself (current reading is distance-based, not pixel-sampled)
2. Reverse geocoding for the selected pin
3. Offline caching of tile data
4. Favorite locations persistence
5. Weather/cloud cover overlay
6. Bortle scale legend on map
