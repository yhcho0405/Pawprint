import Foundation
import XCTest
import PawprintCore
@testable import Pawprint

@MainActor
final class AdventureExpeditionCenterTests: XCTestCase {

    func testSharedDraftUsesIdempotentSelectionAndSurvivesReset() throws {
        let context = rewardContext()
        defer { context.cleanup() }
        let center = AdventureExpeditionCenter(
            rewardStore: context.store
        )
        let roster = partyCandidates() + [
            candidate("2026-07-04", role: .striker)
        ]

        center.replaceDraftCandidates(roster)

        XCTAssertEqual(
            center.draftSelectedIDs,
            ["2026-07-01", "2026-07-02", "2026-07-03"]
        )
        XCTAssertTrue(center.canStartDraft)

        XCTAssertTrue(
            center.setDraftCandidate(
                id: "2026-07-03",
                selected: false
            )
        )
        XCTAssertTrue(
            center.setDraftCandidate(
                id: "2026-07-03",
                selected: false
            )
        )
        XCTAssertEqual(center.draftSelectedIDs.count, 2)

        XCTAssertTrue(
            center.setDraftCandidate(
                id: "2026-07-04",
                selected: true
            )
        )
        XCTAssertTrue(
            center.setDraftCandidate(
                id: "2026-07-04",
                selected: true
            )
        )
        XCTAssertFalse(
            center.setDraftCandidate(
                id: "missing",
                selected: true
            )
        )
        XCTAssertEqual(
            center.draftSelectedIDs,
            ["2026-07-01", "2026-07-02", "2026-07-04"]
        )

        center.setDraftRoute(.midnightArchive)
        XCTAssertTrue(
            center.startDraft(
                seed: 5,
                plan: harderPlan(routeID: "midnightArchive"),
                runID: "draft-run"
            )
        )
        XCTAssertEqual(center.route, .midnightArchive)
        XCTAssertEqual(
            center.candidates.map(\.id),
            center.draftSelectedIDs
        )
        XCTAssertFalse(center.canStartDraft)

        XCTAssertTrue(center.reset(expectedRunID: "draft-run"))
        XCTAssertNil(center.state)
        XCTAssertTrue(center.candidates.isEmpty)
        XCTAssertNil(center.route)
        XCTAssertEqual(center.draftCandidates.map(\.id), roster.map(\.id))
        XCTAssertEqual(
            center.draftSelectedIDs,
            ["2026-07-01", "2026-07-02", "2026-07-04"]
        )
        XCTAssertEqual(center.draftRoute, .midnightArchive)
        XCTAssertTrue(center.canStartDraft)

        // Refreshes reconcile the draft instead of applying the initial recommendation again.
        center.replaceDraftCandidates(Array(roster.dropFirst()))
        XCTAssertEqual(
            center.draftSelectedIDs,
            ["2026-07-02", "2026-07-04"]
        )
        XCTAssertFalse(center.canStartDraft)
    }

    func testRosterRefreshKeepsTheImmutablePartyNeededForRetry() throws {
        let context = rewardContext()
        defer { context.cleanup() }
        let center = AdventureExpeditionCenter(
            rewardStore: context.store
        )
        let party = partyCandidates()
        center.replaceDraftCandidates(party)

        XCTAssertTrue(
            center.startDraft(
                seed: 4,
                plan: easyPlan(routeID: "sunlitTrail"),
                runID: "refresh-run"
            )
        )

        center.replaceDraftCandidates([
            candidate("2026-07-10", role: .guardian)
        ])

        XCTAssertEqual(center.draftSelectedIDs, party.map(\.id))
        XCTAssertTrue(
            Set(party.map(\.id)).isSubset(
                of: Set(center.draftCandidates.map(\.id))
            )
        )

        try playToFinish(center)
        XCTAssertTrue(
            center.retryDraft(
                expectedRunID: "refresh-run",
                seed: 5,
                plan: easyPlan(routeID: "sunlitTrail"),
                runID: "refreshed-retry"
            )
        )
        XCTAssertEqual(center.state?.runID, "refreshed-retry")
    }

