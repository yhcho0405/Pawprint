import Foundation
import Observation
import PawprintCore

enum AdventureRouteDifficulty: String, CaseIterable {
    case easy
    case normal
    case hard
    case expert

    var titleKey: String {
        "adventure.expedition.route.difficulty.\(rawValue)"
    }
}

/// Six authored routes spanning every adventure affinity.
///
/// Each route owns three encounters instead of deriving two copies from one boss. That keeps the
/// content catalog in the app layer while the pure engine remains reusable and deterministic.
enum AdventureExpeditionRoute: String, CaseIterable, Identifiable {
    case sunlitTrail
    case signalRooftops
    case midnightArchive
    case dawnGarden
    case noonStation
    case deepNightLab

    var id: String { rawValue }

    var minimumLevel: Int {
        switch self {
        case .sunlitTrail, .signalRooftops, .midnightArchive: return 1
        case .dawnGarden: return 2
        case .noonStation: return 4
        case .deepNightLab: return 6
        }
    }

    var difficulty: AdventureRouteDifficulty {
        switch self {
        case .sunlitTrail: return .easy
        case .signalRooftops, .midnightArchive, .dawnGarden: return .normal
        case .noonStation: return .hard
        case .deepNightLab: return .expert
        }
    }

    var affinity: AdventureAffinity {
        switch self {
        case .sunlitTrail: return .morning
        case .signalRooftops: return .evening
        case .midnightArchive: return .night
        case .dawnGarden: return .dawn
        case .noonStation: return .afternoon
        case .deepNightLab: return .deepNight
        }
    }

    var featuredIntent: AdventureEnemyIntent {
        switch self {
        case .sunlitTrail: return .heavyStrike
        case .signalRooftops, .noonStation: return .guardedStance
        case .midnightArchive, .deepNightLab: return .drainingMist
        case .dawnGarden: return .heavyStrike
        }
    }

    var rewardMultiplierPercent: Int {
        switch self {
        case .sunlitTrail, .signalRooftops, .midnightArchive: return 100
        case .dawnGarden: return 115
        case .noonStation, .deepNightLab: return 130
        }
    }

    var titleKey: String {
        "adventure.expedition.route.\(rawValue).title"
    }

    var descriptionKey: String {
        "adventure.expedition.route.\(rawValue).description"
    }

    var systemImage: String {
        switch self {
        case .sunlitTrail: return "sun.max.fill"
        case .signalRooftops:
            return "antenna.radiowaves.left.and.right"
        case .midnightArchive: return "books.vertical.fill"
        case .dawnGarden: return "camera.macro"
        case .noonStation: return "tram.fill"
        case .deepNightLab: return "server.rack"
        }
    }

    /// The boss encounter retained for compatibility with callers that present one route power.
    var encounter: AdventureEncounter {
        expeditionPlan.stages[2].encounter
    }

