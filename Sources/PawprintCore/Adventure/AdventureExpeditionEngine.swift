/// The kind of encounter occupying one of an expedition's three fixed stages.
package enum AdventureExpeditionStageKind: Equatable, Sendable {
    case skirmish
    case boss
}

/// One deterministic encounter in a short expedition.
package struct AdventureExpeditionStage: Equatable, Sendable {
    package let kind: AdventureExpeditionStageKind
    package let encounter: AdventureEncounter
    package let maxTurns: Int

    package init(
        kind: AdventureExpeditionStageKind,
        encounter: AdventureEncounter,
        maxTurns: Int
    ) {
        self.kind = kind
        self.encounter = encounter
        self.maxTurns = max(1, maxTurns)
    }
}

/// A route always contains two short skirmishes followed by one boss.
///
/// The fixed shape keeps a run compact and prevents UI or persistence snapshots from constructing
/// a campaign with a missing reward stop or a non-terminal boss.
package struct AdventureExpeditionPlan: Equatable, Sendable {
    package let routeID: String
    package let stages: [AdventureExpeditionStage]
    /// Percentage applied to every positive XP grant from this route.
    package let rewardMultiplierPercent: Int

    package init(
        routeID: String,
        firstEncounter: AdventureEncounter,
        secondEncounter: AdventureEncounter,
        bossEncounter: AdventureEncounter,
        rewardMultiplierPercent: Int = 100
    ) {
        self.routeID = routeID
        self.rewardMultiplierPercent = min(
            max(0, rewardMultiplierPercent),
            1_000
        )
        stages = [
            AdventureExpeditionStage(
                kind: .skirmish,
                encounter: firstEncounter,
                maxTurns: 3
            ),
            AdventureExpeditionStage(
                kind: .skirmish,
                encounter: secondEncounter,
                maxTurns: 3
            ),
            AdventureExpeditionStage(
                kind: .boss,
                encounter: bossEncounter,
                maxTurns: 5
            ),
        ]
    }

    /// Builds a compact route from the encounter already exposed by the first adventure UI.
    ///
    /// The supplied encounter remains the boss. Earlier stages use the same affinity at gentler
    /// power levels, so callers can migrate without inventing three new route definitions at once.
    package init(
        routeID: String,
        bossEncounter: AdventureEncounter,
        rewardMultiplierPercent: Int = 100
    ) {
        self.init(
            routeID: routeID,
            firstEncounter: AdventureEncounter(
                id: "\(bossEncounter.id)-approach",
                affinity: bossEncounter.affinity,
                power: max(1, bossEncounter.power * 3 / 5)
            ),
            secondEncounter: AdventureEncounter(
                id: "\(bossEncounter.id)-depths",
                affinity: bossEncounter.affinity,
                power: max(1, bossEncounter.power * 3 / 4)
            ),
            bossEncounter: bossEncounter,
            rewardMultiplierPercent: rewardMultiplierPercent
        )
    }
}

/// The two explicit choices available for every cat.
package typealias AdventureExpeditionAction = AdventureBattleAction

/// One run-scoped reward chosen between encounters.
package enum AdventureExpeditionRelic:
    String,
    CaseIterable,
    Codable,
    Hashable,
    Sendable
{
    /// Adds four damage to every action.
    case sharpenedClaw
    /// Adds four mitigation against every enemy response.
    case paddedCape
    /// Raises maximum shared mana by one and restores one immediately.
    case manaBell
    /// Restores twenty percent of maximum party health immediately.
    case warmTea
    /// Restores one mana after successfully countering an intent.
    case echoCharm
    /// Adds eight healing to the support role skill.
    case healingHerb
}

package struct AdventureRelicOffer: Equatable, Sendable {
    package let afterStageIndex: Int
    package let options: [AdventureExpeditionRelic]
}

/// One resolved exchange with the run resource changes needed by either HUD.
package struct AdventureExpeditionTurnResolution: Equatable, Sendable {
    package let stageIndex: Int
    package let combat: AdventureTurnResolution
    package let manaBefore: Int
    package let manaAfter: Int
    package let triggeredRelics: [AdventureExpeditionRelic]

    package var action: AdventureExpeditionAction { combat.action }
}

