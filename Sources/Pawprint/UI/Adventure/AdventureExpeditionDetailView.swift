import SwiftUI
import PawprintCore

/// Full companion view for the same event-driven run shown in the floating HUD.
@MainActor
struct AdventureExpeditionDetailView: View {
    @Bindable private var expedition = AdventureExpeditionCenter.shared
    @Bindable private var localization = LocalizationManager.shared

    @State private var selectedCatID: String?
    @State private var withdrawRunID: String?
    @State private var showingWithdrawConfirmation = false

    @Environment(\.accessibilityDifferentiateWithoutColor)
    private var differentiateWithoutColor

    var body: some View {
        let _ = localization.revision

        VStack(spacing: 0) {
            header
            Divider()

            if let state = expedition.state {
                ScrollView {
                    HStack(alignment: .top, spacing: 18) {
                        overviewColumn(state)
                            .frame(maxWidth: .infinity, alignment: .top)
                        actionColumn(state)
                            .frame(maxWidth: .infinity, alignment: .top)
                    }
                    .padding(18)
                }
            } else {
                missingState
            }
        }
        .confirmationDialog(
            L10n.t(
                "adventure.expedition.detail.withdrawConfirmTitle"
            ),
            isPresented: $showingWithdrawConfirmation
        ) {
            Button(
                L10n.t(
                    "adventure.expedition.detail.withdrawConfirm"
                ),
                role: .destructive
            ) {
                if let withdrawRunID {
                    expedition.withdraw(expectedRunID: withdrawRunID)
                }
                self.withdrawRunID = nil
            }
            Button(
                L10n.t(
                    "adventure.expedition.detail.withdrawCancel"
                ),
                role: .cancel
            ) {
                withdrawRunID = nil
            }
        } message: {
            Text(
                L10n.t(
                    "adventure.expedition.detail.withdrawConfirmBody"
                )
            )
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(routeColor.opacity(0.16))
                Image(
                    systemName: expedition.route?.systemImage ?? "map.fill"
                )
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(routeColor)
            }
            .frame(width: 48, height: 48)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.t("adventure.expedition.detail.title"))
                    .font(.title2.weight(.bold))
                Text(
                    expedition.route.map { L10n.t($0.titleKey) }
                        ?? L10n.t("adventure.expedition.hud.title")
                )
                .font(.callout)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(
                    L10n.t(
                        "adventure.expedition.progress.level",
                        expedition.rewardProgress.level
                    )
                )
                .font(.callout.weight(.bold))
                Text(
                    L10n.t(
                        "adventure.expedition.progress.totalXP",
                        expedition.rewardProgress.adventureXP
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Button {
                AdventureExpeditionHUDController.shared.show()
            } label: {
                Label(
                    L10n.t("adventure.expedition.detail.showHUD"),
                    systemImage:
                        "rectangle.inset.filled.and.person.filled"
                )
            }
            .buttonStyle(.bordered)
        }
        .padding(18)
    }