    var expeditionPlan: AdventureExpeditionPlan {
        switch self {
        case .sunlitTrail:
            return plan(
                first: ("moss-scout", 34, 72, [.heavyStrike, .guardedStance, .drainingMist]),
                second: ("pollen-trickster", 43, 88, [.guardedStance, .drainingMist, .heavyStrike]),
                boss: ("sunbeam-guardian", 60, 124, [.heavyStrike, .heavyStrike, .guardedStance, .drainingMist])
            )
        case .signalRooftops:
            return plan(
                first: ("wire-sparrow", 36, 72, [.guardedStance, .guardedStance, .heavyStrike]),
                second: ("neon-prowler", 45, 94, [.guardedStance, .heavyStrike, .drainingMist]),
                boss: ("signal-warden", 64, 132, [.guardedStance, .guardedStance, .drainingMist, .heavyStrike])
            )
        case .midnightArchive:
            return plan(
                first: ("dust-wisp", 38, 68, [.drainingMist, .drainingMist, .guardedStance]),
                second: ("ink-shadow", 48, 84, [.drainingMist, .heavyStrike, .drainingMist]),
                boss: ("archive-keeper", 68, 120, [.drainingMist, .drainingMist, .heavyStrike])
            )
        case .dawnGarden:
            return plan(
                first: ("dew-sprite", 39, 72, [.heavyStrike, .drainingMist, .heavyStrike]),
                second: ("glasswing", 50, 96, [.heavyStrike, .heavyStrike, .guardedStance]),
                boss: ("dawn-bloom", 72, 142, [.heavyStrike, .drainingMist, .heavyStrike])
            )
        case .noonStation:
            return plan(
                first: ("platform-spark", 40, 82, [.guardedStance, .guardedStance, .drainingMist]),
                second: ("clockwork-rival", 51, 106, [.guardedStance, .heavyStrike, .drainingMist]),
                boss: ("station-master", 74, 150, [.guardedStance, .guardedStance, .heavyStrike, .drainingMist])
            )
        case .deepNightLab:
            return plan(
                first: ("static-wisp", 42, 84, [.drainingMist, .heavyStrike, .drainingMist, .guardedStance]),
                second: ("sleep-process", 54, 110, [.heavyStrike, .drainingMist, .guardedStance, .drainingMist]),
                boss: ("kernel-guardian", 78, 158, [.drainingMist, .heavyStrike, .guardedStance, .drainingMist])
            )
        }
    }

    func enemyNameKey(stageIndex: Int) -> String {
        let stage: String
        switch stageIndex {
        case 0: stage = "first"
        case 1: stage = "second"
        default: stage = "boss"
        }
        return "adventure.expedition.route.\(rawValue).enemy.\(stage)"
    }

    func isUnlocked(at adventureLevel: Int) -> Bool {
        adventureLevel >= minimumLevel
    }

    private var encounterIDPrefix: String {
        switch self {
        case .sunlitTrail: return "sunlit-trail"
        case .signalRooftops: return "signal-rooftops"
        case .midnightArchive: return "midnight-archive"
        case .dawnGarden: return "dawn-garden"
        case .noonStation: return "noon-station"
        case .deepNightLab: return "deep-night-lab"
        }
    }

    private typealias EncounterDefinition = (
        suffix: String,
        power: Int,
        health: Int,
        intents: [AdventureEnemyIntent]
    )

    private func plan(
        first: EncounterDefinition,
        second: EncounterDefinition,
        boss: EncounterDefinition
    ) -> AdventureExpeditionPlan {
        AdventureExpeditionPlan(
            routeID: rawValue,
            firstEncounter: makeEncounter(first),
            secondEncounter: makeEncounter(second),
            bossEncounter: makeEncounter(boss),
            rewardMultiplierPercent: rewardMultiplierPercent
        )
    }

    private func makeEncounter(
        _ definition: EncounterDefinition
    ) -> AdventureEncounter {
        AdventureEncounter(
            id: "\(encounterIDPrefix)-\(definition.suffix)",
            affinity: affinity,
            power: definition.power,
            maxHealth: definition.health,
            intentPattern: definition.intents
        )
    }

    static func route(
        for encounterID: String
    ) -> AdventureExpeditionRoute? {
        allCases.first { route in
            encounterID.hasPrefix("\(route.encounterIDPrefix)-")
        }
    }
}

/// Owns one in-memory, manually driven expedition independently of every SwiftUI view.
///
/// There is intentionally no clock or scheduler. Hiding the HUD, sleeping the Mac, or leaving a
/// turn unanswered performs no work and cannot change the run. Only explicit local button clicks
/// submit reducer commands.
@MainActor
@Observable
final class AdventureExpeditionCenter {
    static let shared = AdventureExpeditionCenter()

    /// Setup belongs here rather than to either window so the compact HUD and detail window
    /// always edit the same next-run draft.
    private(set) var draftCandidates: [PawpetAdventureCandidate] = []
    private(set) var draftSelectedIDs: [String] = []
    private(set) var draftRoute: AdventureExpeditionRoute = .sunlitTrail