    func testWithdrawalDoesNotPersistAnEmptyGrant() {
        let context = rewardContext()
        defer { context.cleanup() }
        let center = AdventureExpeditionCenter(
            rewardStore: context.store
        )
        XCTAssertTrue(
            center.start(
                candidates: partyCandidates(),
                route: .sunlitTrail,
                seed: 8,
                runID: "empty-withdrawal"
            )
        )

        XCTAssertTrue(
            center.withdraw(expectedRunID: "empty-withdrawal")
        )
        XCTAssertEqual(center.state?.result?.status, .withdrew)
        XCTAssertEqual(center.rewardProgress, .empty)
        XCTAssertEqual(context.store.progress, .empty)
    }

    func testRewardLedgerIsBounded() {
        let context = rewardContext()
        defer { context.cleanup() }

        for index in 0..<(AdventureRewardStore.grantHistoryLimit + 25) {
            XCTAssertTrue(
                context.store.apply(
                    AdventurePermanentReward(
                        grantID: "grant-\(index)",
                        routeID: "test",
                        adventureXP: 1,
                        routeStampDelta: 0,
                        bondGains: []
                    )
                )
            )
        }

        XCTAssertEqual(
            context.store.progress.appliedGrantIDs.count,
            AdventureRewardStore.grantHistoryLimit
        )
        XCTAssertFalse(
            context.store.progress.appliedGrantIDs.contains("grant-0")
        )
        XCTAssertEqual(
            context.store.progress.adventureXP,
            AdventureRewardStore.grantHistoryLimit + 25
        )
    }

    func testDeletingAdventureDataClearsDateReferencesAndAllProgress() throws {
        let context = rewardContext()
        defer { context.cleanup() }
        let center = AdventureExpeditionCenter(
            rewardStore: context.store
        )
        center.replaceDraftCandidates(partyCandidates())
        XCTAssertTrue(
            center.startDraft(
                seed: 10,
                plan: easyPlan(routeID: "sunlitTrail"),
                runID: "delete-run"
            )
        )

        center.deleteData(forDay: "2026-07-01")

        XCTAssertNil(center.state)
        XCTAssertFalse(
            center.draftCandidates.contains {
                $0.id == "2026-07-01"
            }
        )
        XCTAssertFalse(
            center.draftSelectedIDs.contains("2026-07-01")
        )

        center.deleteAllData()
        XCTAssertEqual(center.rewardProgress, .empty)
        XCTAssertTrue(center.draftCandidates.isEmpty)
        XCTAssertTrue(center.draftSelectedIDs.isEmpty)
        XCTAssertEqual(center.draftRoute, .sunlitTrail)
    }

    func testStartIsExplicitAndASecondStartCannotReplaceTheSession() throws {
        let context = rewardContext()
        defer { context.cleanup() }
        let center = AdventureExpeditionCenter(
            rewardStore: context.store
        )
        let candidates = partyCandidates()

        XCTAssertNil(center.state)
        XCTAssertTrue(
            center.start(
                candidates: candidates,
                route: .sunlitTrail,
                seed: 7,
                plan: easyPlan(routeID: "sunlitTrail"),
                runID: "center-run"
            )
        )
        XCTAssertEqual(center.state?.phase, .awaitingTurn)
        XCTAssertFalse(center.isUpdateScheduled)

        XCTAssertFalse(
            center.start(
                candidates: candidates,
                route: .midnightArchive,
                seed: 99,
                plan: easyPlan(routeID: "midnightArchive"),
                runID: "replacement"
            )
        )
        XCTAssertEqual(center.route, .sunlitTrail)
        XCTAssertEqual(center.state?.seed, 7)
        XCTAssertEqual(center.state?.runID, "center-run")
    }

