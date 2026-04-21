import Foundation
import UIKit

struct StackProjectSummary: Identifiable, Equatable, Sendable {
    let id: UUID
    let title: String
    let updatedAt: Date
    let totalFrameCount: Int
    let lightFrameCount: Int
    let cometMode: CometStackingMode?
    /// Present only when the project has a persisted stack result (i.e. the
    /// user has finished at least one successful stack). The gallery uses
    /// this to both filter out "incomplete" projects and render the tile.
    let resultThumbnailURL: URL?
}

protocol StackProjectRepository: Sendable {
    func loadRecentProject() async throws -> StackingProject?
    func loadProject(id: UUID) async throws -> StackingProject?
    func loadResultImage(id: UUID) async throws -> UIImage?
    func loadProjectSummaries() async throws -> [StackProjectSummary]
    func save(_ project: StackingProject) async throws
    /// Persists a stacking result for the given project. Called after a
    /// successful pipeline run so the gallery can display the output.
    func saveResult(_ image: UIImage, for projectID: UUID) async throws
    func duplicateProject(id: UUID) async throws -> StackingProject
    func deleteProject(id: UUID) async throws
    func markRecentProject(id: UUID) async throws
    func clearRecentProject() async throws
}