    /// Immutable presentation snapshots for the active run. Draft changes never redraw an
    /// already-running party or route.
    private(set) var state: AdventureExpeditionState?
    private(set) var candidates: [PawpetAdventureCandidate] = []
    private(set) var route: AdventureExpeditionRoute?
    private(set) var turnHistory: [AdventureExpeditionTurnResolution] = []
    private(set) var rewardProgress: AdventureRewardProgress

    @ObservationIgnored private let rewardStore: AdventureRewardStore
    @ObservationIgnored private var hasPreparedDraft = false

    init(
        rewardStore: AdventureRewardStore? = nil
    ) {
        let rewardStore = rewardStore ?? .shared
        self.rewardStore = rewardStore
        rewardProgress = rewardStore.progress
    }

    var isRunning: Bool {
        state?.result == nil && state != nil
    }

    var draftSelectedCandidates: [PawpetAdventureCandidate] {
        draftSelectedIDs.compactMap { id in
            draftCandidates.first { $0.id == id }
        }
    }

    var canStartDraft: Bool {
        state == nil
            && draftSelectedCandidates.count == 3
            && isRouteUnlocked(draftRoute)
    }

    func isRouteUnlocked(_ route: AdventureExpeditionRoute) -> Bool {
        route.isUnlocked(at: rewardProgress.level)
    }

    /// Three equal encounter segments, with enemy HP showing progress inside the active segment.
    var progress: Double {
        guard let state else { return 0 }
        if state.result?.status == .completed { return 1 }

        let completed = Double(state.completedBattles.count)
        let activeFraction: Double
        if state.phase == .awaitingTurn,
           state.battle.initialEnemyHealth > 0 {
            activeFraction = 1
                - Double(state.battle.enemyHealth)
                    / Double(state.battle.initialEnemyHealth)
        } else {
            activeFraction = 0
        }
        return min(1, max(0, (completed + activeFraction) / 3))
    }

    /// Kept as an explicit invariant for lifecycle and regression tests.
    var isUpdateScheduled: Bool { false }

    /// Reconciles the shared setup roster with a freshly derived gallery snapshot.
    ///
    /// The first usable roster receives a balanced recommendation once. Later refreshes retain
    /// explicit user choices and only remove cats that no longer exist.
    func replaceDraftCandidates(
        _ candidates: [PawpetAdventureCandidate]
    ) {
        var seen: Set<String> = []
        draftCandidates = candidates.filter { seen.insert($0.id).inserted }
        // A database refresh must not silently invalidate the immutable party needed by the
        // completed screen's Retry button. Explicit date/retention deletion uses the lifecycle
        // methods below and intentionally ends a run that still references deleted history.
        if state != nil {
            for activeCandidate in self.candidates
                where seen.insert(activeCandidate.id).inserted {
                draftCandidates.append(activeCandidate)
            }
        }

        let available = Set(draftCandidates.map(\.id))
        draftSelectedIDs.removeAll { !available.contains($0) }

        guard !hasPreparedDraft, draftCandidates.count >= 3 else {
            return
        }
        hasPreparedDraft = true
        selectRecommendedDraft()
    }

    /// Sets the requested final selection state, making repeated callbacks idempotent.
    @discardableResult
    func setDraftCandidate(
        id: String,
        selected: Bool
    ) -> Bool {
        guard draftCandidates.contains(where: { $0.id == id }) else {
            return false
        }

        if selected {
            if draftSelectedIDs.contains(id) {
                return true
            }
            guard draftSelectedIDs.count < 3 else { return false }
            draftSelectedIDs.append(id)
        } else {
            draftSelectedIDs.removeAll { $0 == id }
        }
        return true
    }

    /// Selects one cat per role when possible, then fills any remaining slots by roster order.
    func selectRecommendedDraft() {
        var selected: [String] = []

        for role in AdventureRole.allCases {
            guard let candidate = draftCandidates.first(
                where: {
                    $0.profile.role == role && !selected.contains($0.id)
                }
            ) else {
                continue
            }
            selected.append(candidate.id)
        }

        for candidate in draftCandidates
            where selected.count < 3 && !selected.contains(candidate.id) {
            selected.append(candidate.id)
        }
        draftSelectedIDs = selected
    }