    private func overviewColumn(
        _ state: AdventureExpeditionState
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            partyCard(state)
            runStatusCard(state)
            relicCollectionCard(state)
            progressionCard
        }
    }

    private func actionColumn(
        _ state: AdventureExpeditionState
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            phaseCard(state)
            combatLogCard

            if state.result == nil {
                Button(role: .destructive) {
                    withdrawRunID = state.runID
                    showingWithdrawConfirmation = true
                } label: {
                    Label(
                        L10n.t(
                            "adventure.expedition.detail.withdraw"
                        ),
                        systemImage: "stop.circle"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func partyCard(
        _ state: AdventureExpeditionState
    ) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionTitle(
                L10n.t("adventure.expedition.detail.party"),
                systemImage: "pawprint.fill"
            )

            HStack(spacing: 10) {
                ForEach(state.party.members) { cat in
                    VStack(spacing: 5) {
                        candidatePortrait(cat, size: 66)
                        Label(
                            AdventureExpeditionPresentation
                                .roleName(cat.role),
                            systemImage:
                                AdventureExpeditionPresentation
                                    .roleIcon(cat.role)
                        )
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(
                            AdventureExpeditionPresentation
                                .roleColor(cat.role)
                        )
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .cardSurface()
    }

    private func runStatusCard(
        _ state: AdventureExpeditionState
    ) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                sectionTitle(
                    L10n.t("adventure.expedition.detail.progress"),
                    systemImage: "flag.checkered"
                )
                Spacer()
                Text(
                    L10n.t(
                        "adventure.expedition.hud.stage",
                        state.stageIndex + 1,
                        3
                    )
                )
                .font(.callout.weight(.bold).monospacedDigit())
            }

            ProgressView(value: expedition.progress)
                .tint(routeColor)

            healthRow(
                icon: "heart.fill",
                color: .green,
                value: state.battle.partyHealth,
                maximum: state.party.maxHealth,
                title: L10n.t(
                    "adventure.expedition.detail.partyHealth"
                )
            )

            HStack {
                Text(L10n.t("adventure.expedition.detail.mana"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                manaPips(state)
            }

            HStack(spacing: 7) {
                ForEach(0..<3, id: \.self) { index in
                    HStack(spacing: 4) {
                        Image(
                            systemName:
                                index < 2
                                    ? "shield.lefthalf.filled"
                                    : "crown.fill"
                        )
                        Text(
                            L10n.t(
                                "adventure.expedition.detail.stageNumber",
                                index + 1
                            )
                        )
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(
                        index <= state.stageIndex
                            ? routeColor
                            : Color.secondary.opacity(0.45)
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(
                            index == state.stageIndex
                                ? routeColor.opacity(0.12)
                                : Color.secondary.opacity(0.05)
                        )
                    )
                }
            }
        }
        .cardSurface()
    }

    private func relicCollectionCard(
        _ state: AdventureExpeditionState
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionTitle(
                L10n.t("adventure.expedition.detail.relics"),
                systemImage: "shippingbox.fill"
            )

            if state.relics.isEmpty {
                Text(
                    L10n.t("adventure.expedition.detail.relicsEmpty")
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                ForEach(state.relics, id: \.self) { relic in
                    HStack(spacing: 8) {
                        Image(
                            systemName:
                                AdventureExpeditionPresentation
                                    .relicIcon(relic)
                        )
                        .foregroundStyle(Color.accentColor)
                        Text(
                            AdventureExpeditionPresentation
                                .relicName(relic)
                        )
                        .font(.caption.weight(.semibold))
                        Spacer()
                    }
                }
            }
        }
        .cardSurface()
    }

    private var progressionCard: some View {
        let progress = expedition.rewardProgress
        let stampCount = expedition.route.map {
            progress.stampCount(for: $0.rawValue)
        } ?? 0

        return VStack(alignment: .leading, spacing: 9) {
            sectionTitle(
                L10n.t("adventure.expedition.progress.title"),
                systemImage: "seal.fill"
            )

            HStack {
                Text(
                    L10n.t(
                        "adventure.expedition.progress.level",
                        progress.level
                    )
                )
                .font(.callout.weight(.bold))
                Spacer()
                Text(
                    "\(progress.experienceWithinLevel)/\(progress.experiencePerLevel) XP"
                )
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }

            ProgressView(
                value: Double(progress.experienceWithinLevel),
                total: Double(progress.experiencePerLevel)
            )
            .tint(Color.accentColor)

            Label(
                L10n.t(
                    "adventure.expedition.progress.routeStamps",
                    stampCount
                ),
                systemImage: "pawprint.fill"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .cardSurface(accent: Color.accentColor)
    }

    @ViewBuilder
    private func phaseCard(
        _ state: AdventureExpeditionState
    ) -> some View {
        if let result = state.result {
            resultCard(result, runID: state.runID)
        } else {
            switch state.phase {
            case .awaitingTurn:
                battleCard(state)
            case let .choosingRelic(offer):
                relicChoiceCard(offer, state: state)
            case .finished:
                resultFallback
            }
        }
    }

    private func battleCard(
        _ state: AdventureExpeditionState
    ) -> some View {
        let actor = selectedCat(in: state)
        let intent = state.battle.currentIntent
        let turnToken = state.turnToken
        let intentColor =
            AdventureExpeditionPresentation.intentColor(intent)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(
                    AdventureExpeditionPresentation.encounterName(
                        encounterID: state.battle.encounter.id,
                        stageIndex: state.stageIndex,
                        kind: state.currentStage.kind
                    ),
                    systemImage:
                        state.currentStage.kind == .boss
                            ? "crown.fill"
                            : "sparkles"
                )
                .font(.headline)
                Spacer()
                Text(
                    L10n.t(
                        "adventure.expedition.hud.turn",
                        state.battle.round
                    )
                )
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
            }

            healthRow(
                icon: "burst.fill",
                color: intentColor,
                value: state.battle.enemyHealth,
                maximum: state.battle.initialEnemyHealth,
                title: L10n.t(
                    "adventure.expedition.detail.enemyHealth"
                )
            )

            Label(
                L10n.t(
                    "adventure.expedition.hud.intent",
                    AdventureExpeditionPresentation.intentName(intent)
                ),
                systemImage:
                    AdventureExpeditionPresentation.intentIcon(intent)
            )
            .font(.callout.weight(.semibold))
            .foregroundStyle(intentColor)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Capsule().fill(intentColor.opacity(0.11)))

            Text(L10n.t("adventure.expedition.detail.chooseActor"))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(state.party.members) { cat in
                    detailCatButton(cat, state: state)
                }
            }

            HStack(spacing: 8) {
                Button {
                    expedition.basicAttack(
                        catID: actor.id,
                        expectedTurn: turnToken
                    )
                } label: {
                    Label(
                        L10n.t(
                            "adventure.expedition.action.basic"
                        ),
                        systemImage: "pawprint.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    expedition.useSkill(
                        catID: actor.id,
                        expectedTurn: turnToken
                    )
                } label: {
                    Label(
                        AdventureExpeditionPresentation
                            .skillName(actor.role),
                        systemImage:
                            AdventureExpeditionPresentation
                                .roleIcon(actor.role)
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(state.mana == 0)
            }

            Text(
                state.mana == 0
                    ? L10n.t(
                        "adventure.expedition.action.noMana"
                    )
                    : L10n.t(
                        "adventure.expedition.detail.actionHint"
                    )
            )
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(accent: intentColor)
    }

    private func detailCatButton(
        _ cat: AdventureCat,
        state: AdventureExpeditionState
    ) -> some View {
        let selected = selectedCat(in: state).id == cat.id
        let counters =
            cat.role == state.battle.currentIntent.counterRole
        let color = AdventureExpeditionPresentation.roleColor(cat.role)

        return Button {
            selectedCatID = cat.id
        } label: {
            VStack(spacing: 5) {
                candidatePortrait(cat, size: 43)
                Text(
                    AdventureExpeditionPresentation.roleName(cat.role)
                )
                .font(.caption2.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 70)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        selected
                            ? color.opacity(0.15)
                            : Color.secondary.opacity(0.06)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        selected || counters
                            ? color
                            : Color.secondary.opacity(0.16),
                        lineWidth:
                            selected || (counters && differentiateWithoutColor)
                                ? 2
                                : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            AdventureExpeditionPresentation.roleName(cat.role)
        )
        .accessibilityHint(
            counters
                ? L10n.t(
                    "adventure.expedition.hud.roleChoiceCounterHint"
                )
                : L10n.t(
                    "adventure.expedition.hud.roleChoiceHint"
                )
        )
    }

    private func relicChoiceCard(
        _ offer: AdventureRelicOffer,
        state: AdventureExpeditionState
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(
                L10n.t("adventure.expedition.relic.choose"),
                systemImage: "shippingbox.fill"
            )

            Text(
                L10n.t(
                    "adventure.expedition.relic.chooseCaption",
                    state.stageIndex + 1
                )
            )
            .font(.callout)
            .foregroundStyle(.secondary)

            ForEach(offer.options, id: \.self) { relic in
                Button {
                    expedition.choose(
                        relic: relic,
                        expectedRunID: state.runID,
                        expectedOffer: offer
                    )
                } label: {
                    HStack(spacing: 11) {
                        Image(
                            systemName:
                                AdventureExpeditionPresentation
                                    .relicIcon(relic)
                        )
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(
                                AdventureExpeditionPresentation
                                    .relicName(relic)
                            )
                            .font(.callout.weight(.bold))
                            Text(
                                AdventureExpeditionPresentation
                                    .relicDescription(relic)
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                    }
                    .padding(9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(
                            cornerRadius: 10,
                            style: .continuous
                        )
                        .fill(Color.secondary.opacity(0.07))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(accent: Color.accentColor)
    }

    private func resultCard(
        _ result: AdventureExpeditionResult,
        runID: String
    ) -> some View {
        let color =
            AdventureExpeditionPresentation.resultColor(result.status)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text(result.rank.rawValue)
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(color)
                    .frame(width: 55, height: 55)
                    .background(Circle().fill(color.opacity(0.13)))

                VStack(alignment: .leading, spacing: 3) {
                    Text(
                        AdventureExpeditionPresentation
                            .resultTitle(result.status)
                    )
                    .font(.title3.weight(.bold))
                    Text(
                        L10n.t(
                            "adventure.expedition.result.score",
                            result.rankScore
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                resultMetric(
                    L10n.t("adventure.expedition.result.xp"),
                    "+\(result.adventureXP)"
                )
                resultMetric(
                    L10n.t("adventure.expedition.result.stamp"),
                    "+\(result.routeStampDelta)"
                )
                resultMetric(
                    L10n.t("adventure.expedition.result.counters"),
                    "\(result.counteredTurnCount)/\(result.totalTurnCount)"
                )
            }

            Text(
                L10n.t(
                    "adventure.expedition.result.persistenceNotice"
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            Button {
                expedition.reset(expectedRunID: runID)
            } label: {
                Label(
                    L10n.t(
                        "adventure.expedition.detail.changeParty"
                    ),
                    systemImage: "person.3.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(accent: color)
    }

    private var combatLogCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionTitle(
                L10n.t("adventure.expedition.detail.history"),
                systemImage: "list.bullet.clipboard"
            )

            if expedition.turnHistory.isEmpty {
                Text(
                    L10n.t(
                        "adventure.expedition.detail.historyEmpty"
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                ForEach(
                    Array(
                        expedition.turnHistory
                            .suffix(6)
                            .reversed()
                            .enumerated()
                    ),
                    id: \.offset
                ) { _, resolution in
                    turnRow(resolution)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private func turnRow(
        _ resolution: AdventureExpeditionTurnResolution
    ) -> some View {
        let combat = resolution.combat
        let color =
            AdventureExpeditionPresentation.roleColor(combat.actorRole)
        let actionName = combat.action.isRoleSkill
            ? AdventureExpeditionPresentation.skillName(combat.actorRole)
            : L10n.t("adventure.expedition.action.basic")

        return HStack(spacing: 9) {
            Image(
                systemName:
                    combat.counteredIntent
                        ? "checkmark.circle.fill"
                        : "circle.fill"
            )
            .foregroundStyle(
                combat.counteredIntent ? Color.green : color
            )
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(
                    L10n.t(
                        "adventure.expedition.detail.historyEntry",
                        resolution.stageIndex + 1,
                        combat.round,
                        actionName
                    )
                )
                .font(.caption.weight(.semibold))

                Text(
                    L10n.t(
                        "adventure.expedition.hud.lastTurn",
                        combat.damageDealt,
                        combat.damageReceived,
                        combat.healing
                    )
                )
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(resolution.manaBefore)→\(resolution.manaAfter)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.cyan)
        }
        .accessibilityElement(children: .combine)
    }

    private func healthRow(
        icon: String,
        color: Color,
        value: Int,
        maximum: Int,
        title: String
    ) -> some View {
        HStack(spacing: 7) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 74, alignment: .leading)
            ProgressView(
                value: Double(value),
                total: Double(maximum)
            )
            .tint(color)
            Text("\(value)/\(maximum)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func manaPips(
        _ state: AdventureExpeditionState
    ) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<state.maximumMana, id: \.self) { index in
                Image(
                    systemName:
                        index < state.mana ? "diamond.fill" : "diamond"
                )
                .foregroundStyle(
                    index < state.mana
                        ? Color.cyan
                        : Color.secondary.opacity(0.35)
                )
            }
        }
        .font(.system(size: 11, weight: .bold))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            L10n.t(
                "adventure.expedition.hud.mana",
                state.mana,
                state.maximumMana
            )
        )
    }

    @ViewBuilder
    private func candidatePortrait(
        _ cat: AdventureCat,
        size: CGFloat
    ) -> some View {
        if let candidate = expedition.candidates.first(
            where: { $0.id == cat.id }
        ) {
            PawpetView(
                summary: candidate.summary,
                size: size,
                streakDays: candidate.streakDays,
                showsAura: false
            )
            .accessibilityHidden(true)
        } else {
            Image(
                systemName:
                    AdventureExpeditionPresentation.roleIcon(cat.role)
            )
            .frame(width: size, height: size)
            .background(Circle().fill(Color.secondary.opacity(0.10)))
            .accessibilityHidden(true)
        }
    }

    private func selectedCat(
        in state: AdventureExpeditionState
    ) -> AdventureCat {
        if let selectedCatID,
           let selected = state.party.members.first(
               where: { $0.id == selectedCatID }
           ) {
            return selected
        }
        return state.party.members[0]
    }

    private func resultMetric(
        _ title: String,
        _ value: String
    ) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.secondary.opacity(0.07))
        )
    }

    private func sectionTitle(
        _ title: String,
        systemImage: String
    ) -> some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
    }

    private var resultFallback: some View {
        Text(L10n.t("adventure.expedition.result.completed"))
            .font(.headline)
            .frame(maxWidth: .infinity)
            .cardSurface()
    }

    private var missingState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "map")
                .font(.system(size: 38))
                .foregroundStyle(.tertiary)
            Text(L10n.t("adventure.expedition.hud.idleTitle"))
                .font(.title3.weight(.semibold))
            Button {
                expedition.reset()
            } label: {
                Text(
                    L10n.t(
                        "adventure.expedition.detail.changeParty"
                    )
                )
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
    }

    private var routeColor: Color {
        expedition.route?.color ?? .accentColor
    }
}

private extension View {
    func cardSurface(accent: Color? = nil) -> some View {
        padding(13)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.secondary.opacity(0.06))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        (accent ?? Color.secondary)
                            .opacity(accent == nil ? 0.13 : 0.28),
                        lineWidth: 1
                    )
            }
    }
}