    func testUnansweredTurnDoesNotAdvanceOrScheduleWork() {
        let context = rewardContext()
        defer { context.cleanup() }
        let center = AdventureExpeditionCenter(
            rewardStore: context.store
        )
        XCTAssertTrue(
            center.start(
                candidates: partyCandidates(),
                route: .signalRooftops,
                seed: 11,
                plan: easyPlan(routeID: "signalRooftops"),
                runID: "paused-run"
            )
        )
        let initial = center.state

        center.stopUpdates()
        center.stopUpdates()

        XCTAssertEqual(center.state, initial)
        XCTAssertEqual(center.state?.phase, .awaitingTurn)
        XCTAssertTrue(center.turnHistory.isEmpty)
        XCTAssertFalse(center.isUpdateScheduled)
    }

    func testLocalActionsAppendExactlyOneTurnAndStaleOrInvalidCommandsDoNot() throws {
        let context = rewardContext()
        defer { context.cleanup() }
        let center = AdventureExpeditionCenter(
            rewardStore: context.store
        )
        XCTAssertTrue(
            center.start(
                candidates: partyCandidates(),
                route: .sunlitTrail,
                seed: 13,
                plan: harderPlan(routeID: "sunlitTrail"),
                runID: "action-run"
            )
        )
        let state = try XCTUnwrap(center.state)
        let actor = try counterCatID(in: state)
        let renderedTurn = state.turnToken

        center.basicAttack(
            catID: actor,
            expectedTurn: renderedTurn
        )

        XCTAssertEqual(center.turnHistory.count, 1)
        XCTAssertEqual(
            center.turnHistory.first?.action,
            .basicAttack(catID: actor)
        )
        let afterAccepted = center.state

        // The same callback can arrive twice from a double-click, but it belongs only to the
        // turn that rendered it and must not consume the next turn.
        center.basicAttack(
            catID: actor,
            expectedTurn: renderedTurn
        )

        XCTAssertEqual(center.state, afterAccepted)
        XCTAssertEqual(center.turnHistory.count, 1)

        let currentTurn = try XCTUnwrap(center.state).turnToken
        center.basicAttack(
            catID: "not-in-party",
            expectedTurn: currentTurn
        )

        XCTAssertEqual(center.state, afterAccepted)
        XCTAssertEqual(center.turnHistory.count, 1)
    }

    func testTurnTokenFromAResetRunCannotActOnTheSameRoundOfANewRun() throws {
        let context = rewardContext()
        defer { context.cleanup() }
        let center = AdventureExpeditionCenter(
            rewardStore: context.store
        )
        let candidates = partyCandidates()
        let plan = harderPlan(routeID: "sunlitTrail")

        XCTAssertTrue(
            center.start(
                candidates: candidates,
                route: .sunlitTrail,
                seed: 23,
                plan: plan,
                runID: "old-run"
            )
        )
        let oldState = try XCTUnwrap(center.state)
        let oldToken = oldState.turnToken
        XCTAssertTrue(center.reset(expectedRunID: "old-run"))

        XCTAssertTrue(
            center.start(
                candidates: candidates,
                route: .sunlitTrail,
                seed: 23,
                plan: plan,
                runID: "new-run"
            )
        )
        let newState = try XCTUnwrap(center.state)
        XCTAssertEqual(oldToken.stageIndex, newState.turnToken.stageIndex)
        XCTAssertEqual(oldToken.round, newState.turnToken.round)
        XCTAssertNotEqual(oldToken.runID, newState.turnToken.runID)
        let actor = try counterCatID(in: newState)

        XCTAssertFalse(
            center.basicAttack(
                catID: actor,
                expectedTurn: oldToken
            )
        )
        XCTAssertEqual(center.state, newState)
        XCTAssertTrue(center.turnHistory.isEmpty)

        XCTAssertTrue(
            center.basicAttack(
                catID: actor,
                expectedTurn: newState.turnToken
            )
        )
        XCTAssertEqual(center.turnHistory.count, 1)
    }

