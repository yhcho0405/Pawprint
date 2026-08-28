import XCTest
import PawprintCore

final class AdventureEngineTests: XCTestCase {

    private func cat(
        _ id: String,
        role: AdventureRole,
        affinity: AdventureAffinity = .morning,
        passive: AdventurePassive = .steady,
        grade: AdventureGrade = .b
    ) -> AdventureCat {
        AdventureCat(
            id: id,
            role: role,
            affinity: affinity,
            passive: passive,
            grade: grade
        )
    }

    private func party(affinity: AdventureAffinity = .morning) throws -> AdventureParty {
        try AdventureParty(
            members: [
                cat("guardian", role: .guardian, affinity: affinity, passive: .steady),
                cat("striker", role: .striker, affinity: affinity, passive: .opportunist),
                cat("support", role: .support, affinity: affinity, passive: .focused),
            ]
        )
    }

    func testPartyRequiresThreeUniqueCats() {
        XCTAssertThrowsError(
            try AdventureParty(members: [cat("one", role: .guardian)])
        ) { error in
            XCTAssertEqual(error as? AdventurePartyError, .requiresThreeMembers)
        }

        let duplicate = cat("same", role: .guardian)
        XCTAssertThrowsError(
            try AdventureParty(members: [duplicate, duplicate, cat("other", role: .support)])
        ) { error in
            XCTAssertEqual(error as? AdventurePartyError, .duplicateMember)
        }
    }

    func testSameSeedProducesExactlyTheSameEncounter() throws {
        let encounter = AdventureEncounter(id: "clearing", affinity: .morning, power: 70)
        let first = AdventureEngine.resolve(party: try party(), encounter: encounter, seed: 42)
        let second = AdventureEngine.resolve(party: try party(), encounter: encounter, seed: 42)

        XCTAssertEqual(first, second)
    }

    func testHealthNeverLeavesItsBounds() throws {
        let encounter = AdventureEncounter(id: "ridge", affinity: .deepNight, power: 140)
        let result = AdventureEngine.resolve(party: try party(), encounter: encounter, seed: 7)

        XCTAssertFalse(result.rounds.isEmpty)
        XCTAssertLessThanOrEqual(result.rounds.count, 3)
        for round in result.rounds {
            XCTAssertGreaterThanOrEqual(round.enemyHealthRemaining, 0)
            XCTAssertLessThanOrEqual(round.enemyHealthRemaining, result.initialEnemyHealth)
            XCTAssertGreaterThanOrEqual(round.partyHealthRemaining, 0)
            XCTAssertLessThanOrEqual(round.partyHealthRemaining, result.initialPartyHealth)
            XCTAssertGreaterThanOrEqual(round.damageDealt, 0)
            XCTAssertGreaterThanOrEqual(round.damageReceived, 0)
            XCTAssertGreaterThanOrEqual(round.healing, 0)
        }
    }

    func testLoggedDeltasReconcileWithFinalHealth() throws {
        let result = AdventureEngine.resolve(
            party: try party(),
            encounter: AdventureEncounter(id: "ledger", affinity: .deepNight, power: 140),
            seed: 19
        )

        XCTAssertEqual(
            result.rounds.reduce(0) { $0 + $1.damageDealt },
            result.initialEnemyHealth - result.remainingEnemyHealth
        )
        XCTAssertEqual(
            result.initialPartyHealth
                + result.rounds.reduce(0) { $0 + $1.healing }
                - result.rounds.reduce(0) { $0 + $1.damageReceived },
            result.remainingPartyHealth
        )
    }

    func testMatchingAffinityImprovesDamageWithTheSameSeed() throws {
        let encounter = AdventureEncounter(id: "dawn-path", affinity: .dawn, power: 100)
        let matching = AdventureEngine.resolve(
            party: try party(affinity: .dawn),
            encounter: encounter,
            seed: 99
        )
        let mismatching = AdventureEngine.resolve(
            party: try party(affinity: .night),
            encounter: encounter,
            seed: 99
        )

        XCTAssertGreaterThan(
            matching.rounds.reduce(0) { $0 + $1.damageDealt },
            mismatching.rounds.reduce(0) { $0 + $1.damageDealt }
        )
    }

