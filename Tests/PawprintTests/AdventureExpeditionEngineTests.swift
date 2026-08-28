import XCTest
import PawprintCore

final class AdventureExpeditionEngineTests: XCTestCase {

    func testPlanIsAlwaysTwoSkirmishesAndOneBoss() throws {
        let plan = expeditionPlan()

        XCTAssertEqual(plan.routeID, "test-route")
        XCTAssertEqual(plan.stages.count, 3)
        XCTAssertEqual(plan.stages.map(\.kind), [.skirmish, .skirmish, .boss])
        XCTAssertEqual(plan.stages.map(\.maxTurns), [3, 3, 5])
    }

    func testConveniencePlanKeepsTheSuppliedEncounterAsBoss() {
        let boss = AdventureEncounter(
            id: "existing-route",
            affinity: .night,
            power: 80
        )
        let plan = AdventureExpeditionPlan(
            routeID: "existing-route",
            bossEncounter: boss
        )

        XCTAssertEqual(plan.stages.count, 3)
        XCTAssertEqual(plan.stages[2].encounter, boss)
        XCTAssertLessThan(plan.stages[0].encounter.power, boss.power)
        XCTAssertLessThan(plan.stages[1].encounter.power, boss.power)
        XCTAssertEqual(plan.stages.map(\.encounter.affinity), [.night, .night, .night])
    }

    func testBeginIsExplicitAndStartsAtFullHealthWithSharedMana() throws {
        let state = try begin()

        XCTAssertEqual(state.runID, "run-001")
        XCTAssertEqual(state.stageIndex, 0)
        XCTAssertEqual(state.currentStage.kind, .skirmish)
        XCTAssertEqual(state.phase, .awaitingTurn)
        XCTAssertEqual(state.battle.partyHealth, state.party.maxHealth)
        XCTAssertEqual(state.battle.startingPartyHealth, state.party.maxHealth)
        XCTAssertEqual(state.mana, 2)
        XCTAssertEqual(state.maximumMana, 3)
        XCTAssertTrue(state.relics.isEmpty)
        XCTAssertTrue(state.completedBattles.isEmpty)
        XCTAssertNil(state.result)
    }

    func testExistingBattleAPIAndInjectedBattleSettingsRemainAvailable() throws {
        let party = try party()
        let encounter = AdventureEncounter(
            id: "long-battle",
            affinity: .night,
            power: 60
        )
        let legacy = AdventureEngine.beginBattle(
            party: party,
            encounter: encounter,
            seed: 7
        )
        let carried = AdventureEngine.beginBattle(
            party: party,
            encounter: encounter,
            seed: 7,
            startingPartyHealth: 200,
            maxRounds: 2
        )

        XCTAssertEqual(legacy.startingPartyHealth, party.maxHealth)
        XCTAssertEqual(legacy.partyHealth, party.maxHealth)
        XCTAssertEqual(legacy.maxRounds, AdventureEngine.battleRoundLimit)
        XCTAssertEqual(carried.startingPartyHealth, 200)
        XCTAssertEqual(carried.partyHealth, 200)
        XCTAssertEqual(carried.initialPartyHealth, party.maxHealth)
        XCTAssertEqual(carried.maxRounds, 2)

        let actor = try counterCatID(in: legacy)
        let oldCall = try AdventureEngine.performTurn(
            catID: actor,
            in: legacy
        )
        let explicitSkill = try AdventureEngine.performTurn(
            action: .roleSkill(catID: actor),
            in: legacy
        )
        XCTAssertEqual(oldCall, explicitSkill)
    }

    func testBasicAttackIsWeakerThanRoleSkillAndKeepsIntentReadable() throws {
        let state = AdventureEngine.beginBattle(
            party: try party(),
            encounter: AdventureEncounter(
                id: "action-comparison",
                affinity: .morning,
                power: 100
            ),
            seed: 14
        )
        let actor = try counterCatID(in: state)

        let basic = try AdventureEngine.performTurn(
            action: .basicAttack(catID: actor),
            in: state
        ).resolution
        let skill = try AdventureEngine.performTurn(
            action: .roleSkill(catID: actor),
            in: state
        ).resolution

        XCTAssertEqual(basic.action, .basicAttack(catID: actor))
        XCTAssertEqual(skill.action, .roleSkill(catID: actor))
        XCTAssertTrue(basic.counteredIntent)
        XCTAssertTrue(skill.counteredIntent)
        XCTAssertGreaterThan(skill.damageDealt, basic.damageDealt)
    }