    func testStaleRelicResetAndWithdrawCallbacksCannotMutateANewRun() throws {
        let context = rewardContext()
        defer { context.cleanup() }
        let center = AdventureExpeditionCenter(
            rewardStore: context.store
        )
        let candidates = partyCandidates()
        let plan = easyPlan(routeID: "sunlitTrail")

        XCTAssertTrue(
            center.start(
                candidates: candidates,
                route: .sunlitTrail,
                seed: 29,
                plan: plan,
                runID: "offer-old"
            )
        )
        let oldOffer = try advanceToRelicOffer(center)
        XCTAssertTrue(center.reset(expectedRunID: "offer-old"))

        XCTAssertTrue(
            center.start(
                candidates: candidates,
                route: .sunlitTrail,
                seed: 29,
                plan: plan,
                runID: "offer-new"
            )
        )
        let newOffer = try advanceToRelicOffer(center)
        let offeredState = try XCTUnwrap(center.state)
        let relic = try XCTUnwrap(newOffer.options.first)

        XCTAssertFalse(
            center.choose(
                relic: relic,
                expectedRunID: "offer-old",
                expectedOffer: oldOffer
            )
        )
        XCTAssertEqual(center.state, offeredState)

        XCTAssertTrue(
            center.choose(
                relic: relic,
                expectedRunID: "offer-new",
                expectedOffer: newOffer
            )
        )
        let afterChoice = try XCTUnwrap(center.state)
        XCTAssertEqual(afterChoice.stageIndex, 1)
        XCTAssertFalse(
            center.choose(
                relic: relic,
                expectedRunID: "offer-new",
                expectedOffer: newOffer
            )
        )
        XCTAssertEqual(center.state, afterChoice)

        XCTAssertFalse(center.reset(expectedRunID: "offer-old"))
        XCTAssertFalse(center.withdraw(expectedRunID: "offer-old"))
        XCTAssertEqual(center.state, afterChoice)
    }

    func testAuthoredRoutesCoverEveryAffinityAndDifficultyTier() {
        XCTAssertEqual(
            AdventureExpeditionRoute.allCases.map(\.encounter.power),
            [60, 64, 68, 72, 74, 78]
        )
        XCTAssertEqual(
            AdventureExpeditionRoute.allCases.map(\.minimumLevel),
            [1, 1, 1, 2, 4, 6]
        )
        XCTAssertEqual(
            AdventureExpeditionRoute.allCases.map(\.rewardMultiplierPercent),
            [100, 100, 100, 115, 130, 130]
        )
        XCTAssertEqual(
            AdventureExpeditionRoute.allCases.map(\.difficulty),
            [.easy, .normal, .normal, .normal, .hard, .expert]
        )
        XCTAssertEqual(
            Set(AdventureExpeditionRoute.allCases.map { $0.affinity.rawValue }),
            Set(AdventureAffinity.allCases.map(\.rawValue))
        )

        let stages = AdventureExpeditionRoute.allCases.flatMap {
            $0.expeditionPlan.stages
        }
        XCTAssertEqual(stages.count, 18)
        XCTAssertEqual(Set(stages.map { $0.encounter.id }).count, 18)
        XCTAssertTrue(
            stages.allSatisfy { !$0.encounter.intentPattern.isEmpty }
        )
        XCTAssertEqual(
            AdventureExpeditionRoute.allCases.map {
                $0.expeditionPlan.stages.map(\.maxTurns)
            },
            Array(repeating: [3, 3, 5], count: 6)
        )
        XCTAssertEqual(
            stages.map { stage in
                let encounter = stage.encounter
                let pattern = encounter.intentPattern
                    .map(\.rawValue)
                    .joined(separator: ",")
                return "\(encounter.power)/\(encounter.maxHealth)/\(pattern)"
            },
            [
                "34/72/heavyStrike,guardedStance,drainingMist",
                "43/88/guardedStance,drainingMist,heavyStrike",
                "60/124/heavyStrike,heavyStrike,guardedStance,drainingMist",
                "36/72/guardedStance,guardedStance,heavyStrike",
                "45/94/guardedStance,heavyStrike,drainingMist",
                "64/132/guardedStance,guardedStance,drainingMist,heavyStrike",
                "38/68/drainingMist,drainingMist,guardedStance",
                "48/84/drainingMist,heavyStrike,drainingMist",
                "68/120/drainingMist,drainingMist,heavyStrike",
                "39/72/heavyStrike,drainingMist,heavyStrike",
                "50/96/heavyStrike,heavyStrike,guardedStance",
                "72/142/heavyStrike,drainingMist,heavyStrike",
                "40/82/guardedStance,guardedStance,drainingMist",
                "51/106/guardedStance,heavyStrike,drainingMist",
                "74/150/guardedStance,guardedStance,heavyStrike,drainingMist",
                "42/84/drainingMist,heavyStrike,drainingMist,guardedStance",
                "54/110/heavyStrike,drainingMist,guardedStance,drainingMist",
                "78/158/drainingMist,heavyStrike,guardedStance,drainingMist",
            ]
        )
        for route in AdventureExpeditionRoute.allCases {
            XCTAssertTrue(
                route.expeditionPlan.stages.allSatisfy {
                    AdventureExpeditionRoute.route(
                        for: $0.encounter.id
                    ) == route
                }
            )
            XCTAssertTrue(route.isUnlocked(at: route.minimumLevel))
            if route.minimumLevel > 1 {
                XCTAssertFalse(
                    route.isUnlocked(at: route.minimumLevel - 1)
                )
            }
        }
    }