/// Compact history retained after the reducer moves on to the next encounter.
package struct AdventureExpeditionBattleSummary: Equatable, Sendable {
    package let stageIndex: Int
    package let kind: AdventureExpeditionStageKind
    package let encounterID: String
    package let outcome: AdventureOutcome
    package let turnCount: Int
    package let startingPartyHealth: Int
    package let remainingPartyHealth: Int
    package let initialEnemyHealth: Int
    package let remainingEnemyHealth: Int
}

package struct AdventureCatBondReward: Equatable, Codable, Sendable {
    package let catID: String
    package let amount: Int
}

/// A replay-safe grant for the separate adventure progression store.
///
/// None of these values modify a cat's activity-derived grade or combat statistics.
package struct AdventurePermanentReward: Equatable, Codable, Sendable {
    package let grantID: String
    package let routeID: String
    package let adventureXP: Int
    package let routeStampDelta: Int
    package let bondGains: [AdventureCatBondReward]

    package init(
        grantID: String,
        routeID: String,
        adventureXP: Int,
        routeStampDelta: Int,
        bondGains: [AdventureCatBondReward]
    ) {
        self.grantID = grantID
        self.routeID = routeID
        self.adventureXP = adventureXP
        self.routeStampDelta = routeStampDelta
        self.bondGains = bondGains
    }
}

package enum AdventureExpeditionRank: String, Codable, Sendable {
    case s = "S"
    case a = "A"
    case b = "B"
    case c = "C"
    case d = "D"
}

package enum AdventureExpeditionResultStatus: Equatable, Sendable {
    case completed
    case defeated
    case withdrew
}

package struct AdventureExpeditionResult: Equatable, Sendable {
    package let status: AdventureExpeditionResultStatus
    package let rank: AdventureExpeditionRank
    /// A deterministic 0...100 performance score. Defeat and withdrawal score zero.
    package let rankScore: Int
    package let completedBattles: [AdventureExpeditionBattleSummary]
    package let totalTurnCount: Int
    package let counteredTurnCount: Int
    package let remainingPartyHealth: Int
    package let maximumPartyHealth: Int
    package let mana: Int
    package let maximumMana: Int
    package let relics: [AdventureExpeditionRelic]
    package let reward: AdventurePermanentReward

    package var grantID: String { reward.grantID }
    package var adventureXP: Int { reward.adventureXP }
    package var routeStampDelta: Int { reward.routeStampDelta }
    package var bondGains: [AdventureCatBondReward] { reward.bondGains }
}

package enum AdventureExpeditionPhase: Equatable, Sendable {
    case awaitingTurn
    case choosingRelic(AdventureRelicOffer)
    case finished
}

/// An immutable snapshot of one manually driven three-battle run.
package struct AdventureExpeditionState: Equatable, Sendable {
    package let runID: String
    package let party: AdventureParty
    package let plan: AdventureExpeditionPlan
    package let seed: UInt64
    /// Zero-based index into `plan.stages`.
    package let stageIndex: Int
    package let battle: AdventureBattleState
    package let mana: Int
    package let maximumMana: Int
    package let relics: [AdventureExpeditionRelic]
    package let completedBattles: [AdventureExpeditionBattleSummary]
    package let totalTurnCount: Int
    package let counteredTurnCount: Int
    package let phase: AdventureExpeditionPhase
    package let result: AdventureExpeditionResult?

    package var currentStage: AdventureExpeditionStage {
        plan.stages[stageIndex]
    }

    /// Identifies the exact unanswered turn currently rendered by a stateful UI.
    ///
    /// A stale button callback must not become a valid action for the following round.
    package var turnToken: AdventureExpeditionTurnToken {
        AdventureExpeditionTurnToken(
            runID: runID,
            stageIndex: stageIndex,
            round: battle.round
        )
    }
}

package struct AdventureExpeditionTurnToken: Equatable, Sendable {
    /// Separates an old view callback from a new run that happens to be on the same round.
    package let runID: String
    package let stageIndex: Int
    package let round: Int
}

package enum AdventureExpeditionCommand: Equatable, Sendable {
    case perform(AdventureExpeditionAction)
    case chooseRelic(AdventureExpeditionRelic)
    case withdraw
}

