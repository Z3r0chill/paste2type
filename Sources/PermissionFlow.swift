/// Permission checks never prompt. Only an explicit settings-button click may
/// request access, at most once per launch; a denied check is not a new request.
struct PermissionFlow {
    private(set) var didRequest = false

    mutating func shouldRequest(granted: Bool, explicitlyRequested: Bool) -> Bool {
        guard explicitlyRequested, !granted, !didRequest else { return false }
        didRequest = true
        return true
    }
}