    func testLockedRouteCanBePreviewedButCannotStart() {
        let context = rewardContext()
        defer { context.cleanup() }
        let center = AdventureExpeditionCenter(rewardStore: context.store)
        center.replaceDraftCandidates(partyCandidates())
        center.setDraftRoute(.dawnGarden)

        XCTAssertEqual(center.draftRoute, .dawnGarden)
        XCTAssertFalse(center.isRouteUnlocked(.dawnGarden))
        XCTAssertFalse(center.canStartDraft)
        XCTAssertFalse(
            center.startDraft(
                seed: 1,
                plan: easyPlan(routeID: "dawnGarden"),
                runID: "locked-route"
            )
        )
        XCTAssertNil(center.state)
    }

    func testLevelUnlockAndRoutePlanIdentityAreEnforced() {
        let context = rewardContext()
        defer { context.cleanup() }
        context.store.apply(
            AdventurePermanentReward(
                grantID: "level-seed",
                routeID: "sunlitTrail",
                adventureXP: 250,
                routeStampDelta: 0,
                bondGains: []
            )
        )
        let center = AdventureExpeditionCenter(rewardStore: context.store)
        center.replaceDraftCandidates(partyCandidates())
        center.setDraftRoute(.dawnGarden)

        XCTAssertTrue(center.isRouteUnlocked(.dawnGarden))
        XCTAssertTrue(center.canStartDraft)
        XCTAssertFalse(
            center.startDraft(
                seed: 1,
                plan: easyPlan(routeID: "sunlitTrail"),
                runID: "mismatched-route"
            )
        )
        XCTAssertTrue(
            center.startDraft(
                seed: 1,
                plan: easyPlan(routeID: "dawnGarden"),
                runID: "unlocked-route"
            )
        )
    }

    func testAuthoredRouteDifficultyBandsRemainPlayable() throws {
        for route in AdventureExpeditionRoute.allCases {
            for grade in [AdventureGrade.s, .b, .d] {
                let team = try AdventureParty(
                    members: [
                        AdventureCat(
                            id: "guardian",
                            role: .guardian,
                            affinity: route.affinity,
                            passive: .steady,
                            grade: grade
                        ),
                        AdventureCat(
                            id: "striker",
                            role: .striker,
                            affinity: route.affinity,
                            passive: .opportunist,
                            grade: grade
                        ),
                        AdventureCat(
                            id: "support",
                            role: .support,
                            affinity: route.affinity,
                            passive: .focused,
                            grade: grade
                        ),
                    ]
                )
                let victories = (UInt64(0)..<32).filter { seed in
                    playAuthoredRoute(route, party: team, seed: seed)
                        == .completed
                }.count

                XCTAssertGreaterThan(
                    victories,
                    0,
                    "\(route.rawValue) is unwinnable for a balanced matching-affinity \(grade.rawValue)-grade party"
                )
                if grade == .s {
                    let expectedBand: ClosedRange<Int>
                    switch route.difficulty {
                    case .easy: expectedBand = 24...32
                    case .normal: expectedBand = 16...31
                    case .hard: expectedBand = 6...20
                    case .expert: expectedBand = 1...9
                    }
                    XCTAssertTrue(
                        expectedBand.contains(victories),
                        "\(route.rawValue) won \(victories)/32 seeds outside its \(route.difficulty.rawValue) band \(expectedBand)"
                    )
                }
            }
        }
    }

