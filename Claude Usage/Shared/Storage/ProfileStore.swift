//
//  ProfileStore.swift
//  Claude Usage
//
//  Created by Claude Code on 2026-01-07.
//

import Foundation

/// Manages storage and retrieval of profiles and profile-related data
class ProfileStore {
    static let shared = ProfileStore()

    private let defaults: UserDefaults
    private let keychainService = KeychainService.shared

    private enum Keys {
        static let profiles = "profiles_v3"
        static let activeProfileId = "activeProfileId"
        static let displayMode = "profileDisplayMode"
        static let multiProfileConfig = "multiProfileDisplayConfig"
    }

    init() {
        // Use standard UserDefaults (app container)
        self.defaults = UserDefaults.standard
        LoggingService.shared.log("ProfileStore: Using standard app container storage")
    }

    // MARK: - Profile Management

    func saveProfiles(_ profiles: [Profile]) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted // For debugging
            let data = try encoder.encode(profiles)
            defaults.set(data, forKey: Keys.profiles)

            // Verify save
            if let savedData = defaults.data(forKey: Keys.profiles) {
                LoggingService.shared.log("ProfileStore: Saved \(profiles.count) profiles (\(savedData.count) bytes)")
            } else {
                LoggingService.shared.logError("ProfileStore: Failed to verify save!")
            }
        } catch {
            LoggingService.shared.logStorageError("saveProfiles", error: error)
        }
    }

    func loadProfiles() -> [Profile] {
        guard let data = defaults.data(forKey: Keys.profiles) else {
            LoggingService.shared.log("ProfileStore: No profiles found in storage")
            return []
        }

        do {
            let profiles = try JSONDecoder().decode([Profile].self, from: data)
            LoggingService.shared.log("ProfileStore: Loaded \(profiles.count) profiles from storage")
            return profiles
        } catch {
            LoggingService.shared.logStorageError("loadProfiles", error: error)
            LoggingService.shared.logError("ProfileStore: Failed to decode profiles, returning empty array")
            return []
        }
    }

    func saveActiveProfileId(_ id: UUID) {
        defaults.set(id.uuidString, forKey: Keys.activeProfileId)
    }

    func loadActiveProfileId() -> UUID? {
        guard let uuidString = defaults.string(forKey: Keys.activeProfileId) else {
            return nil
        }
        return UUID(uuidString: uuidString)
    }

    func saveDisplayMode(_ mode: ProfileDisplayMode) {
        defaults.set(mode.rawValue, forKey: Keys.displayMode)
    }

    func loadDisplayMode() -> ProfileDisplayMode {
        guard let rawValue = defaults.string(forKey: Keys.displayMode),
              let mode = ProfileDisplayMode(rawValue: rawValue) else {
            return .single
        }
        return mode
    }

    // MARK: - Multi-Profile Display Config

    func saveMultiProfileConfig(_ config: MultiProfileDisplayConfig) {
        do {
            let data = try JSONEncoder().encode(config)
            defaults.set(data, forKey: Keys.multiProfileConfig)
        } catch {
            LoggingService.shared.logStorageError("saveMultiProfileConfig", error: error)
        }
    }

    func loadMultiProfileConfig() -> MultiProfileDisplayConfig {
        guard let data = defaults.data(forKey: Keys.multiProfileConfig) else {
            return .default
        }
        do {
            return try JSONDecoder().decode(MultiProfileDisplayConfig.self, from: data)
        } catch {
            LoggingService.shared.logStorageError("loadMultiProfileConfig", error: error)
            return .default
        }
    }

    // MARK: - Credential Helpers (Keychain-backed)

    func saveProfileCredentials(_ profileId: UUID, credentials: ProfileCredentials) throws {
        let keychain = KeychainService.shared

        if let val = credentials.claudeSessionKey {
            try keychain.save(val, for: .claudeSessionKey(profileId: profileId))
        } else {
            try keychain.delete(for: .claudeSessionKey(profileId: profileId))
        }
        if let val = credentials.organizationId {
            try keychain.save(val, for: .organizationId(profileId: profileId))
        } else {
            try keychain.delete(for: .organizationId(profileId: profileId))
        }
        if let val = credentials.apiSessionKey {
            try keychain.save(val, for: .apiSessionKey(profileId: profileId))
        } else {
            try keychain.delete(for: .apiSessionKey(profileId: profileId))
        }
        if let val = credentials.apiOrganizationId {
            try keychain.save(val, for: .apiOrganizationId(profileId: profileId))
        } else {
            try keychain.delete(for: .apiOrganizationId(profileId: profileId))
        }
        if let val = credentials.cliCredentialsJSON {
            try keychain.save(val, for: .cliCredentialsJSON(profileId: profileId))
        } else {
            try keychain.delete(for: .cliCredentialsJSON(profileId: profileId))
        }
    }

    func loadProfileCredentials(_ profileId: UUID) throws -> ProfileCredentials {
        let keychain = KeychainService.shared
        return ProfileCredentials(
            claudeSessionKey: try keychain.load(for: .claudeSessionKey(profileId: profileId)),
            organizationId: try keychain.load(for: .organizationId(profileId: profileId)),
            apiSessionKey: try keychain.load(for: .apiSessionKey(profileId: profileId)),
            apiOrganizationId: try keychain.load(for: .apiOrganizationId(profileId: profileId)),
            cliCredentialsJSON: try keychain.load(for: .cliCredentialsJSON(profileId: profileId))
        )
    }

    /// Loads profiles from UserDefaults and hydrates credentials from Keychain
    func loadProfilesWithCredentials() -> [Profile] {
        var profiles = loadProfiles()
        for i in profiles.indices {
            if let creds = try? loadProfileCredentials(profiles[i].id) {
                profiles[i].claudeSessionKey = creds.claudeSessionKey
                profiles[i].organizationId = creds.organizationId
                profiles[i].apiSessionKey = creds.apiSessionKey
                profiles[i].apiOrganizationId = creds.apiOrganizationId
                profiles[i].cliCredentialsJSON = creds.cliCredentialsJSON
            }
        }
        return profiles
    }

    /// Deletes all keychain credentials for a profile
    func deleteProfileCredentials(_ profileId: UUID) throws {
        try KeychainService.shared.deleteAllProfileKeys(profileId: profileId)
    }
}