    /// Replaces the party in one validated operation, primarily for deterministic harnesses and
    /// compact preset controls.
    @discardableResult
    func selectDraftCandidates(_ ids: [String]) -> Bool {
        let unique = ids.reduce(into: [String]()) { result, id in
            if !result.contains(id) {
                result.append(id)
            }
        }
        let available = Set(draftCandidates.map(\.id))
        guard unique.count <= 3,
              unique.allSatisfy(available.contains)
        else {
            return false
        }
        draftSelectedIDs = unique
        return true
    }

    func setDraftRoute(_ route: AdventureExpeditionRoute) {
        draftRoute = route
    }

    /// Starts the shared setup draft. Randomness is created only for this explicit click.
    @discardableResult
    func startDraft(
        seed: UInt64? = nil,
        plan: AdventureExpeditionPlan? = nil,
        runID: String? = nil
    ) -> Bool {
        guard canStartDraft else { return false }
        var generator = SystemRandomNumberGenerator()
        return start(
            candidates: draftSelectedCandidates,
            route: draftRoute,
            seed: seed ?? generator.next(),
            plan: plan,
            runID: runID ?? UUID().uuidString
        )
    }

    /// Replaces a rendered completed run with a fresh run from the preserved setup draft.
    ///
    /// The expected ID prevents a delayed result-button callback from replacing a newer run.
    @discardableResult
    func retryDraft(
        expectedRunID: String,
        seed: UInt64? = nil,
        plan: AdventureExpeditionPlan? = nil,
        runID: String? = nil
    ) -> Bool {
        guard state?.runID == expectedRunID,
              state?.result != nil,
              (try? AdventureParty(
                  members: draftSelectedCandidates.map(\.profile)
              )) != nil
        else {
            return false
        }
        clearActiveRun()
        return startDraft(
            seed: seed,
            plan: plan,
            runID: runID
        )
    }

    @discardableResult
    func start(
        candidates: [PawpetAdventureCandidate],
        route: AdventureExpeditionRoute,
        seed: UInt64,
        plan: AdventureExpeditionPlan? = nil,
        runID: String = UUID().uuidString
    ) -> Bool {
        guard state == nil else { return false }
        guard isRouteUnlocked(route) else { return false }
        guard plan?.routeID == nil || plan?.routeID == route.rawValue else {
            return false
        }
        guard
            let party = try? AdventureParty(
                members: candidates.map(\.profile)
            )
        else {
            return false
        }

        synchronizeDraft(
            with: candidates,
            route: route
        )
        self.candidates = candidates
        self.route = route
        turnHistory = []
        state = AdventureExpeditionEngine.begin(
            party: party,
            plan: plan ?? route.expeditionPlan,
            seed: seed,
            runID: runID
        )
        return true
    }

    @discardableResult
    func perform(
        _ action: AdventureExpeditionAction,
        expectedTurn: AdventureExpeditionTurnToken
    ) -> Bool {
        guard state?.phase == .awaitingTurn,
              state?.turnToken == expectedTurn
        else {
            return false
        }
        return apply(.perform(action))
    }

    @discardableResult
    func basicAttack(
        catID: String,
        expectedTurn: AdventureExpeditionTurnToken
    ) -> Bool {
        perform(
            .basicAttack(catID: catID),
            expectedTurn: expectedTurn
        )
    }

    @discardableResult
    func useSkill(
        catID: String,
        expectedTurn: AdventureExpeditionTurnToken
    ) -> Bool {
        perform(
            .roleSkill(catID: catID),
            expectedTurn: expectedTurn
        )
    }

    @discardableResult
    func choose(
        relic: AdventureExpeditionRelic,
        expectedRunID: String,
        expectedOffer: AdventureRelicOffer
    ) -> Bool {
        guard state?.runID == expectedRunID,
              case let .choosingRelic(currentOffer) = state?.phase,
              currentOffer == expectedOffer
        else {
            return false
        }
        return apply(.chooseRelic(relic))
    }