    func testCompletedRewardPersistsAndCannotBeGrantedTwice() throws {
        let context = rewardContext()
        defer { context.cleanup() }
        let center = AdventureExpeditionCenter(
            rewardStore: context.store
        )
        XCTAssertTrue(
            center.start(
                candidates: partyCandidates(),
                route: .sunlitTrail,
                seed: 17,
                plan: easyPlan(routeID: "sunlitTrail"),
                runID: "one-grant"
            )
        )

        try playToFinish(center)
        let result = try XCTUnwrap(center.state?.result)
        XCTAssertEqual(result.status, .completed)
        XCTAssertGreaterThan(result.adventureXP, 0)
        XCTAssertEqual(
            center.rewardProgress.adventureXP,
            result.adventureXP
        )
        XCTAssertEqual(
            center.rewardProgress.stampCount(for: "sunlitTrail"),
            1
        )
        XCTAssertEqual(center.rewardProgress.completedRuns, 1)

        center.withdraw()
        XCTAssertEqual(
            center.rewardProgress.adventureXP,
            result.adventureXP
        )
        XCTAssertEqual(center.rewardProgress.completedRuns, 1)

        let reloaded = AdventureRewardStore(
            defaults: context.defaults,
            key: context.key
        )
        XCTAssertEqual(reloaded.progress, center.rewardProgress)
        XCTAssertFalse(reloaded.apply(result.reward))
        XCTAssertEqual(reloaded.progress.completedRuns, 1)
    }

    func testTwoViewsSubmittingTheFinalTurnGrantOnlyOnceAndRetryIsStaleSafe() throws {
        let context = rewardContext()
        defer { context.cleanup() }
        let center = AdventureExpeditionCenter(
            rewardStore: context.store
        )
        let plan = easyPlan(routeID: "sunlitTrail")
        center.replaceDraftCandidates(partyCandidates())
        center.setDraftRoute(.sunlitTrail)

        XCTAssertTrue(
            center.startDraft(
                seed: 31,
                plan: plan,
                runID: "reward-run"
            )
        )

        _ = try advanceToRelicOffer(center)
        try chooseFirstCurrentRelic(center)
        _ = try advanceToRelicOffer(center)
        try chooseFirstCurrentRelic(center)

        let bossState = try XCTUnwrap(center.state)
        XCTAssertEqual(bossState.stageIndex, 2)
        let actor = try counterCatID(in: bossState)

        XCTAssertTrue(
            center.basicAttack(
                catID: actor,
                expectedTurn: bossState.turnToken
            )
        )
        XCTAssertFalse(
            center.basicAttack(
                catID: actor,
                expectedTurn: bossState.turnToken
            )
        )
        let result = try XCTUnwrap(center.state?.result)
        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(center.rewardProgress.completedRuns, 1)
        XCTAssertEqual(
            center.rewardProgress.adventureXP,
            result.adventureXP
        )

        XCTAssertTrue(
            center.retryDraft(
                expectedRunID: "reward-run",
                seed: 37,
                plan: plan,
                runID: "retry-run"
            )
        )
        let retryState = try XCTUnwrap(center.state)
        XCTAssertEqual(retryState.runID, "retry-run")
        XCTAssertEqual(
            retryState.party.members.map(\.id),
            center.draftSelectedIDs
        )

        XCTAssertFalse(
            center.retryDraft(
                expectedRunID: "reward-run",
                seed: 41,
                plan: plan,
                runID: "stale-retry"
            )
        )
        XCTAssertFalse(center.reset(expectedRunID: "reward-run"))
        XCTAssertFalse(center.withdraw(expectedRunID: "reward-run"))
        XCTAssertEqual(center.state, retryState)
        XCTAssertEqual(center.rewardProgress.completedRuns, 1)
    }