    func testGradeIsOnlyASmallStatEdge() {
        let lowest = cat("d", role: .striker, grade: .d)
        let highest = cat("s", role: .striker, grade: .s)

        XCTAssertLessThanOrEqual(highest.maxHealth - lowest.maxHealth, 8)
        XCTAssertLessThanOrEqual(highest.attack - lowest.attack, 4)
    }

    func testEncounterCanProduceBothVictoryAndDefeat() throws {
        let team = try party()
        let easy = AdventureEngine.resolve(
            party: team,
            encounter: AdventureEncounter(id: "easy", affinity: .morning, power: 40),
            seed: 1
        )
        let hard = AdventureEngine.resolve(
            party: team,
            encounter: AdventureEncounter(id: "hard", affinity: .deepNight, power: 180),
            seed: 1
        )

        XCTAssertEqual(easy.outcome, .victory)
        XCTAssertEqual(hard.outcome, .defeat)
    }

    func testEncounterStopsAsSoonAsEitherSideFalls() throws {
        let team = try party()
        let immediateVictory = AdventureEngine.resolve(
            party: team,
            encounter: AdventureEncounter(id: "tiny", affinity: .morning, power: 1),
            seed: 1
        )
        let immediateDefeat = AdventureEngine.resolve(
            party: team,
            encounter: AdventureEncounter(id: "overwhelming", affinity: .deepNight, power: 1_000),
            seed: 1
        )

        XCTAssertEqual(immediateVictory.rounds.count, 1)
        XCTAssertEqual(immediateVictory.rounds.last?.enemyHealthRemaining, 0)
        XCTAssertEqual(immediateVictory.rounds.last?.damageDealt, 2)
        XCTAssertEqual(immediateDefeat.rounds.count, 1)
        XCTAssertEqual(immediateDefeat.rounds.last?.partyHealthRemaining, 0)
        XCTAssertEqual(
            immediateDefeat.rounds.last?.damageReceived,
            immediateDefeat.initialPartyHealth
        )
    }

    func testPassiveLogKeepsActorIdentityAndOnlyReportsActualHealing() throws {
        let team = try AdventureParty(
            members: [
                cat("steady-guardian", role: .guardian, passive: .steady),
                cat("steady-striker", role: .striker, passive: .steady),
                cat("focused-support", role: .support, passive: .focused),
            ]
        )
        let result = AdventureEngine.resolve(
            party: team,
            encounter: AdventureEncounter(id: "long", affinity: .deepNight, power: 160),
            seed: 22
        )

        XCTAssertGreaterThanOrEqual(result.rounds.count, 2)
        let firstRound = try XCTUnwrap(result.rounds.first)
        let firstRoundSteadyCats = Set(
            firstRound.passiveTriggers
                .filter { $0.passive == .steady }
                .map(\.catID)
        )
        XCTAssertEqual(firstRoundSteadyCats, ["steady-guardian", "steady-striker"])
        XCTAssertEqual(firstRound.healing, 0)
        XCTAssertFalse(firstRound.passiveTriggers.contains { $0.passive == .focused })

        let secondRound = result.rounds[1]
        XCTAssertGreaterThan(secondRound.healing, 0)
        XCTAssertTrue(
            secondRound.passiveTriggers.contains {
                $0 == AdventurePassiveTrigger(
                    catID: "focused-support",
                    passive: .focused
                )
            }
        )
    }

