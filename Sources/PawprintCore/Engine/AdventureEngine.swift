import Foundation

/// The deliberately small gameplay surface used by the first Pawprint adventure.
///
/// These values are independent of SwiftUI and of the activity database. The application maps a
/// completed day's visual traits onto them, then this engine works with the resulting immutable
/// values only.
package enum AdventureRole: String, CaseIterable, Codable, Sendable {
    case guardian
    case striker
    case support
}

package enum AdventureAffinity: String, CaseIterable, Codable, Sendable {
    case dawn
    case morning
    case afternoon
    case evening
    case night
    case deepNight
}

package enum AdventurePassive: String, CaseIterable, Codable, Sendable {
    case steady
    case resilient
    case focused
    case opportunist
    case alert
}

package enum AdventureGrade: String, CaseIterable, Codable, Sendable {
    case s = "S"
    case a = "A"
    case b = "B"
    case c = "C"
    case d = "D"

    /// Grade is a small edge, not a verdict on whether a cat is usable. S and D are kept within
    /// eight points so party composition matters much more than rarity.
    package var statBonus: Int {
        switch self {
        case .s: return 8
        case .a: return 6
        case .b: return 4
        case .c: return 2
        case .d: return 0
        }
    }
}

package struct AdventureCat: Identifiable, Equatable, Sendable {
    package let id: String
    package let role: AdventureRole
    package let affinity: AdventureAffinity
    package let passive: AdventurePassive
    package let grade: AdventureGrade

    package init(
        id: String,
        role: AdventureRole,
        affinity: AdventureAffinity,
        passive: AdventurePassive,
        grade: AdventureGrade
    ) {
        self.id = id
        self.role = role
        self.affinity = affinity
        self.passive = passive
        self.grade = grade
    }

    package var maxHealth: Int {
        let roleHealth: Int
        switch role {
        case .guardian: roleHealth = 112
        case .striker: roleHealth = 100
        case .support: roleHealth = 106
        }
        return roleHealth + grade.statBonus
    }

    package var attack: Int {
        let roleAttack: Int
        switch role {
        case .guardian: roleAttack = 22
        case .striker: roleAttack = 30
        case .support: roleAttack = 20
        }
        return roleAttack + grade.statBonus / 2
    }

    package var guardPower: Int {
        let roleGuard: Int
        switch role {
        case .guardian: roleGuard = 10
        case .striker: roleGuard = 2
        case .support: roleGuard = 4
        }
        // Resilient is applied conditionally by the engine once the party is at half health.
        let passiveGuard = passive == .steady ? 3 : 0
        return roleGuard + passiveGuard + grade.statBonus / 4
    }

    package var healingPower: Int {
        let roleHealing = role == .support ? 10 : 0
        let passiveHealing = passive == .focused ? 3 : 0
        return roleHealing + passiveHealing
    }
}

package enum AdventurePartyError: Error, Equatable {
    case requiresThreeMembers
    case duplicateMember
}

package struct AdventureParty: Equatable, Sendable {
    package let members: [AdventureCat]

    package init(members: [AdventureCat]) throws {
        guard members.count == 3 else {
            throw AdventurePartyError.requiresThreeMembers
        }
        guard Set(members.map(\.id)).count == members.count else {
            throw AdventurePartyError.duplicateMember
        }
        self.members = members
    }

    package var maxHealth: Int {
        members.reduce(0) { $0 + $1.maxHealth }
    }

    package var hasRoleTrinity: Bool {
        Set(members.map(\.role)).count == AdventureRole.allCases.count
    }
}

