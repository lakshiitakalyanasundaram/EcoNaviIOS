//
//  OfflineMapRegionStorage.swift
//  econavi
//
//  Stores downloaded map region (center + span) per offline_map id in Application Support.
//

import Foundation
import MapKit
import CoreLocation

enum OfflineMapRegionStorage {

    private static let fileManager = FileManager.default
    private static let directoryName = "offline_map_regions"

    private static var directoryURL: URL? {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = appSupport.appendingPathComponent(directoryName, isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private static func fileURL(for mapId: UUID) -> URL? {
        directoryURL?.appendingPathComponent("\(mapId.uuidString).json")
    }

    struct RegionData: Codable {
        let latitude: Double
        let longitude: Double
        let latitudeDelta: Double
        let longitudeDelta: Double
    }

    static func save(region: MKCoordinateRegion, for mapId: UUID) {
        guard let url = fileURL(for: mapId) else { return }
        let data = RegionData(
            latitude: region.center.latitude,
            longitude: region.center.longitude,
            latitudeDelta: region.span.latitudeDelta,
            longitudeDelta: region.span.longitudeDelta
        )
        try? JSONEncoder().encode(data).write(to: url)
    }

    static func loadRegion(for mapId: UUID) -> MKCoordinateRegion? {
        guard let url = fileURL(for: mapId),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(RegionData.self, from: data) else { return nil }
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: decoded.latitude, longitude: decoded.longitude),
            span: MKCoordinateSpan(latitudeDelta: decoded.latitudeDelta, longitudeDelta: decoded.longitude)
        )
    }

    static func remove(for mapId: UUID) {
        guard let url = fileURL(for: mapId) else { return }
        try? fileManager.removeItem(at: url)
    }
}