    func testResilientGuardOnlyTriggersBelowHalfHealth() throws {
        let team = try AdventureParty(
            members: [
                cat("guardian", role: .guardian, passive: .resilient, grade: .d),
                cat("striker", role: .striker, passive: .resilient, grade: .d),
                cat("support", role: .support, passive: .resilient, grade: .d),
            ]
        )
        let result = AdventureEngine.resolve(
            party: team,
            encounter: AdventureEncounter(id: "attrition", affinity: .deepNight, power: 280),
            seed: 5
        )

        XCTAssertEqual(result.rounds.count, 3)
        XCTAssertFalse(result.rounds[0].passiveTriggers.contains { $0.passive == .resilient })
        XCTAssertFalse(result.rounds[1].passiveTriggers.contains { $0.passive == .resilient })
        XCTAssertEqual(
            result.rounds[2].passiveTriggers.filter { $0.passive == .resilient }.count,
            3
        )
    }

    func testEncounterPowerIsClampedBeforeHealthMath() {
        let tooSmall = AdventureEncounter(id: "small", affinity: .dawn, power: Int.min)
        let tooLarge = AdventureEncounter(id: "large", affinity: .night, power: Int.max)

        XCTAssertEqual(tooSmall.power, 1)
        XCTAssertEqual(tooSmall.maxHealth, 2)
        XCTAssertEqual(tooLarge.power, 1_000)
        XCTAssertEqual(tooLarge.maxHealth, 2_000)
    }

    func testEncounterCanAuthorHealthAndIntentPatternIndependently() throws {
        let encounter = AdventureEncounter(
            id: "authored",
            affinity: .deepNight,
            power: 70,
            maxHealth: 95,
            intentPattern: [.drainingMist]
        )
        let team = try party()
        var battle = AdventureEngine.beginBattle(
            party: team,
            encounter: encounter,
            seed: 42,
            startingPartyHealth: team.maxHealth,
            maxRounds: 3
        )

        XCTAssertEqual(battle.initialEnemyHealth, 95)
        XCTAssertEqual(battle.currentIntent, .drainingMist)

        let actorID = counterCatID(for: battle.currentIntent)
        battle = try AdventureEngine.performTurn(
            action: .basicAttack(catID: actorID),
            in: battle
        ).state
        if battle.outcome == nil {
            XCTAssertEqual(battle.currentIntent, .drainingMist)
        }

        let fallback = AdventureEncounter(
            id: "empty-pattern",
            affinity: .morning,
            power: 10,
            intentPattern: []
        )
        XCTAssertEqual(fallback.intentPattern, AdventureEnemyIntent.allCases)
    }

    func testAuthoredIntentPatternRotatesFromTheSeedAndRepeatsInOrder() throws {
        let encounter = AdventureEncounter(
            id: "weighted-pattern",
            affinity: .evening,
            power: 1,
            maxHealth: 2_000,
            intentPattern: [
                .heavyStrike,
                .guardedStance,
                .heavyStrike,
                .drainingMist,
            ]
        )
        let team = try party()
        var battle = AdventureEngine.beginBattle(
            party: team,
            encounter: encounter,
            seed: 42,
            startingPartyHealth: team.maxHealth,
            maxRounds: 6
        )
        var observed: [AdventureEnemyIntent] = []

        for _ in 0..<4 {
            observed.append(battle.currentIntent)
            battle = try AdventureEngine.performTurn(
                action: .basicAttack(catID: team.members[0].id),
                in: battle
            ).state
        }

        let validRotations: [[AdventureEnemyIntent]] = [
            [.heavyStrike, .guardedStance, .heavyStrike, .drainingMist],
            [.guardedStance, .heavyStrike, .drainingMist, .heavyStrike],
            [.heavyStrike, .drainingMist, .heavyStrike, .guardedStance],
            [.drainingMist, .heavyStrike, .guardedStance, .heavyStrike],
        ]
        XCTAssertTrue(validRotations.contains(observed))
        XCTAssertEqual(battle.currentIntent, observed[0])
    }