    func testBasicAttackNeverTriggersSupportHealing() throws {
        let team = try party()
        let initial = AdventureEngine.beginBattle(
            party: team,
            encounter: AdventureEncounter(
                id: "support-action-boundary",
                affinity: .deepNight,
                power: 100
            ),
            seed: 31,
            startingPartyHealth: team.maxHealth - 80,
            maxRounds: 5
        )
        let supportID = try XCTUnwrap(
            team.members.first { $0.role == .support }?.id
        )

        let basic = try AdventureEngine.performTurn(
            action: .basicAttack(catID: supportID),
            in: initial
        ).resolution
        let skill = try AdventureEngine.performTurn(
            action: .roleSkill(catID: supportID),
            in: initial
        ).resolution

        XCTAssertEqual(basic.healing, 0)
        XCTAssertGreaterThan(skill.healing, 0)
    }

    func testBattleModifiersApplyDamageMitigationAndSupportHealing() throws {
        let team = try party()
        let encounter = AdventureEncounter(
            id: "relic-math",
            affinity: .deepNight,
            power: 100
        )
        let initial = AdventureEngine.beginBattle(
            party: team,
            encounter: encounter,
            seed: 31,
            startingPartyHealth: team.maxHealth - 80,
            maxRounds: 5
        )
        // Force the support actor through the same announced response in both branches.
        let supportID = try XCTUnwrap(
            team.members.first { $0.role == .support }?.id
        )

        let base = try AdventureEngine.performTurn(
            action: .roleSkill(catID: supportID),
            in: initial
        ).resolution
        let boosted = try AdventureEngine.performTurn(
            action: .roleSkill(catID: supportID),
            modifiers: AdventureBattleModifiers(
                flatDamageBonus: 4,
                flatMitigationBonus: 4,
                supportHealingBonus: 8
            ),
            in: initial
        ).resolution

        XCTAssertEqual(boosted.damageDealt, base.damageDealt + 4)
        XCTAssertEqual(boosted.mitigation, base.mitigation + 4)
        XCTAssertEqual(boosted.healing, base.healing + 8)
    }

    func testBasicAttackRestoresManaAndRoleSkillConsumesIt() throws {
        var state = try begin(
            plan: expeditionPlan(power: 100)
        )
        let firstActor = try counterCatID(in: state.battle)
        var transition = AdventureExpeditionEngine.reduce(
            .perform(.basicAttack(catID: firstActor)),
            in: state
        )

        XCTAssertEqual(transition.disposition, .accepted)
        XCTAssertEqual(transition.state.mana, 3)
        let basic = try turnResolution(from: transition.events[0])
        XCTAssertEqual(basic.manaBefore, 2)
        XCTAssertEqual(basic.manaAfter, 3)

        state = transition.state
        let secondActor = try counterCatID(in: state.battle)
        transition = AdventureExpeditionEngine.reduce(
            .perform(.roleSkill(catID: secondActor)),
            in: state
        )

        XCTAssertEqual(transition.disposition, .accepted)
        XCTAssertEqual(transition.state.mana, 2)
        let skill = try turnResolution(from: transition.events[0])
        XCTAssertEqual(skill.manaBefore, 3)
        XCTAssertEqual(skill.manaAfter, 2)
    }

    func testSkillAtZeroManaIsRejectedWithoutMutation() throws {
        var state = try begin(
            plan: expeditionPlan(power: 100)
        )

        for _ in 0..<2 {
            let actor = try counterCatID(in: state.battle)
            let transition = AdventureExpeditionEngine.reduce(
                .perform(.roleSkill(catID: actor)),
                in: state
            )
            XCTAssertEqual(transition.disposition, .accepted)
            state = transition.state
        }

        XCTAssertEqual(state.mana, 0)
        XCTAssertEqual(state.phase, .awaitingTurn)
        let actor = try counterCatID(in: state.battle)
        let rejected = AdventureExpeditionEngine.reduce(
            .perform(.roleSkill(catID: actor)),
            in: state
        )

        XCTAssertEqual(
            rejected.disposition,
            .rejected(.insufficientMana)
        )
        XCTAssertEqual(rejected.state, state)
        XCTAssertTrue(rejected.events.isEmpty)
    }

