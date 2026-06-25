import Foundation

struct LowerThirdPreset: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var role: String
    var organization: String
    var orderIndex: Int

    init(
        id: UUID,
        name: String,
        role: String,
        organization: String,
        orderIndex: Int
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.organization = organization
        self.orderIndex = orderIndex
    }

    static func make(
        id: UUID = UUID(),
        name: String,
        role: String,
        organization: String,
        orderIndex: Int
    ) -> LowerThirdPreset? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }

        return LowerThirdPreset(
            id: id,
            name: trimmedName,
            role: role.trimmingCharacters(in: .whitespacesAndNewlines),
            organization: organization.trimmingCharacters(in: .whitespacesAndNewlines),
            orderIndex: max(0, orderIndex)
        )
    }

    static func normalized(_ presets: [LowerThirdPreset]) -> [LowerThirdPreset] {
        presets
            .compactMap { preset in
                LowerThirdPreset.make(
                    id: preset.id,
                    name: preset.name,
                    role: preset.role,
                    organization: preset.organization,
                    orderIndex: preset.orderIndex
                )
            }
            .sorted {
                if $0.orderIndex == $1.orderIndex {
                    return $0.name.localizedStandardCompare($1.name) == .orderedAscending
                }
                return $0.orderIndex < $1.orderIndex
            }
            .enumerated()
            .map { index, preset in
                var normalizedPreset = preset
                normalizedPreset.orderIndex = index
                return normalizedPreset
            }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case role
        case organization
        case subtitle
        case orderIndex
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name).trimmingCharacters(in: .whitespacesAndNewlines)
        role = (try container.decodeIfPresent(String.self, forKey: .role) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        organization = (try container.decodeIfPresent(String.self, forKey: .organization)
            ?? container.decodeIfPresent(String.self, forKey: .subtitle)
            ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        orderIndex = max(0, try container.decodeIfPresent(Int.self, forKey: .orderIndex) ?? 0)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(role, forKey: .role)
        try container.encode(organization, forKey: .organization)
        try container.encode(orderIndex, forKey: .orderIndex)
    }
}
