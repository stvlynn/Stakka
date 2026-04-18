import Foundation

struct StackProjectSummary: Identifiable, Equatable, Sendable {
    let id: UUID
    let title: String
    let updatedAt: Date
    let totalFrameCount: Int
    let lightFrameCount: Int
    let cometMode: CometStackingMode?
}

protocol StackProjectRepository: Sendable {
    func loadRecentProject() async throws -> StackingProject?
    func loadProject(id: UUID) async throws -> StackingProject?
    func loadProjectSummaries() async throws -> [StackProjectSummary]
    func save(_ project: StackingProject) async throws
    func duplicateProject(id: UUID) async throws -> StackingProject
    func deleteProject(id: UUID) async throws
    func markRecentProject(id: UUID) async throws
    func clearRecentProject() async throws
}