    func testRejectedActionDoesNotChangeStateOrFutureRandomness() throws {
        let initial = try begin(seed: 77, plan: expeditionPlan(power: 100))
        let rejected = AdventureExpeditionEngine.reduce(
            .perform(.basicAttack(catID: "missing-cat")),
            in: initial
        )

        XCTAssertEqual(rejected.disposition, .rejected(.catNotInParty))
        XCTAssertEqual(rejected.state, initial)
        XCTAssertTrue(rejected.events.isEmpty)

        let actor = try counterCatID(in: initial.battle)
        let direct = AdventureExpeditionEngine.reduce(
            .perform(.basicAttack(catID: actor)),
            in: initial
        )
        let afterRejected = AdventureExpeditionEngine.reduce(
            .perform(.basicAttack(catID: actor)),
            in: rejected.state
        )
        XCTAssertEqual(direct, afterRejected)
    }

    func testSameSeedAndCommandsProduceTheSameCompleteRun() throws {
        let first = try playToFinish(
            try begin(seed: 91, plan: easyPlan(), runID: "same-run")
        )
        let second = try playToFinish(
            try begin(seed: 91, plan: easyPlan(), runID: "same-run")
        )

        XCTAssertEqual(first.state, second.state)
        XCTAssertEqual(first.events, second.events)
    }