    /// Compatibility entry point for callers that cannot retain the rendered offer yet.
    @discardableResult
    func choose(relic: AdventureExpeditionRelic) -> Bool {
        guard let state,
              case let .choosingRelic(offer) = state.phase
        else {
            return false
        }
        return choose(
            relic: relic,
            expectedRunID: state.runID,
            expectedOffer: offer
        )
    }

    @discardableResult
    func withdraw(expectedRunID: String) -> Bool {
        guard state?.runID == expectedRunID else { return false }
        return apply(.withdraw)
    }

    /// Compatibility entry point. Stateful UI should pass the run ID it rendered.
    @discardableResult
    func withdraw() -> Bool {
        guard let runID = state?.runID else { return false }
        return withdraw(expectedRunID: runID)
    }

    /// Drops exactly the rendered active or completed run.
    @discardableResult
    func reset(expectedRunID: String) -> Bool {
        guard state?.runID == expectedRunID else { return false }
        clearActiveRun()
        return true
    }

    /// Explicitly returns to shared setup. Persisted rewards and the setup draft remain.
    func reset() {
        clearActiveRun()
    }

    /// Compatibility hook for app termination. A turn-based session owns no update source.
    func stopUpdates() {}

    /// Removes every in-memory and persisted adventure reference derived from one deleted day.
    func deleteData(forDay day: String) {
        rewardStore.deleteBond(for: day)
        rewardProgress = rewardStore.progress
        removeDraftCandidates { $0.id == day }
    }

    /// Applies Pawprint's activity retention policy to date-linked adventure data as well.
    ///
    /// Aggregate XP and route stamps contain no date identity and remain, like achievements.
    func deleteDateLinkedData(before day: String) {
        rewardStore.deleteBonds(before: day)
        rewardProgress = rewardStore.progress
        removeDraftCandidates { $0.id < day }
    }

    /// Implements Settings' complete-record deletion contract.
    func deleteAllData() {
        rewardStore.reset()
        rewardProgress = rewardStore.progress
        clearActiveRun()
        draftCandidates = []
        draftSelectedIDs = []
        draftRoute = .sunlitTrail
        hasPreparedDraft = false
    }

    private func synchronizeDraft(
        with activeCandidates: [PawpetAdventureCandidate],
        route: AdventureExpeditionRoute
    ) {
        var known = Set(draftCandidates.map(\.id))
        for candidate in activeCandidates
            where known.insert(candidate.id).inserted {
            draftCandidates.append(candidate)
        }
        draftSelectedIDs = activeCandidates.map(\.id)
        draftRoute = route
        hasPreparedDraft = true
    }

    private func removeDraftCandidates(
        where shouldRemove: (PawpetAdventureCandidate) -> Bool
    ) {
        let removedIDs = Set(
            draftCandidates
                .filter(shouldRemove)
                .map(\.id)
        )
        guard !removedIDs.isEmpty else { return }

        draftCandidates.removeAll(where: shouldRemove)
        draftSelectedIDs.removeAll { removedIDs.contains($0) }
        if candidates.contains(where: shouldRemove) {
            clearActiveRun()
        }
        if draftCandidates.isEmpty {
            hasPreparedDraft = false
        }
    }

    private func clearActiveRun() {
        state = nil
        candidates = []
        route = nil
        turnHistory = []
    }

    @discardableResult
    private func apply(
        _ command: AdventureExpeditionCommand
    ) -> Bool {
        guard let currentState = state else { return false }
        let transition = AdventureExpeditionEngine.reduce(
            command,
            in: currentState
        )
        guard transition.disposition == .accepted else { return false }

        for event in transition.events {
            if case let .turnResolved(resolution) = event {
                turnHistory.append(resolution)
            }
        }

        let hadResult = currentState.result != nil
        state = transition.state
        if !hadResult, let result = transition.state.result {
            if rewardStore.apply(result.reward) {
                rewardProgress = rewardStore.progress
            }
        }
        return true
    }
}
