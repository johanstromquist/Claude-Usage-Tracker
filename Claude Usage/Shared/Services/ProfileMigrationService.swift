//
//  ProfileMigrationService.swift
//  Claude Usage
//
//  Created by Claude Code on 2026-01-07.
//

import Foundation

/// Handles migration from single-profile (v2.x) to multi-profile system (v3.0)
class ProfileMigrationService {
    static let shared = ProfileMigrationService()

    private let migrationKey = "didMigrateToProfilesV3"

    private init() {}

    func migrateIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migrationKey) else {
            LoggingService.shared.log("Profile migration already completed")
            return
        }

        LoggingService.shared.log("Starting migration to multi-profile system...")

        do {
            // 1. Create first profile from existing settings
            let firstProfile = createFirstProfileFromLegacy()

            // 2. Migrate credentials from old Keychain keys to profile-specific keys
            try migrateCredentialsToProfile(firstProfile.id)

            // 3. Save first profile
            ProfileStore.shared.saveProfiles([firstProfile])
            ProfileStore.shared.saveActiveProfileId(firstProfile.id)
            ProfileStore.shared.saveDisplayMode(.single)

            // 4. Mark migration complete
            UserDefaults.standard.set(true, forKey: migrationKey)

            LoggingService.shared.log("Migration complete. First profile: \(firstProfile.name)")
        } catch {
            LoggingService.shared.logError("Migration failed", error: error)
            // Don't mark as complete so it can retry
        }
    }

    private func createFirstProfileFromLegacy() -> Profile {
        let dataStore = DataStore.shared

        // Generate a funny name for the first profile
        let profileName = FunnyNameGenerator.getRandomName(excluding: [])

        // Load existing settings
        let iconConfig = dataStore.loadMenuBarIconConfiguration()
        let refreshInterval = dataStore.loadRefreshInterval()
        let notificationsEnabled = dataStore.loadNotificationsEnabled()
        let autoStartSessionEnabled = dataStore.loadAutoStartSessionEnabled()

        return Profile(
            id: UUID(),
            name: profileName,
            hasCliAccount: false,
            cliAccountSyncedAt: nil,
            iconConfig: iconConfig,
            refreshInterval: refreshInterval,
            autoStartSessionEnabled: autoStartSessionEnabled,
            notificationSettings: NotificationSettings(
                enabled: notificationsEnabled,
                threshold75Enabled: true,
                threshold90Enabled: true,
                threshold95Enabled: true
            ),
            isSelectedForDisplay: true,
            createdAt: Date(),
            lastUsedAt: Date()
        )
    }

    private func migrateCredentialsToProfile(_ profileId: UUID) throws {
        let keychain = KeychainService.shared
        let dataStore = DataStore.shared

        LoggingService.shared.log("Migrating credentials to profile Keychain entries: \(profileId)")

        // Migrate Claude.ai session key from old Keychain location to per-profile Keychain
        if let sessionKey = try? keychain.load(for: .claudeSessionKey) {
            try keychain.save(sessionKey, for: .claudeSessionKey(profileId: profileId))
            LoggingService.shared.log("Migrated Claude session key to profile Keychain")
        }

        // Migrate API Console session key to per-profile Keychain
        if let apiKey = try? keychain.load(for: .apiSessionKey) {
            try keychain.save(apiKey, for: .apiSessionKey(profileId: profileId))
            LoggingService.shared.log("Migrated API session key to profile Keychain")
        }

        // Migrate organization IDs from DataStore to per-profile Keychain
        if let orgId = dataStore.loadOrganizationId() {
            try keychain.save(orgId, for: .organizationId(profileId: profileId))
            LoggingService.shared.log("Migrated organization ID to profile Keychain")
        }

        if let apiOrgId = dataStore.loadAPIOrganizationId() {
            try keychain.save(apiOrgId, for: .apiOrganizationId(profileId: profileId))
            LoggingService.shared.log("Migrated API organization ID to profile Keychain")
        }

        LoggingService.shared.log("Credential migration to Keychain complete")
    }

    /// Migrates credentials from UserDefaults profile JSON to Keychain (for users upgrading from v2.3.x)
    /// Call this on launch to handle the transition from credentials-in-profile to credentials-in-keychain
    func migrateProfileCredentialsToKeychainIfNeeded() {
        let migrationKey = "didMigrateProfileCredentialsToKeychain_v1"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        LoggingService.shared.log("Checking for profile credentials to migrate from UserDefaults to Keychain...")

        // Read raw profile data from UserDefaults to check for embedded credentials
        guard let data = UserDefaults.standard.data(forKey: "profiles_v3"),
              let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            UserDefaults.standard.set(true, forKey: migrationKey)
            return
        }

        let keychain = KeychainService.shared
        var migratedCount = 0

        for profileJSON in jsonArray {
            guard let idString = profileJSON["id"] as? String,
                  let profileId = UUID(uuidString: idString) else { continue }

            if let sessionKey = profileJSON["claudeSessionKey"] as? String, !sessionKey.isEmpty {
                try? keychain.save(sessionKey, for: .claudeSessionKey(profileId: profileId))
                migratedCount += 1
            }
            if let orgId = profileJSON["organizationId"] as? String, !orgId.isEmpty {
                try? keychain.save(orgId, for: .organizationId(profileId: profileId))
                migratedCount += 1
            }
            if let apiKey = profileJSON["apiSessionKey"] as? String, !apiKey.isEmpty {
                try? keychain.save(apiKey, for: .apiSessionKey(profileId: profileId))
                migratedCount += 1
            }
            if let apiOrgId = profileJSON["apiOrganizationId"] as? String, !apiOrgId.isEmpty {
                try? keychain.save(apiOrgId, for: .apiOrganizationId(profileId: profileId))
                migratedCount += 1
            }
            if let cliJSON = profileJSON["cliCredentialsJSON"] as? String, !cliJSON.isEmpty {
                try? keychain.save(cliJSON, for: .cliCredentialsJSON(profileId: profileId))
                migratedCount += 1
            }
        }

        // Now re-save profiles without credential fields (they'll be excluded by CodingKeys)
        if migratedCount > 0 {
            let profiles = ProfileStore.shared.loadProfiles()
            ProfileStore.shared.saveProfiles(profiles)
            LoggingService.shared.log("Migrated \(migratedCount) credential(s) from UserDefaults to Keychain")
        }

        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    /// Resets migration flag for testing purposes
    func resetMigration() {
        UserDefaults.standard.removeObject(forKey: migrationKey)
        LoggingService.shared.log("Reset migration flag")
    }
}