    func testResetReleasesRunSnapshotsButKeepsAdventureProgress() throws {
        let context = rewardContext()
        defer { context.cleanup() }
        let center = AdventureExpeditionCenter(
            rewardStore: context.store
        )
        XCTAssertTrue(
            center.start(
                candidates: partyCandidates(),
                route: .midnightArchive,
                seed: 19,
                plan: easyPlan(routeID: "midnightArchive"),
                runID: "reset-run"
            )
        )
        try playToFinish(center)
        let earnedXP = center.rewardProgress.adventureXP

        center.reset()
        center.reset()

        XCTAssertNil(center.state)
        XCTAssertNil(center.route)
        XCTAssertTrue(center.candidates.isEmpty)
        XCTAssertTrue(center.turnHistory.isEmpty)
        XCTAssertEqual(center.rewardProgress.adventureXP, earnedXP)
        XCTAssertFalse(center.isUpdateScheduled)
    }

    func testTurnBasedSourcesKeepPrivacyAndSchedulingBoundaryNarrow() throws {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let paths = [
            "Sources/PawprintCore/Adventure/AdventureExpeditionEngine.swift",
            "Sources/Pawprint/Adventure/AdventureExpeditionCenter.swift",
            "Sources/Pawprint/UI/Adventure/AdventureExpeditionHUDView.swift",
            "Sources/Pawprint/UI/Adventure/AdventureExpeditionDetailView.swift",
        ]
        let bannedPrivacyAPIs = [
            "URLSession",
            "URLRequest",
            "NSPasteboard",
            "addGlobalMonitor",
            "AXUIElement",
            "NSWorkspace",
            "PawprintStore",
            "Process(",
        ]

        for path in paths {
            let source = try String(
                contentsOf: repository.appendingPathComponent(path),
                encoding: .utf8
            )
            for banned in bannedPrivacyAPIs {
                XCTAssertFalse(
                    source.contains(banned),
                    "\(path) must not reference \(banned)"
                )
            }
        }

        let centerSource = try String(
            contentsOf: repository.appendingPathComponent(paths[1]),
            encoding: .utf8
        )
        for scheduler in [
            "Timer(",
            "scheduledTimer",
            "RunLoop.",
            "DispatchSource",
            "Task.sleep",
        ] {
            XCTAssertFalse(
                centerSource.contains(scheduler),
                "The turn center must not schedule \(scheduler)"
            )
        }
    }

    private func playToFinish(
        _ center: AdventureExpeditionCenter
    ) throws {
        for _ in 0..<40 {
            let state = try XCTUnwrap(center.state)
            switch state.phase {
            case .awaitingTurn:
                let actor = try counterCatID(in: state)
                if state.mana > 0 {
                    center.useSkill(
                        catID: actor,
                        expectedTurn: state.turnToken
                    )
                } else {
                    center.basicAttack(
                        catID: actor,
                        expectedTurn: state.turnToken
                    )
                }
            case let .choosingRelic(offer):
                center.choose(relic: try XCTUnwrap(offer.options.first))
            case .finished:
                return
            }
        }
        XCTFail("The deterministic easy run did not finish")
    }

    private func advanceToRelicOffer(
        _ center: AdventureExpeditionCenter
    ) throws -> AdventureRelicOffer {
        let state = try XCTUnwrap(center.state)
        XCTAssertEqual(state.phase, .awaitingTurn)
        let actor = try counterCatID(in: state)
        XCTAssertTrue(
            center.basicAttack(
                catID: actor,
                expectedTurn: state.turnToken
            )
        )
        let next = try XCTUnwrap(center.state)
        guard case let .choosingRelic(offer) = next.phase else {
            throw CenterTestError.expectedRelicOffer
        }
        return offer
    }

