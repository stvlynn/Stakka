import MapKit
import UIKit

final class LocalLightPollutionTileOverlay: MKTileOverlay {

    // (lat, lon) pairs of major cities worldwide
    private static let cities: [(Double, Double)] = [
        (39.9042, 116.4074), (31.2304, 121.4737), (23.1291, 113.2644),
        (22.5431, 114.0579), (30.5728, 104.0668), (34.3416, 108.9398),
        (29.5630, 106.5516), (38.0428, 114.5149), (36.6512, 117.1201),
        (32.0603, 118.7969), (30.2936, 120.1614), (26.0745, 119.2965),
        (28.2282, 112.9388), (30.5928, 114.3055), (22.8170, 108.3665),
        (25.0408, 102.7123), (36.0671, 103.8343), (43.8256,  87.6168),
        (29.8683, 121.5440), (24.4798, 118.0894),
        (35.6762, 139.6503), (37.5665, 126.9780), ( 1.3521, 103.8198),
        (40.7128, -74.0060), (34.0522,-118.2437), (51.5074,  -0.1278),
        (48.8566,   2.3522), (41.8781, -87.6298), (37.7749,-122.4194),
        (55.7558,  37.6173), (19.0760,  72.8777), (28.6139,  77.2090),
        (-23.5505, -46.6333),(  -33.8688, 151.2093),
    ]

    private let tileCache = NSCache<NSString, NSData>()
    private let renderQueue = DispatchQueue(label: "com.stakka.lightpollution.tiles",
                                            qos: .userInitiated,
                                            attributes: .concurrent)

    init() {
        super.init(urlTemplate: nil)
        canReplaceMapContent = false
        minimumZ = 2
        maximumZ = 14
        tileSize = CGSize(width: 256, height: 256)
        tileCache.countLimit = 512
    }

    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        let key = "\(path.z)/\(path.x)/\(path.y)" as NSString
        if let cached = tileCache.object(forKey: key) {
            result(cached as Data, nil)
            return
        }
        renderQueue.async { [weak self] in
            guard let self else { result(nil, nil); return }
            let data = self.renderTile(z: path.z, x: path.x, y: path.y)
            if let data {
                self.tileCache.setObject(data as NSData, forKey: key)
            }
            result(data, nil)
        }
    }

    // MARK: - Tile rendering

    private func renderTile(z: Int, x: Int, y: Int) -> Data? {
        let res = 64  // sample resolution; upscaled to 256×256
        let n = pow(2.0, Double(z))
        let cities = Self.cities

        var pixels = [UInt32](repeating: 0, count: res * res)

        for py in 0..<res {
            let fracY = (Double(py) + 0.5) / Double(res)
            let tileY = Double(y) + fracY
            let latRad = atan(sinh(.pi * (1.0 - 2.0 * tileY / n)))
            let lat = latRad * 180.0 / .pi
            let cosLat = cos(latRad)

            for px in 0..<res {
                let fracX = (Double(px) + 0.5) / Double(res)
                let lon = (Double(x) + fracX) / n * 360.0 - 180.0

                var minDist = Double.infinity
                for (cityLat, cityLon) in cities {
                    let dx = (lon - cityLon) * cosLat * 111_320
                    let dy = (lat - cityLat) * 111_000
                    let d = (dx*dx + dy*dy).squareRoot()
                    if d < minDist { minDist = d }
                }

                pixels[py * res + px] = pixelColor(forDistanceM: minDist)
            }
        }

        return makeImage(pixels: pixels, sampleRes: res, tileRes: 256)?.pngData()
    }

    // Returns ARGB packed UInt32
    private func pixelColor(forDistanceM d: Double) -> UInt32 {
        // Control points (distM, r, g, b, a×255)
        let stops: [(Double, Float, Float, Float, Float)] = [
            (        0, 1.00, 1.00, 0.90, 175),   // inner city  – white-pink
            (    5_000, 1.00, 0.10, 0.05, 155),   // city        – red
            (   15_000, 1.00, 0.42, 0.00, 135),   // urban edge  – orange
            (   30_000, 1.00, 0.80, 0.00, 115),   // suburban    – yellow
            (   60_000, 0.55, 0.95, 0.00, 95),    // rural trans – yellow-green
            (  100_000, 0.00, 0.82, 0.12, 72),    // rural dark  – green
            (  180_000, 0.00, 0.40, 0.90, 48),    // dark sky    – blue
            (  320_000, 0.00, 0.08, 0.55, 24),    // very dark   – deep blue
            (  500_000, 0.00, 0.00, 0.00, 0),     // excellent   – transparent
        ]

        let last = stops.last!
        if d >= last.0 { return 0 }

        for i in 1..<stops.count {
            let (d0, r0, g0, b0, a0) = stops[i-1]
            let (d1, r1, g1, b1, a1) = stops[i]
            if d <= d1 {
                let t = Float((d - d0) / (d1 - d0))
                let r = UInt32((r0 + t*(r1-r0)) * 255) & 0xFF
                let g = UInt32((g0 + t*(g1-g0)) * 255) & 0xFF
                let b = UInt32((b0 + t*(b1-b0)) * 255) & 0xFF
                let a = UInt32(a0 + t*(a1-a0)) & 0xFF
                return (a << 24) | (r << 16) | (g << 8) | b
            }
        }
        return 0
    }

    private func makeImage(pixels: [UInt32], sampleRes: Int, tileRes: Int) -> UIImage? {
        // Bilinear upscale from sampleRes to tileRes
        let scale = Float(tileRes) / Float(sampleRes)
        var output = [UInt8](repeating: 0, count: tileRes * tileRes * 4)

        for ty in 0..<tileRes {
            for tx in 0..<tileRes {
                let sx = (Float(tx) + 0.5) / scale - 0.5
                let sy = (Float(ty) + 0.5) / scale - 0.5
                let sx0 = max(0, Int(sx)); let sx1 = min(sampleRes-1, sx0+1)
                let sy0 = max(0, Int(sy)); let sy1 = min(sampleRes-1, sy0+1)
                let fx = sx - Float(sx0); let fy = sy - Float(sy0)

                let c00 = pixels[sy0*sampleRes+sx0]; let c10 = pixels[sy0*sampleRes+sx1]
                let c01 = pixels[sy1*sampleRes+sx0]; let c11 = pixels[sy1*sampleRes+sx1]

                let r = bilinear(c00>>16, c10>>16, c01>>16, c11>>16, fx, fy)
                let g = bilinear((c00>>8)&0xFF, (c10>>8)&0xFF, (c01>>8)&0xFF, (c11>>8)&0xFF, fx, fy)
                let b = bilinear(c00&0xFF, c10&0xFF, c01&0xFF, c11&0xFF, fx, fy)
                let a = bilinear(c00>>24, c10>>24, c01>>24, c11>>24, fx, fy)

                let base = (ty*tileRes+tx)*4
                output[base] = r; output[base+1] = g; output[base+2] = b; output[base+3] = a
            }
        }

        guard let provider = CGDataProvider(data: Data(output) as CFData),
              let cg = CGImage(
                width: tileRes, height: tileRes,
                bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: tileRes*4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        else { return nil }

        return UIImage(cgImage: cg)
    }

    private func bilinear(_ v00: UInt32, _ v10: UInt32, _ v01: UInt32, _ v11: UInt32,
                          _ fx: Float, _ fy: Float) -> UInt8 {
        let top = Float(v00)*(1-fx) + Float(v10)*fx
        let bot = Float(v01)*(1-fx) + Float(v11)*fx
        return UInt8(min(255, max(0, top*(1-fy) + bot*fy)))
    }
}
