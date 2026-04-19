import MapKit

/// WMTS tile overlay for darkmap.cn light pollution data
/// Uses PostGIS:World_Atlas_2015 layer from lpm.darkmap.cn
final class WMTSLightPollutionTileOverlay: MKTileOverlay {

    private let baseURL = "https://lpm.darkmap.cn/gwc/service/wmts"
    private let layer = "PostGIS:World_Atlas_2015"
    private let tileMatrixSet = "EPSG:900913"

    init() {
        super.init(urlTemplate: nil)
        canReplaceMapContent = false
        minimumZ = 2
        maximumZ = 14
        tileSize = CGSize(width: 256, height: 256)
    }

    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        // WMTS format: SERVICE=WMTS&REQUEST=GetTile&VERSION=1.0.0&LAYER={layer}&STYLE=&TILEMATRIXSET={tileMatrixSet}&TILEMATRIX={tileMatrixSet}:{z}&TILEROW={y}&TILECOL={x}&FORMAT=image/png
        let urlString = "\(baseURL)?SERVICE=WMTS&REQUEST=GetTile&VERSION=1.0.0&LAYER=\(layer)&STYLE=&TILEMATRIXSET=\(tileMatrixSet)&TILEMATRIX=\(tileMatrixSet):\(path.z)&TILEROW=\(path.y)&TILECOL=\(path.x)&FORMAT=image/png"
        return URL(string: urlString)!
    }
}
