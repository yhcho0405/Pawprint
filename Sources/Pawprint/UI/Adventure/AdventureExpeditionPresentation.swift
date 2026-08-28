import SwiftUI
import PawprintCore

enum AdventureExpeditionPresentation {
    /// Keeps the center's party/recommendation order untouched while presenting rarity from
    /// highest to lowest. Enumerated offsets make equal-grade ordering explicitly stable; the
    /// catalog already supplies those cats newest-first.
    static func gradeSortedCandidates(
        _ candidates: [PawpetAdventureCandidate]
    ) -> [PawpetAdventureCandidate] {
        candidates.enumerated()
            .sorted { lhs, rhs in
                let lhsRank = gradeRank(lhs.element.profile.grade)
                let rhsRank = gradeRank(rhs.element.profile.grade)
                if lhsRank != rhsRank {
                    return lhsRank < rhsRank
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    private static func gradeRank(_ grade: AdventureGrade) -> Int {
        switch grade {
        case .s: return 0
        case .a: return 1
        case .b: return 2
        case .c: return 3
        case .d: return 4
        }
    }

    static func roleName(_ role: AdventureRole) -> String {
        switch role {
        case .guardian: return L10n.t("adventure.role.guardian")
        case .striker: return L10n.t("adventure.role.striker")
        case .support: return L10n.t("adventure.role.support")
        }
    }

    static func roleIcon(_ role: AdventureRole) -> String {
        switch role {
        case .guardian: return "shield.fill"
        case .striker: return "bolt.fill"
        case .support: return "heart.fill"
        }
    }

    static func roleColor(_ role: AdventureRole) -> Color {
        switch role {
        case .guardian: return .blue
        case .striker: return .orange
        case .support: return .green
        }
    }

    static func affinityName(_ affinity: AdventureAffinity) -> String {
        switch affinity {
        case .dawn: return L10n.t("adventure.affinity.dawn")
        case .morning: return L10n.t("adventure.affinity.morning")
        case .afternoon: return L10n.t("adventure.affinity.afternoon")
        case .evening: return L10n.t("adventure.affinity.evening")
        case .night: return L10n.t("adventure.affinity.night")
        case .deepNight: return L10n.t("adventure.affinity.deepNight")
        }
    }

    static func passiveName(_ passive: AdventurePassive) -> String {
        switch passive {
        case .steady: return L10n.t("adventure.passive.steady")
        case .resilient: return L10n.t("adventure.passive.resilient")
        case .focused: return L10n.t("adventure.passive.focused")
        case .opportunist: return L10n.t("adventure.passive.opportunist")
        case .alert: return L10n.t("adventure.passive.alert")
        }
    }

    static func skillName(_ role: AdventureRole) -> String {
        switch role {
        case .guardian:
            return L10n.t("adventure.expedition.skill.guardian")
        case .striker:
            return L10n.t("adventure.expedition.skill.striker")
        case .support:
            return L10n.t("adventure.expedition.skill.support")
        }
    }

    static func intentName(_ intent: AdventureEnemyIntent) -> String {
        switch intent {
        case .heavyStrike:
            return L10n.t(
                "adventure.battle.intent.heavyStrike.name"
            )
        case .guardedStance:
            return L10n.t(
                "adventure.battle.intent.guardedStance.name"
            )
        case .drainingMist:
            return L10n.t(
                "adventure.battle.intent.drainingMist.name"
            )
        }
    }

    static func intentIcon(_ intent: AdventureEnemyIntent) -> String {
        switch intent {
        case .heavyStrike: return "burst.fill"
        case .guardedStance: return "shield.lefthalf.filled"
        case .drainingMist: return "cloud.fog.fill"
        }
    }

    static func intentColor(_ intent: AdventureEnemyIntent) -> Color {
        switch intent {
        case .heavyStrike: return .red
        case .guardedStance: return .blue
        case .drainingMist: return .purple
        }
    }

    static func encounterName(
        encounterID: String,
        stageIndex: Int,
        kind: AdventureExpeditionStageKind
    ) -> String {
        if let route = AdventureExpeditionRoute.route(for: encounterID) {
            return L10n.t(route.enemyNameKey(stageIndex: stageIndex))
        }
        if kind == .boss {
            return L10n.t("adventure.expedition.enemy.boss")
        }
        return stageIndex == 0
            ? L10n.t("adventure.expedition.enemy.scout")
            : L10n.t("adventure.expedition.enemy.rival")
    }

    static func relicName(_ relic: AdventureExpeditionRelic) -> String {
        L10n.t("adventure.expedition.relic.\(relic.rawValue).name")
    }

    static func relicDescription(
        _ relic: AdventureExpeditionRelic
    ) -> String {
        L10n.t(
            "adventure.expedition.relic.\(relic.rawValue).description"
        )
    }

    static func relicIcon(_ relic: AdventureExpeditionRelic) -> String {
        switch relic {
        case .sharpenedClaw: return "pawprint.fill"
        case .paddedCape: return "shield.fill"
        case .manaBell: return "bell.fill"
        case .warmTea: return "cup.and.saucer.fill"
        case .echoCharm: return "wave.3.right.circle.fill"
        case .healingHerb: return "leaf.fill"
        }
    }

    static func routeSelectionName(
        _ route: AdventureExpeditionRoute,
        adventureLevel: Int
    ) -> String {
        let title = L10n.t(route.titleKey)
        guard !route.isUnlocked(at: adventureLevel) else { return title }
        return L10n.t(
            "adventure.expedition.route.lockedName",
            title,
            route.minimumLevel
        )
    }

    static func routeOverview(_ route: AdventureExpeditionRoute) -> String {
        L10n.t(
            "adventure.expedition.route.overview",
            affinityName(route.affinity),
            L10n.t(route.difficulty.titleKey),
            route.minimumLevel,
            intentName(route.featuredIntent)
        )
    }

    static func routeReward(_ route: AdventureExpeditionRoute) -> String {
        guard route.rewardMultiplierPercent > 100 else {
            return L10n.t("adventure.expedition.route.baseXP")
        }
        return L10n.t(
            "adventure.expedition.route.bonusXP",
            route.rewardMultiplierPercent - 100
        )
    }

    static func routeUnlockRequirement(
        _ route: AdventureExpeditionRoute
    ) -> String {
        L10n.t(
            "adventure.expedition.route.unlockLevel",
            route.minimumLevel
        )
    }

    static func resultTitle(
        _ status: AdventureExpeditionResultStatus
    ) -> String {
        switch status {
        case .completed:
            return L10n.t("adventure.expedition.result.completed")
        case .defeated:
            return L10n.t("adventure.expedition.result.defeated")
        case .withdrew:
            return L10n.t("adventure.expedition.result.withdrew")
        }
    }

    static func resultColor(
        _ status: AdventureExpeditionResultStatus
    ) -> Color {
        switch status {
        case .completed: return .green
        case .defeated: return .red
        case .withdrew: return .orange
        }
    }
}

extension AdventureExpeditionRoute {
    var color: Color {
        switch self {
        case .sunlitTrail: return .orange
        case .signalRooftops: return .purple
        case .midnightArchive: return .blue
        case .dawnGarden: return .pink
        case .noonStation: return .brown
        case .deepNightLab: return .indigo
        }
    }
}

/// A pull-down route selector shared by the full Adventure window and the floating HUD.
///
/// A menu-style `Picker` maps to an AppKit pop-up button, which aligns the currently selected row
/// with the control. With six routes, choosing a lower row makes the next menu appear to jump
/// upward. `Menu` uses pull-down semantics instead, so its origin stays anchored to the control.
struct AdventureRouteMenu: View {
    @Binding private var selection: AdventureExpeditionRoute
    let adventureLevel: Int
    let showsFieldLabel: Bool

    init(
        selection: Binding<AdventureExpeditionRoute>,
        adventureLevel: Int,
        showsFieldLabel: Bool = false
    ) {
        _selection = selection
        self.adventureLevel = adventureLevel
        self.showsFieldLabel = showsFieldLabel
    }

    var body: some View {
        Group {
            if showsFieldLabel {
                LabeledContent(
                    L10n.t("adventure.expedition.route.label")
                ) {
                    routeMenu
                }
            } else {
                routeMenu
            }
        }
    }

    private var routeMenu: some View {
        Menu {
            ForEach(AdventureExpeditionRoute.allCases) { route in
                Button {
                    selection = route
                } label: {
                    Label(
                        AdventureExpeditionPresentation.routeSelectionName(
                            route,
                            adventureLevel: adventureLevel
                        ),
                        systemImage: itemIcon(for: route)
                    )
                }
            }
        } label: {
            Label(
                AdventureExpeditionPresentation.routeSelectionName(
                    selection,
                    adventureLevel: adventureLevel
                ),
                systemImage: selection.isUnlocked(at: adventureLevel)
                    ? selection.systemImage
                    : "lock.fill"
            )
            .lineLimit(1)
        }
        .accessibilityLabel(
            L10n.t("adventure.expedition.route.label")
        )
        .accessibilityValue(
            AdventureExpeditionPresentation.routeSelectionName(
                selection,
                adventureLevel: adventureLevel
            )
        )
    }

    private func itemIcon(
        for route: AdventureExpeditionRoute
    ) -> String {
        if route == selection { return "checkmark" }
        return route.isUnlocked(at: adventureLevel)
            ? route.systemImage
            : "lock.fill"
    }
}