    func testSkirmishVictoryOffersThreeUniqueDeterministicRelics() throws {
        let first = try firstRelicTransition(seed: 42)
        let second = try firstRelicTransition(seed: 42)
        let offer = try relicOffer(in: first.state)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.state.completedBattles.count, 1)
        XCTAssertEqual(offer.afterStageIndex, 0)
        XCTAssertEqual(offer.options.count, 3)
        XCTAssertEqual(Set(offer.options).count, 3)
        XCTAssertTrue(first.state.relics.isEmpty)
        XCTAssertEqual(first.events.count, 3)
        XCTAssertNoThrow(try turnResolution(from: first.events[0]))
        XCTAssertNoThrow(try battleSummary(from: first.events[1]))
        XCTAssertEqual(try offeredRelics(from: first.events[2]), offer)
    }

    func testUnlistedRelicAndRepeatedChoiceAreRejected() throws {
        let offeredState = try firstRelicTransition(seed: 45).state
        let offer = try relicOffer(in: offeredState)
        let unlisted = try XCTUnwrap(
            AdventureExpeditionRelic.allCases.first {
                !offer.options.contains($0)
            }
        )
        let rejected = AdventureExpeditionEngine.reduce(
            .chooseRelic(unlisted),
            in: offeredState
        )

        XCTAssertEqual(rejected.disposition, .rejected(.relicNotOffered))
        XCTAssertEqual(rejected.state, offeredState)

        let selected = try XCTUnwrap(offer.options.first)
        let accepted = AdventureExpeditionEngine.reduce(
            .chooseRelic(selected),
            in: offeredState
        )
        let repeated = AdventureExpeditionEngine.reduce(
            .chooseRelic(selected),
            in: accepted.state
        )

        XCTAssertEqual(accepted.disposition, .accepted)
        XCTAssertEqual(repeated.disposition, .rejected(.notChoosingRelic))
        XCTAssertEqual(repeated.state, accepted.state)
    }

    func testRelicChoiceStartsNextBattleAndCarriesHealthAndMana() throws {
        let offeredState = try damagedFirstRelicState()
        let offer = try relicOffer(in: offeredState)
        let passiveRelic = try XCTUnwrap(
            offer.options.first {
                $0 != .manaBell && $0 != .warmTea
            }
        )
        let carriedHealth = offeredState.battle.partyHealth
        let carriedMana = offeredState.mana

        let transition = AdventureExpeditionEngine.reduce(
            .chooseRelic(passiveRelic),
            in: offeredState
        )

        XCTAssertEqual(transition.disposition, .accepted)
        XCTAssertEqual(transition.state.stageIndex, 1)
        XCTAssertEqual(transition.state.phase, .awaitingTurn)
        XCTAssertEqual(
            transition.state.battle.startingPartyHealth,
            carriedHealth
        )
        XCTAssertEqual(transition.state.battle.partyHealth, carriedHealth)
        XCTAssertEqual(transition.state.mana, carriedMana)
        XCTAssertEqual(transition.state.relics, [passiveRelic])
        XCTAssertEqual(
            transition.events,
            [
                .relicChosen(passiveRelic),
                .battleStarted(transition.state.currentStage),
            ]
        )
    }

    func testManaBellRaisesCapacityAndWarmTeaRestoresCarriedHealth() throws {
        let manaState = try stateOffering(.manaBell)
        let manaBefore = manaState.mana
        let bell = AdventureExpeditionEngine.reduce(
            .chooseRelic(.manaBell),
            in: manaState
        ).state
        XCTAssertEqual(bell.maximumMana, 4)
        XCTAssertEqual(bell.mana, min(4, manaBefore + 1))

        let teaState = try stateOffering(.warmTea, requiresDamage: true)
        XCTAssertLessThan(teaState.battle.partyHealth, teaState.party.maxHealth)
        let expectedHealth = min(
            teaState.party.maxHealth,
            teaState.battle.partyHealth + teaState.party.maxHealth / 5
        )
        let tea = AdventureExpeditionEngine.reduce(
            .chooseRelic(.warmTea),
            in: teaState
        ).state
        XCTAssertEqual(tea.battle.startingPartyHealth, expectedHealth)
        XCTAssertEqual(tea.battle.partyHealth, expectedHealth)
    }

    func testEchoCharmRefundsManaOnACounteredAction() throws {
        let offered = try stateOffering(.echoCharm)
        var state = AdventureExpeditionEngine.reduce(
            .chooseRelic(.echoCharm),
            in: offered
        ).state
        XCTAssertGreaterThan(state.mana, 0)
        let manaBefore = state.mana
        let actor = try counterCatID(in: state.battle)

        let transition = AdventureExpeditionEngine.reduce(
            .perform(.roleSkill(catID: actor)),
            in: state
        )
        let resolution = try turnResolution(from: transition.events[0])

        XCTAssertTrue(resolution.combat.counteredIntent)
        XCTAssertEqual(resolution.manaAfter, manaBefore)
        XCTAssertTrue(resolution.triggeredRelics.contains(.echoCharm))
        state = transition.state
        XCTAssertEqual(state.mana, manaBefore)
    }

    func testSecondOfferExcludesTheOwnedRelicAndThenStartsBoss() throws {
        let firstOfferState = try firstRelicTransition(seed: 52).state
        let firstOffer = try relicOffer(in: firstOfferState)
        let selected = try XCTUnwrap(firstOffer.options.first)
        var state = AdventureExpeditionEngine.reduce(
            .chooseRelic(selected),
            in: firstOfferState
        ).state

        let actor = try counterCatID(in: state.battle)
        state = AdventureExpeditionEngine.reduce(
            .perform(.roleSkill(catID: actor)),
            in: state
        ).state
        let secondOffer = try relicOffer(in: state)

        XCTAssertEqual(state.completedBattles.count, 2)
        XCTAssertEqual(secondOffer.afterStageIndex, 1)
        XCTAssertEqual(secondOffer.options.count, 3)
        XCTAssertEqual(Set(secondOffer.options).count, 3)
        XCTAssertFalse(secondOffer.options.contains(selected))

        let secondRelic = try XCTUnwrap(secondOffer.options.first)
        state = AdventureExpeditionEngine.reduce(
            .chooseRelic(secondRelic),
            in: state
        ).state
        XCTAssertEqual(state.stageIndex, 2)
        XCTAssertEqual(state.currentStage.kind, .boss)
        XCTAssertEqual(state.phase, .awaitingTurn)
    }

    func testBossVictoryCompletesWithRankAndSeparatePermanentReward() throws {
        let trace = try playToFinish(
            try begin(seed: 12, plan: easyPlan(), runID: "reward-run")
        )
        let result = try XCTUnwrap(trace.state.result)

        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(result.rank, .s)
        XCTAssertEqual(result.rankScore, 95)
        XCTAssertEqual(result.completedBattles.count, 3)
        XCTAssertEqual(
            result.completedBattles.map(\.kind),
            [.skirmish, .skirmish, .boss]
        )
        XCTAssertEqual(result.adventureXP, 120)
        XCTAssertEqual(result.routeStampDelta, 1)
        XCTAssertEqual(result.grantID, "reward-run:adventure-expedition")
        XCTAssertEqual(Set(result.bondGains.map(\.catID)).count, 3)
        XCTAssertTrue(result.bondGains.allSatisfy { $0.amount == 1 })
        XCTAssertEqual(eventCount(.finished, in: trace.events), 1)
        XCTAssertEqual(eventCount(.battleFinished, in: trace.events), 3)
        XCTAssertEqual(eventCount(.relicOffered, in: trace.events), 2)
    }

    func testRouteRewardMultiplierAppliesAfterBaseXPIsCalculated() throws {
        let plan = expeditionPlan(
            firstPower: 1,
            secondPower: 1,
            bossPower: 1,
            rewardMultiplierPercent: 130
        )
        let trace = try playToFinish(
            try begin(seed: 12, plan: plan, runID: "bonus-route")
        )
        let result = try XCTUnwrap(trace.state.result)

        XCTAssertEqual(result.rank, .s)
        XCTAssertEqual(result.adventureXP, 156)
        XCTAssertEqual(plan.rewardMultiplierPercent, 130)
    }

    func testDefeatStopsTheRunWithoutStampOrCatGradeMutation() throws {
        let hard = expeditionPlan(
            firstPower: 1_000,
            secondPower: 1_000,
            bossPower: 1_000
        )
        let initial = try begin(seed: 3, plan: hard)
        let originalParty = initial.party
        let trace = try playToFinish(initial)
        let result = try XCTUnwrap(trace.state.result)

        XCTAssertEqual(result.status, .defeated)
        XCTAssertEqual(result.rank, .d)
        XCTAssertEqual(result.rankScore, 0)
        XCTAssertEqual(result.routeStampDelta, 0)
        XCTAssertEqual(result.adventureXP, 0)
        XCTAssertTrue(result.bondGains.isEmpty)
        XCTAssertEqual(trace.state.party, originalParty)
        XCTAssertEqual(trace.state.phase, .finished)
    }

    func testBossDefeatAwardsOnlySmallPartialAdventureXP() throws {
        let plan = expeditionPlan(
            firstPower: 1,
            secondPower: 1,
            bossPower: 1_000
        )
        let trace = try playToFinish(
            try begin(seed: 5, plan: plan, runID: "partial-run")
        )
        let result = try XCTUnwrap(trace.state.result)

        XCTAssertEqual(result.status, .defeated)
        XCTAssertEqual(
            result.completedBattles.filter { $0.outcome == .victory }.count,
            2
        )
        XCTAssertEqual(result.adventureXP, 20)
        XCTAssertEqual(result.routeStampDelta, 0)
        XCTAssertTrue(result.bondGains.isEmpty)
    }

    func testRouteRewardMultiplierAlsoAppliesToPartialDefeatXP() throws {
        let plan = expeditionPlan(
            firstPower: 1,
            secondPower: 1,
            bossPower: 1_000,
            rewardMultiplierPercent: 115
        )
        let trace = try playToFinish(
            try begin(seed: 5, plan: plan, runID: "partial-bonus")
        )
        let result = try XCTUnwrap(trace.state.result)

        XCTAssertEqual(result.status, .defeated)
        XCTAssertEqual(result.adventureXP, 23)
    }

    func testRouteRewardMultiplierFloorsOneBattlePartialXP() throws {
        let plan = expeditionPlan(
            firstPower: 1,
            secondPower: 1_000,
            bossPower: 1,
            rewardMultiplierPercent: 115
        )
        let trace = try playToFinish(
            try begin(seed: 5, plan: plan, runID: "partial-floor")
        )
        let result = try XCTUnwrap(trace.state.result)

        XCTAssertEqual(result.status, .defeated)
        XCTAssertEqual(result.adventureXP, 11)
    }

    func testWithdrawAndFinishedCommandsCannotGrantTwice() throws {
        let offered = try firstRelicTransition(seed: 61).state
        let withdrew = AdventureExpeditionEngine.reduce(
            .withdraw,
            in: offered
        )
        let result = try XCTUnwrap(withdrew.state.result)

        XCTAssertEqual(result.status, .withdrew)
        XCTAssertEqual(result.rank, .d)
        XCTAssertEqual(result.adventureXP, 0)
        XCTAssertEqual(result.routeStampDelta, 0)
        XCTAssertEqual(result.grantID, "run-001:adventure-expedition")
        XCTAssertEqual(withdrew.events, [.finished(result)])

        let afterFinished = AdventureExpeditionEngine.reduce(
            .withdraw,
            in: withdrew.state
        )
        XCTAssertEqual(
            afterFinished.disposition,
            .rejected(.alreadyFinished)
        )
        XCTAssertEqual(afterFinished.state, withdrew.state)
        XCTAssertTrue(afterFinished.events.isEmpty)
    }

    func testCoreExpeditionHasNoClockOrSchedulingDependency() throws {
        let testURL = URL(fileURLWithPath: #filePath)
        let repository = testURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let engineURL = repository.appendingPathComponent(
            "Sources/PawprintCore/Adventure/AdventureExpeditionEngine.swift"
        )
        let source = try String(contentsOf: engineURL, encoding: .utf8)

        for banned in [
            "Date",
            "Timer",
            "RunLoop",
            "DispatchSource",
            "Task.sleep",
            "ContinuousClock",
        ] {
            XCTAssertFalse(
                source.contains(banned),
                "Expedition core must not reference \(banned)"
            )
        }
    }

    // MARK: - Fixtures

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

    private func party() throws -> AdventureParty {
        try AdventureParty(
            members: [
                cat(
                    "guardian",
                    role: .guardian,
                    passive: .steady
                ),
                cat(
                    "striker",
                    role: .striker,
                    passive: .opportunist
                ),
                cat(
                    "support",
                    role: .support,
                    passive: .focused
                ),
            ]
        )
    }

    private func expeditionPlan(
        power: Int
    ) -> AdventureExpeditionPlan {
        expeditionPlan(
            firstPower: power,
            secondPower: power,
            bossPower: power
        )
    }

    private func expeditionPlan(
        firstPower: Int = 30,
        secondPower: Int = 36,
        bossPower: Int = 45,
        rewardMultiplierPercent: Int = 100
    ) -> AdventureExpeditionPlan {
        AdventureExpeditionPlan(
            routeID: "test-route",
            firstEncounter: AdventureEncounter(
                id: "first",
                affinity: .morning,
                power: firstPower
            ),
            secondEncounter: AdventureEncounter(
                id: "second",
                affinity: .evening,
                power: secondPower
            ),
            bossEncounter: AdventureEncounter(
                id: "boss",
                affinity: .night,
                power: bossPower
            ),
            rewardMultiplierPercent: rewardMultiplierPercent
        )
    }

    private func easyPlan() -> AdventureExpeditionPlan {
        expeditionPlan(firstPower: 1, secondPower: 1, bossPower: 1)
    }

    private func begin(
        seed: UInt64 = 42,
        plan: AdventureExpeditionPlan? = nil,
        runID: String = "run-001"
    ) throws -> AdventureExpeditionState {
        AdventureExpeditionEngine.begin(
            party: try party(),
            plan: plan ?? expeditionPlan(),
            seed: seed,
            runID: runID
        )
    }

    private func counterCatID(
        in battle: AdventureBattleState
    ) throws -> String {
        try XCTUnwrap(
            battle.party.members.first {
                $0.role == battle.currentIntent.counterRole
            }?.id
        )
    }

    private func firstRelicTransition(
        seed: UInt64
    ) throws -> AdventureExpeditionTransition {
        let state = try begin(seed: seed, plan: easyPlan())
        let actor = try counterCatID(in: state.battle)
        return AdventureExpeditionEngine.reduce(
            .perform(.roleSkill(catID: actor)),
            in: state
        )
    }

    private func damagedFirstRelicState(
        seed: UInt64 = 17
    ) throws -> AdventureExpeditionState {
        var state = try begin(
            seed: seed,
            plan: expeditionPlan(
                firstPower: 30,
                secondPower: 1,
                bossPower: 1
            )
        )

        for turn in 0..<3 {
            let actor: String
            let action: AdventureExpeditionAction
            if turn == 0 {
                actor = try XCTUnwrap(
                    state.party.members.first {
                        $0.role != state.battle.currentIntent.counterRole
                    }?.id
                )
                action = .basicAttack(catID: actor)
            } else {
                actor = try counterCatID(in: state.battle)
                action = .roleSkill(catID: actor)
            }
            state = AdventureExpeditionEngine.reduce(
                .perform(action),
                in: state
            ).state
            if case .choosingRelic = state.phase {
                return state
            }
        }
        throw FixtureError.expectedRelicOffer
    }

    private func stateOffering(
        _ relic: AdventureExpeditionRelic,
        requiresDamage: Bool = false
    ) throws -> AdventureExpeditionState {
        for seed in UInt64(0)..<512 {
            let state = requiresDamage
                ? try damagedFirstRelicState(seed: seed)
                : try firstRelicTransition(seed: seed).state
            if try relicOffer(in: state).options.contains(relic),
               !requiresDamage || state.battle.partyHealth < state.party.maxHealth {
                return state
            }
        }
        throw FixtureError.expectedRelicOffer
    }

    private func playToFinish(
        _ initial: AdventureExpeditionState
    ) throws -> RunTrace {
        var state = initial
        var events: [AdventureExpeditionEvent] = []

        for _ in 0..<40 {
            switch state.phase {
            case .awaitingTurn:
                let actor = try counterCatID(in: state.battle)
                let action: AdventureExpeditionAction = state.mana > 0
                    ? .roleSkill(catID: actor)
                    : .basicAttack(catID: actor)
                let transition = AdventureExpeditionEngine.reduce(
                    .perform(action),
                    in: state
                )
                guard transition.disposition == .accepted else {
                    throw FixtureError.rejectedRunCommand
                }
                state = transition.state
                events.append(contentsOf: transition.events)

            case let .choosingRelic(offer):
                let selected = try XCTUnwrap(offer.options.first)
                let transition = AdventureExpeditionEngine.reduce(
                    .chooseRelic(selected),
                    in: state
                )
                guard transition.disposition == .accepted else {
                    throw FixtureError.rejectedRunCommand
                }
                state = transition.state
                events.append(contentsOf: transition.events)

            case .finished:
                return RunTrace(state: state, events: events)
            }
        }
        throw FixtureError.runDidNotFinish
    }

    private func relicOffer(
        in state: AdventureExpeditionState
    ) throws -> AdventureRelicOffer {
        guard case let .choosingRelic(offer) = state.phase else {
            throw FixtureError.expectedRelicOffer
        }
        return offer
    }

    private func turnResolution(
        from event: AdventureExpeditionEvent
    ) throws -> AdventureExpeditionTurnResolution {
        guard case let .turnResolved(resolution) = event else {
            throw FixtureError.wrongEvent
        }
        return resolution
    }

    private func battleSummary(
        from event: AdventureExpeditionEvent
    ) throws -> AdventureExpeditionBattleSummary {
        guard case let .battleFinished(summary) = event else {
            throw FixtureError.wrongEvent
        }
        return summary
    }

    private func offeredRelics(
        from event: AdventureExpeditionEvent
    ) throws -> AdventureRelicOffer {
        guard case let .relicOffered(offer) = event else {
            throw FixtureError.wrongEvent
        }
        return offer
    }

    private enum EventKind {
        case battleFinished
        case relicOffered
        case finished
    }

    private func eventCount(
        _ kind: EventKind,
        in events: [AdventureExpeditionEvent]
    ) -> Int {
        events.filter { event in
            switch (kind, event) {
            case (.battleFinished, .battleFinished),
                 (.relicOffered, .relicOffered),
                 (.finished, .finished):
                return true
            default:
                return false
            }
        }.count
    }

    private struct RunTrace {
        let state: AdventureExpeditionState
        let events: [AdventureExpeditionEvent]
    }

    private enum FixtureError: Error {
        case expectedRelicOffer
        case rejectedRunCommand
        case runDidNotFinish
        case wrongEvent
    }
}