package struct AdventureEncounter: Equatable, Sendable {
    package let id: String
    package let affinity: AdventureAffinity
    package let power: Int
    /// Route-authored enemy durability, independent from attack power.
    package let maxHealth: Int
    /// Ordered, repeatable intent deck. Duplicate entries make one response more common without
    /// introducing hidden probabilities, and the battle seed still chooses the starting offset.
    package let intentPattern: [AdventureEnemyIntent]

    package init(
        id: String,
        affinity: AdventureAffinity,
        power: Int,
        maxHealth: Int? = nil,
        intentPattern: [AdventureEnemyIntent] = AdventureEnemyIntent.allCases
    ) {
        self.id = id
        self.affinity = affinity
        self.power = min(max(1, power), 1_000)
        self.maxHealth = min(
            max(1, maxHealth ?? self.power * 2),
            2_000
        )
        self.intentPattern = intentPattern.isEmpty
            ? AdventureEnemyIntent.allCases
            : intentPattern
    }
}

package enum AdventureOutcome: Equatable, Sendable {
    case victory
    case defeat
}

/// One passive activation and the cat responsible for it.
///
/// Keeping the actor alongside the effect lets the app build an accurate localized battle log,
/// including parties where two cats share the same expression-derived passive.
package struct AdventurePassiveTrigger: Equatable, Sendable {
    package let catID: String
    package let passive: AdventurePassive

    package init(catID: String, passive: AdventurePassive) {
        self.catID = catID
        self.passive = passive
    }
}

/// Structured combat output. The app target turns these values into localized prose.
package struct AdventureRoundLog: Equatable, Sendable {
    package let round: Int
    package let damageDealt: Int
    package let damageReceived: Int
    package let healing: Int
    package let affinityMatches: Int
    package let passiveTriggers: [AdventurePassiveTrigger]
    package let enemyHealthRemaining: Int
    package let partyHealthRemaining: Int
}

package struct AdventureEncounterResult: Equatable, Sendable {
    package let encounterID: String
    package let outcome: AdventureOutcome
    package let initialEnemyHealth: Int
    package let remainingEnemyHealth: Int
    package let initialPartyHealth: Int
    package let remainingPartyHealth: Int
    package let rounds: [AdventureRoundLog]
}

/// The move the enemy has announced for the current turn.
///
/// Intents are deliberately public knowledge: the player's decision comes from matching the
/// appropriate cat to the announced move rather than guessing hidden randomness.
package enum AdventureEnemyIntent: String, CaseIterable, Codable, Sendable {
    case heavyStrike
    case guardedStance
    case drainingMist

    package var counterRole: AdventureRole {
        switch self {
        case .heavyStrike: return .guardian
        case .guardedStance: return .striker
        case .drainingMist: return .support
        }
    }
}

/// Each role owns one small, readable action.
package enum AdventureSkill: String, CaseIterable, Codable, Sendable {
    case guardianGuard
    case strikerPounce
    case supportMend
}

package extension AdventureRole {
    var skill: AdventureSkill {
        switch self {
        case .guardian: return .guardianGuard
        case .striker: return .strikerPounce
        case .support: return .supportMend
        }
    }
}

/// One explicit action submitted for a turn battle.
///
/// Basic attacks trade power for one shared expedition mana. Role skills use the original
/// role-specific combat behavior and cost mana in the expedition reducer. `AdventureEngine`
/// itself deliberately owns no shared resource state.
package enum AdventureBattleAction: Equatable, Sendable {
    case basicAttack(catID: String)
    case roleSkill(catID: String)

    package var catID: String {
        switch self {
        case let .basicAttack(catID), let .roleSkill(catID):
            return catID
        }
    }

    package var isRoleSkill: Bool {
        if case .roleSkill = self { return true }
        return false
    }
}

/// Run-scoped relic bonuses projected onto one battle exchange.
///
/// Resource-changing relics such as the mana bell and warm tea remain in the expedition reducer;
/// only combat arithmetic enters this lower-level engine.
package struct AdventureBattleModifiers: Equatable, Sendable {
    package let flatDamageBonus: Int
    package let flatMitigationBonus: Int
    package let supportHealingBonus: Int

    package init(
        flatDamageBonus: Int = 0,
        flatMitigationBonus: Int = 0,
        supportHealingBonus: Int = 0
    ) {
        self.flatDamageBonus = max(0, flatDamageBonus)
        self.flatMitigationBonus = max(0, flatMitigationBonus)
        self.supportHealingBonus = max(0, supportHealingBonus)
    }

    static package let none = AdventureBattleModifiers()
}

