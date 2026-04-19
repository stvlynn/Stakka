import Foundation
import UIKit

actor LocalStackProjectRepository: StackProjectRepository {
    nonisolated static let recentProjectDidChangeNotification = Notification.Name("LocalStackProjectRepository.recentProjectDidChange")

    private let fileManager: FileManager
    private let baseDirectoryURL: URL?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(baseDirectoryURL: URL? = nil) {
        self.fileManager = .default
        self.baseDirectoryURL = baseDirectoryURL
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func loadRecentProject() async throws -> StackingProject? {
        if let recentProjectID = try loadRecentProjectID() {
            return try await loadProject(id: recentProjectID)
        }

        if let legacyProject = try loadLegacyRecentProjectIfAvailable() {
            try await save(legacyProject)
            try removeLegacyStorageIfPresent()
            return legacyProject
        }

        return nil
    }

    func loadProject(id: UUID) async throws -> StackingProject? {
        guard let storedProject = try loadStoredProject(id: id) else {
            return nil
        }

        return try makeProject(from: storedProject, projectID: id)
    }

    func loadProjectSummaries() async throws -> [StackProjectSummary] {
        let projectDirectories = try projectDirectoryURLs()

        let summaries = try projectDirectories.compactMap { directoryURL -> StackProjectSummary? in
            let projectID = UUID(uuidString: directoryURL.lastPathComponent)
            guard let projectID,
                  let storedProject = try loadStoredProject(id: projectID) else {
                return nil
            }

            return StackProjectSummary(
                id: projectID,
                title: storedProject.title,
                updatedAt: storedProject.updatedAt,
                totalFrameCount: storedProject.frames.count,
                lightFrameCount: storedProject.frames.filter { $0.kind == .light && $0.isEnabled }.count,
                cometMode: storedProject.cometMode
            )
        }

        return summaries.sorted { lhs, rhs in
            lhs.updatedAt > rhs.updatedAt
        }
    }

    func save(_ project: StackingProject) async throws {
        try write(project, markAsRecent: true)
        notifyCatalogChange()
    }

    func duplicateProject(id: UUID) async throws -> StackingProject {
        guard let project = try await loadProject(id: id) else {
            throw AppError.operationFailed(L10n.Error.duplicateProjectMissing)
        }

        let duplicatedProject = duplicate(project)
        try write(duplicatedProject, markAsRecent: true)
        notifyCatalogChange()
        return duplicatedProject
    }

    func deleteProject(id: UUID) async throws {
        let directoryURL = try projectDirectoryURL(for: id, createIfNeeded: false)
        guard fileManager.fileExists(atPath: directoryURL.path()) else {
            return
        }

        try fileManager.removeItem(at: directoryURL)

        if try loadRecentProjectID() == id {
            let fallbackProjectID = try await loadProjectSummaries().first(where: { $0.id != id })?.id
            try writeRecentProjectID(fallbackProjectID)
        }

        notifyCatalogChange()
    }

    func markRecentProject(id: UUID) async throws {
        guard fileManager.fileExists(atPath: try projectDirectoryURL(for: id, createIfNeeded: false).path()) else {
            throw AppError.operationFailed(L10n.Error.switchProjectMissing)
        }

        try writeRecentProjectID(id)
        notifyCatalogChange()
    }

    func clearRecentProject() async throws {
        try writeRecentProjectID(nil)
        notifyCatalogChange()
    }
}

private extension LocalStackProjectRepository {
    struct StoredProject: Codable {
        let id: UUID
        let title: String
        let mode: StackingMode
        let cometMode: CometStackingMode?
        let referenceFrameID: UUID?
        let frames: [StoredFrame]
        let cometAnnotations: [UUID: CometAnnotation]
        let updatedAt: Date

        enum CodingKeys: String, CodingKey {
            case id
            case title
            case mode
            case cometMode
            case referenceFrameID
            case frames
            case cometAnnotations
            case updatedAt
        }

        init(
            id: UUID,
            title: String,
            mode: StackingMode,
            cometMode: CometStackingMode?,
            referenceFrameID: UUID?,
            frames: [StoredFrame],
            cometAnnotations: [UUID: CometAnnotation],
            updatedAt: Date
        ) {
            self.id = id
            self.title = title
            self.mode = mode
            self.cometMode = cometMode
            self.referenceFrameID = referenceFrameID
            self.frames = frames
            self.cometAnnotations = cometAnnotations
            self.updatedAt = updatedAt
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            title = try container.decode(String.self, forKey: .title)
            mode = try container.decode(StackingMode.self, forKey: .mode)
            cometMode = try container.decodeIfPresent(CometStackingMode.self, forKey: .cometMode)
            referenceFrameID = try container.decodeIfPresent(UUID.self, forKey: .referenceFrameID)
            frames = try container.decode([StoredFrame].self, forKey: .frames)
            cometAnnotations = try container.decodeIfPresent([UUID: CometAnnotation].self, forKey: .cometAnnotations) ?? [:]
            updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        }
    }

    struct StoredFrame: Codable {
        let id: UUID
        let kind: StackFrameKind
        let name: String
        let source: StoredFrameSource
        let imageFilename: String
        let isEnabled: Bool
        let analysis: FrameAnalysis?
        let registration: FrameRegistration?
    }

    enum StoredFrameSource: Codable {
        case photoLibrary(assetIdentifier: String?)
        case fileBookmark(Data)
        case capture(String)

        init(_ source: StackFrameSource) throws {
            switch source {
            case .photoLibrary(let assetIdentifier):
                self = .photoLibrary(assetIdentifier: assetIdentifier)
            case .fileURL(let url):
                self = .fileBookmark(try url.bookmarkData())
            case .capture(let identifier):
                self = .capture(identifier)
            }
        }

        func resolve() throws -> StackFrameSource {
            switch self {
            case .photoLibrary(let assetIdentifier):
                return .photoLibrary(assetIdentifier: assetIdentifier)
            case .fileBookmark(let bookmarkData):
                var isStale = false
                let url = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: [.withoutUI, .withoutMounting],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                return .fileURL(url)
            case .capture(let identifier):
                return .capture(identifier: identifier)
            }
        }

        enum CodingKeys: String, CodingKey {
            case kind
            case assetIdentifier
            case bookmarkData
        }

        enum Kind: String, Codable {
            case photoLibrary
            case fileBookmark
            case capture
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let kind = try container.decode(Kind.self, forKey: .kind)

            switch kind {
            case .photoLibrary:
                self = .photoLibrary(assetIdentifier: try container.decodeIfPresent(String.self, forKey: .assetIdentifier))
            case .fileBookmark:
                self = .fileBookmark(try container.decode(Data.self, forKey: .bookmarkData))
            case .capture:
                self = .capture(try container.decode(String.self, forKey: .assetIdentifier))
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case .photoLibrary(let assetIdentifier):
                try container.encode(Kind.photoLibrary, forKey: .kind)
                try container.encodeIfPresent(assetIdentifier, forKey: .assetIdentifier)
            case .fileBookmark(let bookmarkData):
                try container.encode(Kind.fileBookmark, forKey: .kind)
                try container.encode(bookmarkData, forKey: .bookmarkData)
            case .capture(let identifier):
                try container.encode(Kind.capture, forKey: .kind)
                try container.encode(identifier, forKey: .assetIdentifier)
            }
        }
    }

    func write(_ project: StackingProject, markAsRecent: Bool) throws {
        let directoryURL = try projectDirectoryURL(for: project.id, createIfNeeded: true)
        let framesURL = directoryURL.appendingPathComponent("Frames", isDirectory: true)
        try createDirectoryIfNeeded(at: framesURL)

        let storedFrames = try project.frames.map { frame in
            let imageFilename = "\(frame.id.uuidString).png"
            let imageURL = framesURL.appendingPathComponent(imageFilename)
            try writeImage(frame.image, to: imageURL)

            return try StoredFrame(
                id: frame.id,
                kind: frame.kind,
                name: frame.name,
                source: StoredFrameSource(frame.source),
                imageFilename: imageFilename,
                isEnabled: frame.isEnabled,
                analysis: frame.analysis,
                registration: frame.registration
            )
        }

        try removeOrphanedImages(in: framesURL, referencedFiles: Set(storedFrames.map(\.imageFilename)))

        let storedProject = StoredProject(
            id: project.id,
            title: project.title,
            mode: project.mode,
            cometMode: project.cometMode,
            referenceFrameID: project.referenceFrameID,
            frames: storedFrames,
            cometAnnotations: project.cometAnnotations,
            updatedAt: Date()
        )

        let projectData = try encoder.encode(storedProject)
        try projectData.write(to: projectFileURL(for: directoryURL), options: .atomic)

        if markAsRecent {
            try writeRecentProjectID(project.id)
        }
    }

    func loadStoredProject(id: UUID) throws -> StoredProject? {
        let directoryURL = try projectDirectoryURL(for: id, createIfNeeded: false)
        let projectURL = projectFileURL(for: directoryURL)
        guard fileManager.fileExists(atPath: projectURL.path()) else {
            return nil
        }

        let data = try Data(contentsOf: projectURL)
        return try decoder.decode(StoredProject.self, from: data)
    }

    func makeProject(from storedProject: StoredProject, projectID: UUID) throws -> StackingProject {
        let framesURL = try projectDirectoryURL(for: projectID, createIfNeeded: false).appendingPathComponent("Frames", isDirectory: true)

        let frames = try storedProject.frames.compactMap { storedFrame -> StackFrame? in
            let imageURL = framesURL.appendingPathComponent(storedFrame.imageFilename)
            guard let imageData = try? Data(contentsOf: imageURL),
                  let image = UIImage(data: imageData) else {
                return nil
            }

            return StackFrame(
                id: storedFrame.id,
                kind: storedFrame.kind,
                name: storedFrame.name,
                source: try storedFrame.source.resolve(),
                image: image,
                isEnabled: storedFrame.isEnabled,
                analysis: storedFrame.analysis,
                registration: storedFrame.registration
            )
        }

        return StackingProject(
            id: storedProject.id,
            title: storedProject.title,
            mode: storedProject.mode,
            cometMode: storedProject.cometMode,
            referenceFrameID: storedProject.referenceFrameID,
            frames: frames,
            cometAnnotations: storedProject.cometAnnotations
        )
    }

    func duplicate(_ project: StackingProject) -> StackingProject {
        let frameIDMap = Dictionary(uniqueKeysWithValues: project.frames.map { ($0.id, UUID()) })
        let duplicatedFrames = project.frames.map { frame in
            StackFrame(
                id: frameIDMap[frame.id] ?? UUID(),
                kind: frame.kind,
                name: frame.name,
                source: frame.source,
                image: frame.image,
                isEnabled: frame.isEnabled,
                analysis: frame.analysis,
                registration: frame.registration
            )
        }

        let duplicatedAnnotationPairs: [(UUID, CometAnnotation)] = project.cometAnnotations.compactMap { key, value in
            guard let duplicatedFrameID = frameIDMap[key] else { return nil }
            return (duplicatedFrameID, value)
        }
        let duplicatedAnnotations = Dictionary(uniqueKeysWithValues: duplicatedAnnotationPairs)

        let duplicateTitle = L10n.Project.duplicateTitle(from: project.title)
        return StackingProject(
            id: UUID(),
            title: duplicateTitle,
            mode: project.mode,
            cometMode: project.cometMode,
            referenceFrameID: project.referenceFrameID.flatMap { frameIDMap[$0] },
            frames: duplicatedFrames,
            cometAnnotations: duplicatedAnnotations
        )
    }

    func projectDirectoryURLs() throws -> [URL] {
        let projectsURL = try projectsRootURL(createIfNeeded: true)
        return try fileManager.contentsOfDirectory(
            at: projectsURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).filter { url in
            var isDirectory: ObjCBool = false
            return fileManager.fileExists(atPath: url.path(), isDirectory: &isDirectory) && isDirectory.boolValue
        }
    }

    func loadRecentProjectID() throws -> UUID? {
        let pointerURL = try recentProjectPointerURL()
        guard let pointerData = try? Data(contentsOf: pointerURL),
              let pointerString = String(data: pointerData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              let projectID = UUID(uuidString: pointerString) else {
            return nil
        }

        return projectID
    }

    func writeRecentProjectID(_ id: UUID?) throws {
        let pointerURL = try recentProjectPointerURL()

        if let id {
            try id.uuidString.data(using: .utf8)?.write(to: pointerURL, options: .atomic)
        } else if fileManager.fileExists(atPath: pointerURL.path()) {
            try fileManager.removeItem(at: pointerURL)
        }
    }

    func loadLegacyRecentProjectIfAvailable() throws -> StackingProject? {
        let legacyRootURL = try legacyProjectRootURL(createIfNeeded: false)
        let legacyProjectURL = legacyRootURL.appendingPathComponent("project.json")
        guard fileManager.fileExists(atPath: legacyProjectURL.path()) else {
            return nil
        }

        let data = try Data(contentsOf: legacyProjectURL)
        let storedProject = try decoder.decode(StoredProject.self, from: data)
        let framesURL = legacyRootURL.appendingPathComponent("Frames", isDirectory: true)

        let frames = try storedProject.frames.compactMap { storedFrame -> StackFrame? in
            let imageURL = framesURL.appendingPathComponent(storedFrame.imageFilename)
            guard let imageData = try? Data(contentsOf: imageURL),
                  let image = UIImage(data: imageData) else {
                return nil
            }

            return StackFrame(
                id: storedFrame.id,
                kind: storedFrame.kind,
                name: storedFrame.name,
                source: try storedFrame.source.resolve(),
                image: image,
                isEnabled: storedFrame.isEnabled,
                analysis: storedFrame.analysis,
                registration: storedFrame.registration
            )
        }

        return StackingProject(
            id: storedProject.id,
            title: storedProject.title,
            mode: storedProject.mode,
            cometMode: storedProject.cometMode,
            referenceFrameID: storedProject.referenceFrameID,
            frames: frames,
            cometAnnotations: storedProject.cometAnnotations
        )
    }

    func removeLegacyStorageIfPresent() throws {
        let legacyRootURL = try legacyProjectRootURL(createIfNeeded: false)
        guard fileManager.fileExists(atPath: legacyRootURL.path()) else { return }
        try fileManager.removeItem(at: legacyRootURL)
    }

    func writeImage(_ image: UIImage, to url: URL) throws {
        if let pngData = image.pngData() {
            try pngData.write(to: url, options: .atomic)
            return
        }

        guard let jpegData = image.jpegData(compressionQuality: 0.95) else {
            throw AppError.operationFailed(L10n.Error.frameCacheWriteFailed)
        }

        try jpegData.write(to: url, options: .atomic)
    }

    func removeOrphanedImages(in framesURL: URL, referencedFiles: Set<String>) throws {
        let existingFiles = try fileManager.contentsOfDirectory(
            at: framesURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        for fileURL in existingFiles where !referencedFiles.contains(fileURL.lastPathComponent) {
            try fileManager.removeItem(at: fileURL)
        }
    }

    func rootURL() throws -> URL {
        if let baseDirectoryURL {
            return baseDirectoryURL.appendingPathComponent("Stakka", isDirectory: true)
        }

        return try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("Stakka", isDirectory: true)
    }

    func projectsRootURL(createIfNeeded: Bool) throws -> URL {
        let url = try rootURL().appendingPathComponent("Projects", isDirectory: true)
        if createIfNeeded {
            try createDirectoryIfNeeded(at: url)
        }
        return url
    }

    func projectDirectoryURL(for id: UUID, createIfNeeded: Bool) throws -> URL {
        let url = try projectsRootURL(createIfNeeded: true).appendingPathComponent(id.uuidString, isDirectory: true)
        if createIfNeeded {
            try createDirectoryIfNeeded(at: url)
        }
        return url
    }

    func projectFileURL(for directoryURL: URL) -> URL {
        directoryURL.appendingPathComponent("project.json")
    }

    func recentProjectPointerURL() throws -> URL {
        try rootURL().appendingPathComponent("recent-project-id.txt")
    }

    func legacyProjectRootURL(createIfNeeded: Bool) throws -> URL {
        let url = try rootURL().appendingPathComponent("RecentStackProject", isDirectory: true)
        if createIfNeeded {
            try createDirectoryIfNeeded(at: url)
        }
        return url
    }

    func createDirectoryIfNeeded(at url: URL) throws {
        if !fileManager.fileExists(atPath: url.path()) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    func notifyCatalogChange() {
        NotificationCenter.default.post(name: Self.recentProjectDidChangeNotification, object: nil)
    }
}