    func testTurnBattleIsDeterministicForTheSameChoices() throws {
        let encounter = AdventureEncounter(id: "turns", affinity: .morning, power: 70)
        var first = AdventureEngine.beginBattle(
            party: try party(),
            encounter: encounter,
            seed: 42
        )
        var second = AdventureEngine.beginBattle(
            party: try party(),
            encounter: encounter,
            seed: 42
        )

        while first.outcome == nil {
            let actorID = counterCatID(for: first.currentIntent)
            let firstTurn = try AdventureEngine.performTurn(catID: actorID, in: first)
            let secondTurn = try AdventureEngine.performTurn(catID: actorID, in: second)

            XCTAssertEqual(firstTurn, secondTurn)
            first = firstTurn.state
            second = secondTurn.state
        }

        XCTAssertEqual(first, second)
        XCTAssertFalse(first.history.isEmpty)
    }

    func testEnemyIntentCyclesThroughAllThreeMoves() throws {
        let team = try party()
        var state = AdventureEngine.beginBattle(
            party: team,
            encounter: AdventureEncounter(id: "cycle", affinity: .morning, power: 70),
            seed: 2026
        )
        var intents: [AdventureEnemyIntent] = []

        for _ in 0..<4 {
            intents.append(state.currentIntent)
            let turn = try AdventureEngine.performTurn(
                catID: counterCatID(for: state.currentIntent),
                in: state
            )
            state = turn.state
            if state.outcome != nil { break }
        }

        XCTAssertEqual(intents.count, 4)
        guard intents.count == 4 else { return }
        XCTAssertEqual(Set(intents.prefix(3)).count, 3)
        XCTAssertEqual(intents[0], intents[3])

        let openingIntents = Set(
            (UInt64(0)..<12).map { seed in
                AdventureEngine.beginBattle(
                    party: team,
                    encounter: AdventureEncounter(
                        id: "opening",
                        affinity: .morning,
                        power: 70
                    ),
                    seed: seed
                ).currentIntent
            }
        )
        XCTAssertEqual(openingIntents.count, 3)
    }

    func testEachRoleCounterOutperformsAWrongRole() throws {
        let team = try party()

        let heavyState = battleStarting(
            with: .heavyStrike,
            party: team,
            power: 70
        )
        let guardedState = battleStarting(
            with: .guardedStance,
            party: team,
            power: 70
        )
        let mistState = battleStarting(
            with: .drainingMist,
            party: team,
            power: 70
        )
        XCTAssertEqual(AdventureEnemyIntent.heavyStrike.counterRole, .guardian)
        XCTAssertEqual(AdventureEnemyIntent.guardedStance.counterRole, .striker)
        XCTAssertEqual(AdventureEnemyIntent.drainingMist.counterRole, .support)

        let heavyCounter = try AdventureEngine.performTurn(
            catID: "guardian",
            in: heavyState
        ).resolution
        let heavyWrong = try AdventureEngine.performTurn(
            catID: "striker",
            in: heavyState
        ).resolution
        XCTAssertTrue(heavyCounter.counteredIntent)
        XCTAssertFalse(heavyWrong.counteredIntent)
        XCTAssertEqual(heavyCounter.skill, .guardianGuard)
        XCTAssertGreaterThan(heavyCounter.mitigation, heavyWrong.mitigation)
        XCTAssertLessThan(heavyCounter.damageReceived, heavyWrong.damageReceived)

        let guardedCounter = try AdventureEngine.performTurn(
            catID: "striker",
            in: guardedState
        ).resolution
        let guardedWrong = try AdventureEngine.performTurn(
            catID: "guardian",
            in: guardedState
        ).resolution
        XCTAssertTrue(guardedCounter.counteredIntent)
        XCTAssertFalse(guardedWrong.counteredIntent)
        XCTAssertEqual(guardedCounter.skill, .strikerPounce)
        XCTAssertGreaterThan(guardedCounter.damageDealt, guardedWrong.damageDealt)

        let mistCounter = try AdventureEngine.performTurn(
            catID: "support",
            in: mistState
        ).resolution
        let mistWrong = try AdventureEngine.performTurn(
            catID: "striker",
            in: mistState
        ).resolution
        XCTAssertTrue(mistCounter.counteredIntent)
        XCTAssertFalse(mistWrong.counteredIntent)
        XCTAssertEqual(mistCounter.skill, .supportMend)
        XCTAssertGreaterThan(mistCounter.mitigation, mistWrong.mitigation)
        XCTAssertLessThan(mistCounter.damageReceived, mistWrong.damageReceived)

        for resolution in [
            heavyCounter, heavyWrong,
            guardedCounter, guardedWrong,
            mistCounter, mistWrong,
        ] {
            XCTAssertGreaterThan(resolution.damageDealt, 0)
        }
    }