package enum AdventureBattleError: Error, Equatable {
    case catNotInParty
    case battleFinished
}

/// Everything the UI needs to animate and describe one completed player/enemy exchange.
package struct AdventureTurnResolution: Equatable, Sendable {
    package let round: Int
    package let action: AdventureBattleAction
    package let actorID: String
    package let actorRole: AdventureRole
    package let skill: AdventureSkill
    package let enemyIntent: AdventureEnemyIntent
    package let damageDealt: Int
    package let damageReceived: Int
    package let healing: Int
    /// Damage prevented from the enemy's attack by the selected cat's action and passive.
    package let mitigation: Int
    package let counteredIntent: Bool
    package let passiveTriggers: [AdventurePassiveTrigger]
    package let enemyHealthRemaining: Int
    package let partyHealthRemaining: Int
    package let outcome: AdventureOutcome?
}

/// An immutable, replayable micro-battle snapshot.
///
/// `round` is the turn currently awaiting input. Once a battle finishes it remains the number of
/// the terminal turn, while `history` contains every completed exchange.
package struct AdventureBattleState: Equatable, Sendable {
    package let party: AdventureParty
    package let encounter: AdventureEncounter
    package let seed: UInt64
    package let round: Int
    package let maxRounds: Int
    /// Party health carried into this encounter. It may be below the run-wide maximum.
    package let startingPartyHealth: Int
    /// The run-wide health ceiling. Kept under its original name for source compatibility.
    package let initialPartyHealth: Int
    package let initialEnemyHealth: Int
    package let partyHealth: Int
    package let enemyHealth: Int
    package let currentIntent: AdventureEnemyIntent
    package let outcome: AdventureOutcome?
    package let history: [AdventureTurnResolution]
}

/// A turn is returned alongside its resulting immutable state so callers cannot accidentally
/// render a log from one state while retaining another.
package struct AdventureTurnResult: Equatable, Sendable {
    package let resolution: AdventureTurnResolution
    package let state: AdventureBattleState
}

