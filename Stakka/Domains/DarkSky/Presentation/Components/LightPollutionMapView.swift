import MapKit
import SwiftUI
import UIKit

struct LightPollutionMapView: UIViewRepresentable {
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    var cameraRegion: MKCoordinateRegion?
    var onTap: ((CLLocationCoordinate2D) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .flat)
        mapView.overrideUserInterfaceStyle = .dark
        mapView.showsUserLocation = true

        let tileOverlay = WMTSLightPollutionTileOverlay()
        mapView.addOverlay(tileOverlay, level: .aboveRoads)

        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        mapView.addGestureRecognizer(tapGesture)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        if let region = cameraRegion {
            mapView.setRegion(region, animated: true)
        }

        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })

        if let coordinate = selectedCoordinate {
            let pin = MKPointAnnotation()
            pin.coordinate = coordinate
            pin.title = "暗空点"
            mapView.addAnnotation(pin)
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: LightPollutionMapView

        init(_ parent: LightPollutionMapView) {
            self.parent = parent
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            parent.onTap?(coordinate)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tileOverlay)
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }

            let id = "DarkSkyPin"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)

            view.markerTintColor = UIColor(red: 0.23, green: 0.51, blue: 0.96, alpha: 1)
            view.glyphImage = UIImage(systemName: "sparkle")
            return view
        }
    }
}