    private func chooseFirstCurrentRelic(
        _ center: AdventureExpeditionCenter
    ) throws {
        let state = try XCTUnwrap(center.state)
        guard case let .choosingRelic(offer) = state.phase else {
            throw CenterTestError.expectedRelicOffer
        }
        XCTAssertTrue(
            center.choose(
                relic: try XCTUnwrap(offer.options.first),
                expectedRunID: state.runID,
                expectedOffer: offer
            )
        )
    }

    private func counterCatID(
        in state: AdventureExpeditionState
    ) throws -> String {
        try XCTUnwrap(
            state.party.members.first {
                $0.role == state.battle.currentIntent.counterRole
            }?.id
        )
    }

    private func playAuthoredRoute(
        _ route: AdventureExpeditionRoute,
        party: AdventureParty,
        seed: UInt64
    ) -> AdventureExpeditionResultStatus? {
        var state = AdventureExpeditionEngine.begin(
            party: party,
            plan: route.expeditionPlan,
            seed: seed,
            runID: "balance-\(route.rawValue)-\(seed)"
        )
        let relicPriority: [AdventureExpeditionRelic] = [
            .sharpenedClaw,
            .manaBell,
            .paddedCape,
            .echoCharm,
            .healingHerb,
            .warmTea,
        ]

        while state.result == nil {
            let command: AdventureExpeditionCommand
            switch state.phase {
            case .awaitingTurn:
                guard let actor = state.party.members.first(
                    where: {
                        $0.role == state.battle.currentIntent.counterRole
                    }
                ) else {
                    return nil
                }
                command = state.mana > 0
                    ? .perform(.roleSkill(catID: actor.id))
                    : .perform(.basicAttack(catID: actor.id))
            case let .choosingRelic(offer):
                guard let relic = relicPriority.first(
                    where: { offer.options.contains($0) }
                ) else {
                    return nil
                }
                command = .chooseRelic(relic)
            case .finished:
                return state.result?.status
            }

            let transition = AdventureExpeditionEngine.reduce(
                command,
                in: state
            )
            guard transition.disposition == .accepted else { return nil }
            state = transition.state
        }
        return state.result?.status
    }

    private func easyPlan(
        routeID: String
    ) -> AdventureExpeditionPlan {
        plan(routeID: routeID, power: 1)
    }

    private func harderPlan(
        routeID: String
    ) -> AdventureExpeditionPlan {
        plan(routeID: routeID, power: 100)
    }

    private func plan(
        routeID: String,
        power: Int
    ) -> AdventureExpeditionPlan {
        AdventureExpeditionPlan(
            routeID: routeID,
            firstEncounter: AdventureEncounter(
                id: "\(routeID)-one",
                affinity: .morning,
                power: power
            ),
            secondEncounter: AdventureEncounter(
                id: "\(routeID)-two",
                affinity: .evening,
                power: power
            ),
            bossEncounter: AdventureEncounter(
                id: "\(routeID)-boss",
                affinity: .night,
                power: power
            )
        )
    }

    private func partyCandidates() -> [PawpetAdventureCandidate] {
        [
            candidate("2026-07-01", role: .guardian),
            candidate("2026-07-02", role: .striker),
            candidate("2026-07-03", role: .support),
        ]
    }

    private func candidate(
        _ id: String,
        role: AdventureRole
    ) -> PawpetAdventureCandidate {
        PawpetAdventureCandidate(
            summary: DailySummary(day: id),
            streakDays: 1,
            profile: AdventureCat(
                id: id,
                role: role,
                affinity: .morning,
                passive: .steady,
                grade: .b
            )
        )
    }

    private func rewardContext() -> RewardTestContext {
        let suiteName =
            "PawprintTests.AdventureRewards.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let key = "progress"
        return RewardTestContext(
            defaults: defaults,
            key: key,
            store: AdventureRewardStore(
                defaults: defaults,
                key: key
            ),
            suiteName: suiteName
        )
    }
}

private enum CenterTestError: Error {
    case expectedRelicOffer
}

@MainActor
private struct RewardTestContext {
    let defaults: UserDefaults
    let key: String
    let store: AdventureRewardStore
    let suiteName: String

    func cleanup() {
        defaults.removePersistentDomain(forName: suiteName)
    }
}