package enum AdventureEngine {
    static package let battleRoundLimit = 6

    /// Creates a deterministic six-turn battle. No work is performed until a cat is selected.
    static package func beginBattle(
        party: AdventureParty,
        encounter: AdventureEncounter,
        seed: UInt64
    ) -> AdventureBattleState {
        beginBattle(
            party: party,
            encounter: encounter,
            seed: seed,
            startingPartyHealth: party.maxHealth,
            maxRounds: battleRoundLimit
        )
    }

    /// Creates a battle with health carried from an earlier encounter and an injected turn limit.
    ///
    /// Inputs are bounded so an application snapshot cannot create negative health or a battle
    /// with no playable turn. Passing zero health creates an already-defeated snapshot.
    static package func beginBattle(
        party: AdventureParty,
        encounter: AdventureEncounter,
        seed: UInt64,
        startingPartyHealth: Int,
        maxRounds: Int
    ) -> AdventureBattleState {
        let boundedPartyHealth = min(
            party.maxHealth,
            max(0, startingPartyHealth)
        )
        return AdventureBattleState(
            party: party,
            encounter: encounter,
            seed: seed,
            round: 1,
            maxRounds: max(1, maxRounds),
            startingPartyHealth: boundedPartyHealth,
            initialPartyHealth: party.maxHealth,
            initialEnemyHealth: encounter.maxHealth,
            partyHealth: boundedPartyHealth,
            enemyHealth: encounter.maxHealth,
            currentIntent: battleIntent(
                encounter: encounter,
                seed: seed,
                round: 1
            ),
            outcome: boundedPartyHealth == 0 ? .defeat : nil,
            history: []
        )
    }

    /// Performs one player action and, if the enemy survives, its announced response.
    ///
    /// The three role counters are intentionally easy to learn:
    /// guardian ↔ heavy strike, striker ↔ guarded stance, and support ↔ draining mist.
    static package func performTurn(
        catID: String,
        in state: AdventureBattleState
    ) throws -> AdventureTurnResult {
        try performTurn(
            action: .roleSkill(catID: catID),
            modifiers: .none,
            in: state
        )
    }

    /// Performs a basic attack or the selected cat's role skill.
    ///
    /// The expedition reducer validates and updates shared mana around this call. Keeping that
    /// resource outside `AdventureBattleState` preserves the original standalone battle API.
    static package func performTurn(
        action: AdventureBattleAction,
        modifiers: AdventureBattleModifiers = .none,
        in state: AdventureBattleState
    ) throws -> AdventureTurnResult {
        guard state.outcome == nil else {
            throw AdventureBattleError.battleFinished
        }
        guard let actor = state.party.members.first(
            where: { $0.id == action.catID }
        ) else {
            throw AdventureBattleError.catNotInParty
        }

        let intent = state.currentIntent
        let counteredIntent = actor.role == intent.counterRole
        var generator = AdventureGenerator(
            seed: state.seed &+ UInt64(state.round) &* 0xD1342543DE82EF95
        )
        let damageWobble = generator.nextInt(in: -2...2)
        let incomingWobble = generator.nextInt(in: -2...2)
        let opportunistRoll = generator.nextInt(in: 0...3)

        var triggers: [AdventurePassiveTrigger] = []
        var attemptedDamage = action.isRoleSkill
            ? actor.attack + damageWobble
            : max(1, actor.attack * 2 / 3 + damageWobble)

        if action.isRoleSkill {
            switch actor.role {
            case .guardian:
                attemptedDamage += 4
            case .striker:
                attemptedDamage += 8
            case .support:
                break
            }
        }

        if actor.affinity == state.encounter.affinity {
            attemptedDamage += action.isRoleSkill
                ? max(3, actor.attack / 6)
                : max(2, actor.attack / 10)
        }

        switch actor.passive {
        case .alert where state.round == 1:
            attemptedDamage += 5
            triggers.append(
                AdventurePassiveTrigger(catID: actor.id, passive: .alert)
            )
        case .opportunist where opportunistRoll == 0:
            attemptedDamage += 7
            triggers.append(
                AdventurePassiveTrigger(catID: actor.id, passive: .opportunist)
            )
        default:
            break
        }

        if counteredIntent, action.isRoleSkill {
            switch intent {
            case .heavyStrike:
                attemptedDamage += 3
            case .guardedStance:
                attemptedDamage += 10
            case .drainingMist:
                attemptedDamage += 3
            }
        } else if counteredIntent {
            switch intent {
            case .heavyStrike, .drainingMist:
                attemptedDamage += 1
            case .guardedStance:
                attemptedDamage += 5
            }
        }
        attemptedDamage += modifiers.flatDamageBonus

        let enemyGuard = intent == .guardedStance && !counteredIntent
            ? max(6, state.encounter.power / 5)
            : 0
        let damageDealt = min(
            state.enemyHealth,
            max(1, attemptedDamage - enemyGuard)
        )
        let enemyHealth = state.enemyHealth - damageDealt

        var healingCapacity = 0
        if action.isRoleSkill {
            healingCapacity = actor.healingPower
            if actor.role == .support {
                healingCapacity += 12
                if counteredIntent {
                    healingCapacity += 8
                }
                healingCapacity += modifiers.supportHealingBonus
            }
            if actor.passive == .focused {
                healingCapacity += 4
            }
        }
        let healing = min(
            healingCapacity,
            state.initialPartyHealth - state.partyHealth
        )
        if healing > 0, actor.passive == .focused {
            triggers.append(
                AdventurePassiveTrigger(catID: actor.id, passive: .focused)
            )
        }

        var mitigationPotential = actor.guardPower / 2
        if actor.role == .guardian {
            mitigationPotential += action.isRoleSkill ? 8 : 3
        }
        if counteredIntent {
            switch intent {
            case .heavyStrike:
                let full = max(12, state.encounter.power / 3)
                mitigationPotential += action.isRoleSkill ? full : full / 2
            case .guardedStance:
                break
            case .drainingMist:
                let full = max(8, state.encounter.power / 5)
                mitigationPotential += action.isRoleSkill ? full : full / 2
            }
        }
        if actor.passive == .steady {
            mitigationPotential += 4
        }
        if actor.passive == .resilient,
           state.partyHealth * 2 <= state.initialPartyHealth {
            mitigationPotential += 8
        }
        mitigationPotential += modifiers.flatMitigationBonus

        let healedPartyHealth = state.partyHealth + healing
        let enemyAttack: Int
        switch intent {
        case .heavyStrike:
            enemyAttack = state.encounter.power * 3 / 4 + incomingWobble
        case .guardedStance:
            enemyAttack = state.encounter.power * 2 / 5 + incomingWobble
        case .drainingMist:
            let uncounteredDrain = counteredIntent
                ? 0
                : max(8, state.encounter.power / 7)
            enemyAttack = state.encounter.power / 2 + uncounteredDrain + incomingWobble
        }

        let mitigation: Int
        let damageReceived: Int
        if enemyHealth == 0 {
            mitigation = 0
            damageReceived = 0
        } else {
            let boundedEnemyAttack = max(1, enemyAttack)
            mitigation = min(boundedEnemyAttack, max(0, mitigationPotential))
            damageReceived = min(
                healedPartyHealth,
                max(0, boundedEnemyAttack - mitigation)
            )

            if actor.passive == .steady, mitigation > 0 {
                triggers.append(
                    AdventurePassiveTrigger(catID: actor.id, passive: .steady)
                )
            }
            if actor.passive == .resilient,
               state.partyHealth * 2 <= state.initialPartyHealth,
               mitigation > 0 {
                triggers.append(
                    AdventurePassiveTrigger(catID: actor.id, passive: .resilient)
                )
            }
        }

        let partyHealth = healedPartyHealth - damageReceived
        let outcome: AdventureOutcome?
        if enemyHealth == 0 {
            outcome = .victory
        } else if partyHealth == 0 || state.round == state.maxRounds {
            outcome = .defeat
        } else {
            outcome = nil
        }

        let resolution = AdventureTurnResolution(
            round: state.round,
            action: action,
            actorID: actor.id,
            actorRole: actor.role,
            skill: actor.role.skill,
            enemyIntent: intent,
            damageDealt: damageDealt,
            damageReceived: damageReceived,
            healing: healing,
            mitigation: mitigation,
            counteredIntent: counteredIntent,
            passiveTriggers: triggers,
            enemyHealthRemaining: enemyHealth,
            partyHealthRemaining: partyHealth,
            outcome: outcome
        )
        let nextRound = outcome == nil ? state.round + 1 : state.round
        let nextIntent = outcome == nil
            ? battleIntent(
                encounter: state.encounter,
                seed: state.seed,
                round: nextRound
            )
            : intent
        let nextState = AdventureBattleState(
            party: state.party,
            encounter: state.encounter,
            seed: state.seed,
            round: nextRound,
            maxRounds: state.maxRounds,
            startingPartyHealth: state.startingPartyHealth,
            initialPartyHealth: state.initialPartyHealth,
            initialEnemyHealth: state.initialEnemyHealth,
            partyHealth: partyHealth,
            enemyHealth: enemyHealth,
            currentIntent: nextIntent,
            outcome: outcome,
            history: state.history + [resolution]
        )
        return AdventureTurnResult(resolution: resolution, state: nextState)
    }

    private static func battleIntent(
        encounter: AdventureEncounter,
        seed: UInt64,
        round: Int
    ) -> AdventureEnemyIntent {
        var generator = AdventureGenerator(seed: seed)
        let pattern = encounter.intentPattern
        let offset = Int(generator.next() % UInt64(pattern.count))
        let index = (offset + round - 1) % pattern.count
        return pattern[index]
    }

    /// Resolves one compact encounter of up to three rounds.
    ///
    /// Supplying the seed makes a run replayable in tests and prevents SwiftUI body evaluation
    /// from changing its outcome. Randomness only adds a narrow damage wobble and an occasional
    /// opportunist burst; role, affinity and party construction remain the dominant inputs.
    static package func resolve(
        party: AdventureParty,
        encounter: AdventureEncounter,
        seed: UInt64
    ) -> AdventureEncounterResult {
        var generator = AdventureGenerator(seed: seed)
        let initialPartyHealth = party.maxHealth
        let initialEnemyHealth = encounter.maxHealth
        var partyHealth = initialPartyHealth
        var enemyHealth = initialEnemyHealth
        var logs: [AdventureRoundLog] = []

        for round in 1...3 {
            guard partyHealth > 0, enemyHealth > 0 else { break }

            var rawPartyDamage = 0
            var triggers: [AdventurePassiveTrigger] = []
            var affinityMatches = 0

            for cat in party.members {
                var contribution = cat.attack + generator.nextInt(in: -2...2)

                if cat.affinity == encounter.affinity {
                    affinityMatches += 1
                    contribution += max(3, cat.attack / 5)
                }

                switch cat.passive {
                case .alert where round == 1:
                    contribution += 5
                    triggers.append(
                        AdventurePassiveTrigger(catID: cat.id, passive: .alert)
                    )
                case .opportunist where generator.nextInt(in: 0...3) == 0:
                    contribution += 8
                    triggers.append(
                        AdventurePassiveTrigger(catID: cat.id, passive: .opportunist)
                    )
                default:
                    break
                }

                rawPartyDamage += max(1, contribution)
            }

            let trinityBonus = party.hasRoleTrinity ? 5 : 0
            let attemptedDamage = max(1, rawPartyDamage / 2 + trinityBonus)
            let damageDealt = min(enemyHealth, attemptedDamage)
            enemyHealth -= damageDealt

            let healingCapacity = party.members.reduce(0) { $0 + $1.healingPower }
            let healing = min(healingCapacity, initialPartyHealth - partyHealth)
            partyHealth += healing
            if healing > 0 {
                for cat in party.members where cat.passive == .focused {
                    triggers.append(
                        AdventurePassiveTrigger(catID: cat.id, passive: .focused)
                    )
                }
            }

            var totalGuard = party.members.reduce(0) { $0 + $1.guardPower }
            if enemyHealth > 0 {
                for cat in party.members where cat.passive == .steady {
                    triggers.append(
                        AdventurePassiveTrigger(catID: cat.id, passive: .steady)
                    )
                }

                // Steady is a modest guard every round; resilient is a larger comeback guard that
                // only wakes up after the party has fallen to half health.
                if partyHealth * 2 <= initialPartyHealth {
                    for cat in party.members where cat.passive == .resilient {
                        totalGuard += 6
                        triggers.append(
                            AdventurePassiveTrigger(catID: cat.id, passive: .resilient)
                        )
                    }
                }
            }
            let incoming = encounter.power / 2 + generator.nextInt(in: -3...3)
            let attemptedDamageReceived = max(1, incoming - totalGuard)
            let damageReceived = enemyHealth == 0
                ? 0
                : min(partyHealth, attemptedDamageReceived)
            partyHealth -= damageReceived

            logs.append(
                AdventureRoundLog(
                    round: round,
                    damageDealt: damageDealt,
                    damageReceived: damageReceived,
                    healing: healing,
                    affinityMatches: affinityMatches,
                    passiveTriggers: triggers,
                    enemyHealthRemaining: enemyHealth,
                    partyHealthRemaining: partyHealth
                )
            )
        }

        return AdventureEncounterResult(
            encounterID: encounter.id,
            outcome: enemyHealth == 0 ? .victory : .defeat,
            initialEnemyHealth: initialEnemyHealth,
            remainingEnemyHealth: enemyHealth,
            initialPartyHealth: initialPartyHealth,
            remainingPartyHealth: partyHealth,
            rounds: logs
        )
    }
}

/// SplitMix64 is tiny, deterministic on every architecture, and needs no shared mutable state.
private struct AdventureGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }

    mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        let width = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % width)
    }
}
