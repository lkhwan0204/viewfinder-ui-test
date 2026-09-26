import MapKit

// Core의 순수 좌표 타입 ↔ MapKit 타입 변환

extension GeoPoint {
    init(_ coordinate: CLLocationCoordinate2D) {
        self.init(coordinate.latitude, coordinate.longitude)
    }

    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

extension GeoRegion {
    init(_ region: MKCoordinateRegion) {
        self.init(
            center: GeoPoint(region.center),
            latitudeDelta: region.span.latitudeDelta,
            longitudeDelta: region.span.longitudeDelta
        )
    }

    var mkRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: center.clCoordinate,
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
    }
}