package enum AdventureExpeditionEvent: Equatable, Sendable {
    case turnResolved(AdventureExpeditionTurnResolution)
    case battleFinished(AdventureExpeditionBattleSummary)
    case relicOffered(AdventureRelicOffer)
    case relicChosen(AdventureExpeditionRelic)
    case battleStarted(AdventureExpeditionStage)
    case finished(AdventureExpeditionResult)
}

package enum AdventureExpeditionCommandRejection: Equatable, Sendable {
    case notAwaitingTurn
    case notChoosingRelic
    case catNotInParty
    case insufficientMana
    case relicNotOffered
    case alreadyFinished
}

package enum AdventureExpeditionCommandDisposition: Equatable, Sendable {
    case accepted
    case rejected(AdventureExpeditionCommandRejection)
}

package struct AdventureExpeditionTransition: Equatable, Sendable {
    package let state: AdventureExpeditionState
    package let events: [AdventureExpeditionEvent]
    package let disposition: AdventureExpeditionCommandDisposition
}

/// A pure, event-driven reducer for two skirmishes and one boss.
///
/// Nothing advances without a submitted command. Seeded lanes depend only on stage and turn, so a
/// rejected command, a hidden HUD, or a recreated view can never change future combat or offers.
package enum AdventureExpeditionEngine {
    static package let startingMana = 2
    static package let baseMaximumMana = 3

    static package func begin(
        party: AdventureParty,
        plan: AdventureExpeditionPlan,
        seed: UInt64,
        runID: String
    ) -> AdventureExpeditionState {
        let firstStage = plan.stages[0]
        let battle = AdventureEngine.beginBattle(
            party: party,
            encounter: firstStage.encounter,
            seed: battleSeed(runSeed: seed, stageIndex: 0),
            startingPartyHealth: party.maxHealth,
            maxRounds: firstStage.maxTurns
        )
        return AdventureExpeditionState(
            runID: runID,
            party: party,
            plan: plan,
            seed: seed,
            stageIndex: 0,
            battle: battle,
            mana: startingMana,
            maximumMana: baseMaximumMana,
            relics: [],
            completedBattles: [],
            totalTurnCount: 0,
            counteredTurnCount: 0,
            phase: .awaitingTurn,
            result: nil
        )
    }

    static package func reduce(
        _ command: AdventureExpeditionCommand,
        in state: AdventureExpeditionState
    ) -> AdventureExpeditionTransition {
        guard state.result == nil else {
            return rejected(.alreadyFinished, state: state)
        }

        switch command {
        case let .perform(action):
            return perform(action, in: state)
        case let .chooseRelic(relic):
            return choose(relic, in: state)
        case .withdraw:
            var accumulator = ExpeditionAccumulator(state)
            let result = finish(&accumulator, status: .withdrew)
            return accepted(
                accumulator.state,
                events: [.finished(result)]
            )
        }
    }

    private static func perform(
        _ action: AdventureExpeditionAction,
        in state: AdventureExpeditionState
    ) -> AdventureExpeditionTransition {
        guard state.phase == .awaitingTurn else {
            return rejected(.notAwaitingTurn, state: state)
        }
        guard state.party.members.contains(where: { $0.id == action.catID }) else {
            return rejected(.catNotInParty, state: state)
        }
        if action.isRoleSkill, state.mana == 0 {
            return rejected(.insufficientMana, state: state)
        }

        let combatResult: AdventureTurnResult
        do {
            combatResult = try AdventureEngine.performTurn(
                action: action,
                modifiers: battleModifiers(for: state.relics),
                in: state.battle
            )
        } catch AdventureBattleError.catNotInParty {
            return rejected(.catNotInParty, state: state)
        } catch {
            return rejected(.notAwaitingTurn, state: state)
        }

        var mana = action.isRoleSkill
            ? state.mana - 1
            : min(state.maximumMana, state.mana + 1)
        var triggeredRelics = combatRelicTriggers(
            action: action,
            combat: combatResult.resolution,
            relics: state.relics
        )

        if state.relics.contains(.echoCharm),
           combatResult.resolution.counteredIntent,
           mana < state.maximumMana {
            mana += 1
            triggeredRelics.append(.echoCharm)
        }

        let turnResolution = AdventureExpeditionTurnResolution(
            stageIndex: state.stageIndex,
            combat: combatResult.resolution,
            manaBefore: state.mana,
            manaAfter: mana,
            triggeredRelics: triggeredRelics
        )
        var accumulator = ExpeditionAccumulator(state)
        accumulator.battle = combatResult.state
        accumulator.mana = mana
        accumulator.totalTurnCount += 1
        if combatResult.resolution.counteredIntent {
            accumulator.counteredTurnCount += 1
        }

        var events: [AdventureExpeditionEvent] = [
            .turnResolved(turnResolution)
        ]

        guard let outcome = combatResult.state.outcome else {
            return accepted(accumulator.state, events: events)
        }

        let summary = battleSummary(
            stageIndex: state.stageIndex,
            stage: state.currentStage,
            battle: combatResult.state
        )
        accumulator.completedBattles.append(summary)
        events.append(.battleFinished(summary))

        switch outcome {
        case .defeat:
            let result = finish(&accumulator, status: .defeated)
            events.append(.finished(result))

        case .victory where state.currentStage.kind == .boss:
            let result = finish(&accumulator, status: .completed)
            events.append(.finished(result))

        case .victory:
            let offer = relicOffer(
                seed: state.seed,
                afterStageIndex: state.stageIndex,
                excluding: state.relics
            )
            accumulator.phase = .choosingRelic(offer)
            events.append(.relicOffered(offer))
        }

        return accepted(accumulator.state, events: events)
    }

    private static func choose(
        _ relic: AdventureExpeditionRelic,
        in state: AdventureExpeditionState
    ) -> AdventureExpeditionTransition {
        guard case let .choosingRelic(offer) = state.phase else {
            return rejected(.notChoosingRelic, state: state)
        }
        guard offer.options.contains(relic), !state.relics.contains(relic) else {
            return rejected(.relicNotOffered, state: state)
        }

        let nextStageIndex = state.stageIndex + 1
        // A valid plan reaches this branch only after either skirmish.
        guard state.plan.stages.indices.contains(nextStageIndex) else {
            return rejected(.notChoosingRelic, state: state)
        }

        var maximumMana = state.maximumMana
        var mana = state.mana
        var partyHealth = state.battle.partyHealth

        switch relic {
        case .manaBell:
            maximumMana += 1
            mana = min(maximumMana, mana + 1)
        case .warmTea:
            let recovery = max(1, state.party.maxHealth / 5)
            partyHealth = min(state.party.maxHealth, partyHealth + recovery)
        default:
            break
        }

        let nextStage = state.plan.stages[nextStageIndex]
        let nextBattle = AdventureEngine.beginBattle(
            party: state.party,
            encounter: nextStage.encounter,
            seed: battleSeed(
                runSeed: state.seed,
                stageIndex: nextStageIndex
            ),
            startingPartyHealth: partyHealth,
            maxRounds: nextStage.maxTurns
        )

        var accumulator = ExpeditionAccumulator(state)
        accumulator.stageIndex = nextStageIndex
        accumulator.battle = nextBattle
        accumulator.mana = mana
        accumulator.maximumMana = maximumMana
        accumulator.relics.append(relic)
        accumulator.phase = .awaitingTurn

        return accepted(
            accumulator.state,
            events: [
                .relicChosen(relic),
                .battleStarted(nextStage),
            ]
        )
    }

    private static func finish(
        _ accumulator: inout ExpeditionAccumulator,
        status: AdventureExpeditionResultStatus
    ) -> AdventureExpeditionResult {
        let rankScore = performanceScore(
            status: status,
            remainingPartyHealth: accumulator.battle.partyHealth,
            maximumPartyHealth: accumulator.party.maxHealth,
            counteredTurnCount: accumulator.counteredTurnCount,
            totalTurnCount: accumulator.totalTurnCount
        )
        let rank = performanceRank(
            status: status,
            score: rankScore
        )
        let reward = permanentReward(
            runID: accumulator.runID,
            plan: accumulator.plan,
            party: accumulator.party,
            status: status,
            rank: rank,
            completedBattles: accumulator.completedBattles
        )
        let result = AdventureExpeditionResult(
            status: status,
            rank: rank,
            rankScore: rankScore,
            completedBattles: accumulator.completedBattles,
            totalTurnCount: accumulator.totalTurnCount,
            counteredTurnCount: accumulator.counteredTurnCount,
            remainingPartyHealth: accumulator.battle.partyHealth,
            maximumPartyHealth: accumulator.party.maxHealth,
            mana: accumulator.mana,
            maximumMana: accumulator.maximumMana,
            relics: accumulator.relics,
            reward: reward
        )
        accumulator.phase = .finished
        accumulator.result = result
        return result
    }

    private static func battleModifiers(
        for relics: [AdventureExpeditionRelic]
    ) -> AdventureBattleModifiers {
        AdventureBattleModifiers(
            flatDamageBonus: relics.contains(.sharpenedClaw) ? 4 : 0,
            flatMitigationBonus: relics.contains(.paddedCape) ? 4 : 0,
            supportHealingBonus: relics.contains(.healingHerb) ? 8 : 0
        )
    }

    private static func combatRelicTriggers(
        action: AdventureExpeditionAction,
        combat: AdventureTurnResolution,
        relics: [AdventureExpeditionRelic]
    ) -> [AdventureExpeditionRelic] {
        var triggers: [AdventureExpeditionRelic] = []
        if relics.contains(.sharpenedClaw), combat.damageDealt > 0 {
            triggers.append(.sharpenedClaw)
        }
        if relics.contains(.paddedCape), combat.enemyHealthRemaining > 0 {
            triggers.append(.paddedCape)
        }
        if relics.contains(.healingHerb),
           action.isRoleSkill,
           combat.actorRole == .support,
           combat.healing > 0 {
            triggers.append(.healingHerb)
        }
        return triggers
    }

    private static func battleSummary(
        stageIndex: Int,
        stage: AdventureExpeditionStage,
        battle: AdventureBattleState
    ) -> AdventureExpeditionBattleSummary {
        AdventureExpeditionBattleSummary(
            stageIndex: stageIndex,
            kind: stage.kind,
            encounterID: stage.encounter.id,
            outcome: battle.outcome ?? .defeat,
            turnCount: battle.history.count,
            startingPartyHealth: battle.startingPartyHealth,
            remainingPartyHealth: battle.partyHealth,
            initialEnemyHealth: battle.initialEnemyHealth,
            remainingEnemyHealth: battle.enemyHealth
        )
    }

    private static func relicOffer(
        seed: UInt64,
        afterStageIndex: Int,
        excluding owned: [AdventureExpeditionRelic]
    ) -> AdventureRelicOffer {
        let candidates = AdventureExpeditionRelic.allCases.filter {
            !owned.contains($0)
        }
        let ordered = candidates.sorted { lhs, rhs in
            let left = relicOrder(
                seed: seed,
                stageIndex: afterStageIndex,
                relic: lhs
            )
            let right = relicOrder(
                seed: seed,
                stageIndex: afterStageIndex,
                relic: rhs
            )
            if left == right {
                return lhs.rawValue < rhs.rawValue
            }
            return left < right
        }
        return AdventureRelicOffer(
            afterStageIndex: afterStageIndex,
            options: Array(ordered.prefix(3))
        )
    }

    private static func relicOrder(
        seed: UInt64,
        stageIndex: Int,
        relic: AdventureExpeditionRelic
    ) -> UInt64 {
        let relicIndex = UInt64(
            AdventureExpeditionRelic.allCases.firstIndex(of: relic) ?? 0
        )
        return deterministicWord(
            seed: seed,
            lane: 1_000
                &+ UInt64(stageIndex) &* 100
                &+ relicIndex
        )
    }

    private static func performanceScore(
        status: AdventureExpeditionResultStatus,
        remainingPartyHealth: Int,
        maximumPartyHealth: Int,
        counteredTurnCount: Int,
        totalTurnCount: Int
    ) -> Int {
        guard status == .completed else { return 0 }

        let healthPoints = maximumPartyHealth == 0
            ? 0
            : remainingPartyHealth * 25 / maximumPartyHealth
        let counterPoints = totalTurnCount == 0
            ? 0
            : counteredTurnCount * 20 / totalTurnCount
        let excessTurns = max(0, totalTurnCount - 8)
        let efficiencyPoints = max(0, 10 - excessTurns * 3)
        return min(
            100,
            40 + healthPoints + counterPoints + efficiencyPoints
        )
    }

    private static func performanceRank(
        status: AdventureExpeditionResultStatus,
        score: Int
    ) -> AdventureExpeditionRank {
        guard status == .completed else { return .d }
        switch score {
        case 90...: return .s
        case 85...: return .a
        case 75...: return .b
        default: return .c
        }
    }

    private static func permanentReward(
        runID: String,
        plan: AdventureExpeditionPlan,
        party: AdventureParty,
        status: AdventureExpeditionResultStatus,
        rank: AdventureExpeditionRank,
        completedBattles: [AdventureExpeditionBattleSummary]
    ) -> AdventurePermanentReward {
        let baseAdventureXP: Int
        switch status {
        case .completed:
            switch rank {
            case .s: baseAdventureXP = 120
            case .a: baseAdventureXP = 100
            case .b: baseAdventureXP = 80
            case .c: baseAdventureXP = 60
            case .d: baseAdventureXP = 40
            }
        case .defeated:
            baseAdventureXP = completedBattles.filter {
                $0.outcome == .victory
            }.count * 10
        case .withdrew:
            baseAdventureXP = 0
        }
        let adventureXP = baseAdventureXP * plan.rewardMultiplierPercent / 100

        let completed = status == .completed
        return AdventurePermanentReward(
            grantID: "\(runID):adventure-expedition",
            routeID: plan.routeID,
            adventureXP: adventureXP,
            routeStampDelta: completed ? 1 : 0,
            bondGains: completed
                ? party.members.map {
                    AdventureCatBondReward(catID: $0.id, amount: 1)
                }
                : []
        )
    }

    private static func battleSeed(
        runSeed: UInt64,
        stageIndex: Int
    ) -> UInt64 {
        deterministicWord(
            seed: runSeed,
            lane: UInt64(stageIndex) &+ 10
        )
    }

    /// Stateless SplitMix64 lanes keep results independent of command count and view lifetime.
    private static func deterministicWord(
        seed: UInt64,
        lane: UInt64
    ) -> UInt64 {
        var value = seed &+ lane &* 0x9E3779B97F4A7C15
        value &+= 0x9E3779B97F4A7C15
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }

    private static func accepted(
        _ state: AdventureExpeditionState,
        events: [AdventureExpeditionEvent]
    ) -> AdventureExpeditionTransition {
        AdventureExpeditionTransition(
            state: state,
            events: events,
            disposition: .accepted
        )
    }

    private static func rejected(
        _ reason: AdventureExpeditionCommandRejection,
        state: AdventureExpeditionState
    ) -> AdventureExpeditionTransition {
        AdventureExpeditionTransition(
            state: state,
            events: [],
            disposition: .rejected(reason)
        )
    }
}