    func testTurnRejectsUnknownCatAndFinishedBattle() throws {
        let initial = AdventureEngine.beginBattle(
            party: try party(),
            encounter: AdventureEncounter(id: "tiny-turn", affinity: .morning, power: 1),
            seed: 1
        )

        XCTAssertThrowsError(
            try AdventureEngine.performTurn(catID: "not-in-party", in: initial)
        ) { error in
            XCTAssertEqual(error as? AdventureBattleError, .catNotInParty)
        }

        let finalTurn = try AdventureEngine.performTurn(
            catID: "guardian",
            in: initial
        )
        let finished = finalTurn.state
        XCTAssertEqual(finished.outcome, .victory)
        XCTAssertEqual(finalTurn.resolution.damageReceived, 0)
        XCTAssertEqual(finalTurn.resolution.partyHealthRemaining, initial.partyHealth)
        XCTAssertThrowsError(
            try AdventureEngine.performTurn(catID: "guardian", in: finished)
        ) { error in
            XCTAssertEqual(error as? AdventureBattleError, .battleFinished)
        }
    }

    func testTurnHealthAndStructuredLogDeltasStayBounded() throws {
        var state = AdventureEngine.beginBattle(
            party: try party(),
            encounter: AdventureEncounter(id: "bounded", affinity: .morning, power: 70),
            seed: 91
        )
        XCTAssertNil(state.outcome)

        while state.outcome == nil {
            let previous = state
            let turn = try AdventureEngine.performTurn(
                catID: counterCatID(for: state.currentIntent),
                in: state
            )
            let resolution = turn.resolution
            state = turn.state

            XCTAssertEqual(
                previous.enemyHealth - resolution.damageDealt,
                state.enemyHealth
            )
            XCTAssertEqual(
                previous.partyHealth + resolution.healing - resolution.damageReceived,
                state.partyHealth
            )
            XCTAssertEqual(resolution.enemyHealthRemaining, state.enemyHealth)
            XCTAssertEqual(resolution.partyHealthRemaining, state.partyHealth)
            XCTAssertEqual(state.history.last, resolution)
            XCTAssertGreaterThanOrEqual(resolution.damageDealt, 1)
            XCTAssertGreaterThanOrEqual(resolution.damageReceived, 0)
            XCTAssertGreaterThanOrEqual(resolution.healing, 0)
            XCTAssertGreaterThanOrEqual(resolution.mitigation, 0)
            XCTAssertGreaterThanOrEqual(state.enemyHealth, 0)
            XCTAssertLessThanOrEqual(state.enemyHealth, state.initialEnemyHealth)
            XCTAssertGreaterThanOrEqual(state.partyHealth, 0)
            XCTAssertLessThanOrEqual(state.partyHealth, state.initialPartyHealth)
            XCTAssertLessThanOrEqual(state.history.count, state.maxRounds)
        }
    }

