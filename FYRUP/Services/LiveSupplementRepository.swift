import Foundation

extension LiveAppRepository {
    func supplements(timezone: String) async throws -> SupplementSnapshot {
        try await client.rpc("get_supplements", body: ["p_timezone": timezone])
    }
    func saveSupplement(_ plan: SupplementPlan) async throws -> SupplementPlan {
        if let message = plan.validationMessage { throw AppError.validation(message) }
        struct Body: Encodable { let p_plan: SupplementPlan }
        return try await client.rpc("save_supplement_plan", body: Body(p_plan: plan))
    }
    func saveSupplementSettings(_ settings: SupplementSettings) async throws -> SupplementSettings {
        guard settings.isValid else { throw AppError.validation("Prüfe deine Ruhezeiten.") }
        struct Body: Encodable { let p_settings: SupplementSettings }
        return try await client.rpc("save_supplement_settings", body: Body(p_settings: settings))
    }
    func setSupplementDose(_ mutation: SupplementDoseMutation) async throws -> SupplementDose {
        struct Body: Encodable { let p_change: SupplementDoseMutation }
        return try await client.rpc("set_supplement_dose", body: Body(p_change: mutation))
    }
}
