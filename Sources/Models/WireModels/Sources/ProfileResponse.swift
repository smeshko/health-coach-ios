import DomainModels

/// The `/profile` response (`openapi.yaml` `ProfileResponse`). Its JSON keys equal the domain
/// member names (camelCase) and it carries no date/enum fields, so the canonical
/// `DomainModels.Profile` decodes it byte-for-byte — there is no separate wire twin or mapping layer
/// (Phase 11.3 D4). Re-exported under the wire name for API-surface continuity.
public typealias ProfileResponse = DomainModels.Profile