    func testPowerSeventyBattleLastsSeveralTurnsAndBothOutcomesExist() throws {
        var balanced = AdventureEngine.beginBattle(
            party: try party(),
            encounter: AdventureEncounter(id: "balanced", affinity: .morning, power: 70),
            seed: 12
        )
        while balanced.outcome == nil {
            balanced = try AdventureEngine.performTurn(
                catID: counterCatID(for: balanced.currentIntent),
                in: balanced
            ).state
        }

        XCTAssertEqual(balanced.outcome, .victory)
        XCTAssertGreaterThanOrEqual(balanced.history.count, 4)
        XCTAssertLessThanOrEqual(balanced.history.count, 6)

        var overwhelming = AdventureEngine.beginBattle(
            party: try party(),
            encounter: AdventureEncounter(
                id: "overwhelming-turns",
                affinity: .deepNight,
                power: 1_000
            ),
            seed: 12
        )
        while overwhelming.outcome == nil {
            overwhelming = try AdventureEngine.performTurn(
                catID: counterCatID(for: overwhelming.currentIntent),
                in: overwhelming
            ).state
        }

        XCTAssertEqual(overwhelming.outcome, .defeat)
        XCTAssertLessThanOrEqual(overwhelming.history.count, 6)
    }

    func testSixthTurnTimesOutWhenBothSidesStillHaveHealth() throws {
        var battle = AdventureEngine.beginBattle(
            party: try supportOnlyParty(),
            encounter: AdventureEncounter(
                id: "six-turn-timeout",
                affinity: .morning,
                power: 70
            ),
            seed: 12
        )

        while battle.outcome == nil {
            battle = try AdventureEngine.performTurn(
                catID: "support-one",
                in: battle
            ).state
        }

        XCTAssertEqual(battle.history.count, battle.maxRounds)
        XCTAssertEqual(battle.outcome, .defeat)
        XCTAssertGreaterThan(battle.partyHealth, 0)
        XCTAssertGreaterThan(battle.enemyHealth, 0)
    }

    func testSixthTurnKillWinsBeforeTheTurnLimitIsApplied() throws {
        var battle = AdventureEngine.beginBattle(
            party: try supportOnlyParty(),
            encounter: AdventureEncounter(
                id: "six-turn-victory",
                affinity: .morning,
                power: 41
            ),
            seed: 17
        )

        while battle.outcome == nil {
            battle = try AdventureEngine.performTurn(
                catID: "support-one",
                in: battle
            ).state
        }

        XCTAssertEqual(battle.history.count, battle.maxRounds)
        XCTAssertEqual(battle.outcome, .victory)
        XCTAssertEqual(battle.enemyHealth, 0)
        XCTAssertGreaterThan(battle.partyHealth, 0)
    }

    private func counterCatID(for intent: AdventureEnemyIntent) -> String {
        switch intent {
        case .heavyStrike: return "guardian"
        case .guardedStance: return "striker"
        case .drainingMist: return "support"
        }
    }

    private func supportOnlyParty() throws -> AdventureParty {
        try AdventureParty(
            members: [
                cat(
                    "support-one",
                    role: .support,
                    affinity: .night,
                    passive: .focused,
                    grade: .d
                ),
                cat(
                    "support-two",
                    role: .support,
                    affinity: .night,
                    passive: .focused,
                    grade: .d
                ),
                cat(
                    "support-three",
                    role: .support,
                    affinity: .night,
                    passive: .focused,
                    grade: .d
                ),
            ]
        )
    }

    private func battleStarting(
        with intent: AdventureEnemyIntent,
        party: AdventureParty,
        power: Int
    ) -> AdventureBattleState {
        let encounter = AdventureEncounter(
            id: "counter-\(intent.rawValue)",
            affinity: .morning,
            power: power
        )

        for seed in UInt64(0)..<100 {
            let state = AdventureEngine.beginBattle(
                party: party,
                encounter: encounter,
                seed: seed
            )
            if state.currentIntent == intent {
                return state
            }
        }

        XCTFail("No seed produced \(intent)")
        return AdventureEngine.beginBattle(
            party: party,
            encounter: encounter,
            seed: 0
        )
    }
}