private struct ExpeditionAccumulator {
    let runID: String
    let party: AdventureParty
    let plan: AdventureExpeditionPlan
    let seed: UInt64
    var stageIndex: Int
    var battle: AdventureBattleState
    var mana: Int
    var maximumMana: Int
    var relics: [AdventureExpeditionRelic]
    var completedBattles: [AdventureExpeditionBattleSummary]
    var totalTurnCount: Int
    var counteredTurnCount: Int
    var phase: AdventureExpeditionPhase
    var result: AdventureExpeditionResult?

    init(_ state: AdventureExpeditionState) {
        runID = state.runID
        party = state.party
        plan = state.plan
        seed = state.seed
        stageIndex = state.stageIndex
        battle = state.battle
        mana = state.mana
        maximumMana = state.maximumMana
        relics = state.relics
        completedBattles = state.completedBattles
        totalTurnCount = state.totalTurnCount
        counteredTurnCount = state.counteredTurnCount
        phase = state.phase
        result = state.result
    }

    var state: AdventureExpeditionState {
        AdventureExpeditionState(
            runID: runID,
            party: party,
            plan: plan,
            seed: seed,
            stageIndex: stageIndex,
            battle: battle,
            mana: mana,
            maximumMana: maximumMana,
            relics: relics,
            completedBattles: completedBattles,
            totalTurnCount: totalTurnCount,
            counteredTurnCount: counteredTurnCount,
            phase: phase,
            result: result
        )
    }
}
