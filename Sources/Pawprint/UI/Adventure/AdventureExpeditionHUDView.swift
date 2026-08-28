import SwiftUI
import PawprintCore

/// A compact, non-activating turn board.
///
/// This view owns no timer, task, or perpetual animation. An unanswered turn remains unchanged
/// until the user clicks one of the local controls.
@MainActor
struct AdventureExpeditionHUDView: View {
    @Bindable private var expedition = AdventureExpeditionCenter.shared
    @Bindable private var activityCenter = ActivityCenter.shared
    @Bindable private var hudController =
        AdventureExpeditionHUDController.shared
    @Bindable private var localization = LocalizationManager.shared

    @State private var selectedCatID: String?
    @State private var hoveredDraftCandidateID: String?
    @State private var withdrawRunID: String?
    @State private var showingWithdrawConfirmation = false

    @Environment(\.accessibilityDifferentiateWithoutColor)
    private var differentiateWithoutColor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var colorScheme: ColorScheme? {
        switch activityCenter.settings.theme {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var body: some View {
        let _ = localization.revision

        VStack(spacing: 8) {
            header
            phaseLayout
        }
        .padding(10)
        .frame(
            width: hudController.currentContentSize.width,
            height: hudController.currentContentSize.height
        )
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color.primary.opacity(0.14), lineWidth: 1)
        )
        .opacity(max(0.65, activityCenter.settings.hudOpacity))
        .preferredColorScheme(colorScheme)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            L10n.t("adventure.expedition.hud.windowAccessibility")
        )
        .onAppear(perform: refreshDraftCandidates)
        .onChange(of: activityCenter.currentDayString) {
            refreshDraftCandidates()
        }
        .onChange(of: activityCenter.settings.dayStartHour) {
            refreshDraftCandidates()
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
                    expedition.withdraw(
                        expectedRunID: withdrawRunID
                    )
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

    @ViewBuilder
    private var phaseLayout: some View {
        if hudController.isExpanded, expedition.state == nil {
            // Setup owns a bounded roster scroller in expanded mode. Keeping it out of the outer
            // fallback ScrollView lets the roster consume exactly the space between the fixed
            // setup header and footer instead of leaving a compact strip at the top of the HUD.
            idleContent
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .top
                )
        } else {
            ViewThatFits(in: .vertical) {
                phaseContent
                    .frame(maxWidth: .infinity)

                ScrollView(.vertical, showsIndicators: false) {
                    phaseContent
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .top
            )
        }
    }

    @ViewBuilder
    private var phaseContent: some View {
        if let state = expedition.state {
            content(state)
        } else {
            idleContent
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: expedition.route?.systemImage ?? "map.fill")
                .foregroundStyle(expedition.route?.color ?? .accentColor)
                .contentShape(Rectangle())
                .gesture(windowDrag)
                .accessibilityHidden(true)

            Text(L10n.t("adventure.expedition.hud.title"))
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .contentShape(Rectangle())
                .gesture(windowDrag)
                .accessibilityHidden(true)
                .layoutPriority(1)

            Spacer(minLength: 4)

            Button {
                hudController.toggleExpanded()
            } label: {
                Image(
                    systemName: hudController.isExpanded
                        ? "arrow.down.right.and.arrow.up.left"
                        : "arrow.up.left.and.arrow.down.right"
                )
                .frame(width: 18, height: 18)
            }
            .help(expansionLabel)
            .accessibilityLabel(
                expansionLabel
            )
            .accessibilityHint(
                expansionHint
            )
            .accessibilityValue(
                hudController.isExpanded
                    ? L10n.t("adventure.expedition.hud.expanded")
                    : L10n.t("adventure.expedition.hud.compact")
            )
            .fixedSize()

            if let state = expedition.state, state.result == nil {
                Button {
                    withdrawRunID = state.runID
                    showingWithdrawConfirmation = true
                } label: {
                    Image(systemName: "stop.circle")
                        .frame(width: 18, height: 18)
                }
                .help(
                    L10n.t(
                        "adventure.expedition.detail.withdraw"
                    )
                )
                .accessibilityLabel(
                    L10n.t(
                        "adventure.expedition.detail.withdraw"
                    )
                )
                .fixedSize()
            }

            Button {
                AdventureExpeditionHUDController.shared.hide()
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 18, height: 18)
            }
            .help(L10n.t("adventure.expedition.hud.close"))
            .accessibilityLabel(
                L10n.t("adventure.expedition.hud.close")
            )
            .fixedSize()
        }
        .buttonStyle(.plain)
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(.secondary)
        .frame(height: 20)
    }

    private var expansionLabel: String {
        L10n.t(
            hudController.isExpanded
                ? "adventure.expedition.hud.collapse"
                : "adventure.expedition.hud.expand"
        )
    }

    private var expansionHint: String {
        L10n.t(
            hudController.isExpanded
                ? "adventure.expedition.hud.collapseHint"
                : "adventure.expedition.hud.expandHint"
        )
    }

    private var windowDrag: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { _ in
                AdventureExpeditionHUDController.shared
                    .dragToCurrentMouseLocation()
            }
            .onEnded { _ in
                AdventureExpeditionHUDController.shared.endDrag()
            }
    }

    @ViewBuilder
    private func content(_ state: AdventureExpeditionState) -> some View {
        if let result = state.result {
            resultContent(result, runID: state.runID)
        } else {
            switch state.phase {
            case .awaitingTurn:
                battleContent(state)
            case let .choosingRelic(offer):
                relicContent(offer, state: state)
            case .finished:
                fallbackFinishedContent(runID: state.runID)
            }
        }
    }

    private func battleContent(
        _ state: AdventureExpeditionState
    ) -> some View {
        let actor = selectedCat(in: state)
        let routeColor = expedition.route?.color ?? .accentColor
        let turnToken = state.turnToken

        return VStack(spacing: 8) {
            HStack {
                Label(
                    L10n.t(
                        "adventure.expedition.hud.stage",
                        state.stageIndex + 1,
                        3
                    ),
                    systemImage:
                        state.currentStage.kind == .boss
                            ? "crown.fill"
                            : "flag.fill"
                )
                .font(.caption.weight(.bold))
                .foregroundStyle(routeColor)

                Spacer()

                manaLabel(state)
            }

            enemyCard(state)
            partyHealth(state)
            catSelector(state)

            HStack(spacing: 7) {
                Button {
                    expedition.basicAttack(
                        catID: actor.id,
                        expectedTurn: turnToken
                    )
                } label: {
                    actionLabel(
                        title: L10n.t(
                            "adventure.expedition.action.basic"
                        ),
                        caption: L10n.t(
                            "adventure.expedition.action.basicMana"
                        ),
                        systemImage: "pawprint.fill"
                    )
                }
                .buttonStyle(.bordered)

                Button {
                    expedition.useSkill(
                        catID: actor.id,
                        expectedTurn: turnToken
                    )
                } label: {
                    actionLabel(
                        title:
                            AdventureExpeditionPresentation
                                .skillName(actor.role),
                        caption: L10n.t(
                            "adventure.expedition.action.skillMana"
                        ),
                        systemImage:
                            AdventureExpeditionPresentation
                                .roleIcon(actor.role)
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(state.mana == 0)
                .help(
                    state.mana == 0
                        ? L10n.t(
                            "adventure.expedition.action.noMana"
                        )
                        : AdventureExpeditionPresentation
                            .skillName(actor.role)
                )
            }
            .controlSize(.small)

            lastTurnFeedback
        }
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.22),
            value: state.battle.enemyHealth
        )
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.22),
            value: state.battle.partyHealth
        )
    }

    private func enemyCard(
        _ state: AdventureExpeditionState
    ) -> some View {
        let intent = state.battle.currentIntent
        let intentColor =
            AdventureExpeditionPresentation.intentColor(intent)

        return VStack(spacing: 6) {
            HStack(spacing: 8) {
                ZStack {
                    Circle().fill(intentColor.opacity(0.14))
                    Image(
                        systemName:
                            state.currentStage.kind == .boss
                                ? "crown.fill"
                                : "sparkles"
                    )
                    .foregroundStyle(intentColor)
                }
                .frame(width: 34, height: 34)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(
                            AdventureExpeditionPresentation.encounterName(
                                encounterID: state.battle.encounter.id,
                                stageIndex: state.stageIndex,
                                kind: state.currentStage.kind
                            )
                        )
                        .font(.caption.weight(.bold))

                        Spacer()

                        Text(
                            "\(state.battle.enemyHealth)/\(state.battle.initialEnemyHealth)"
                        )
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                    }

                    ProgressView(
                        value: Double(state.battle.enemyHealth),
                        total: Double(state.battle.initialEnemyHealth)
                    )
                    .tint(intentColor)
                }
            }

            HStack(spacing: 5) {
                Image(
                    systemName:
                        AdventureExpeditionPresentation.intentIcon(intent)
                )
                Text(
                    L10n.t(
                        "adventure.expedition.hud.intent",
                        AdventureExpeditionPresentation.intentName(intent)
                    )
                )
                .lineLimit(1)
                Spacer()
                Text(
                    L10n.t(
                        "adventure.expedition.hud.turn",
                        state.battle.round
                    )
                )
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(intentColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(intentColor.opacity(0.10))
            )
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.07))
        )
        .accessibilityElement(children: .combine)
    }

    private func partyHealth(
        _ state: AdventureExpeditionState
    ) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "heart.fill")
                .font(.system(size: 9))
                .foregroundStyle(.green)
            ProgressView(
                value: Double(state.battle.partyHealth),
                total: Double(state.party.maxHealth)
            )
            .tint(.green)
            Text(
                "\(state.battle.partyHealth)/\(state.party.maxHealth)"
            )
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            L10n.t(
                "adventure.expedition.hud.partyHealth",
                state.battle.partyHealth,
                state.party.maxHealth
            )
        )
    }

    private func catSelector(
        _ state: AdventureExpeditionState
    ) -> some View {
        HStack(spacing: 6) {
            ForEach(state.party.members) { cat in
                catButton(cat, state: state)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            L10n.t("adventure.expedition.hud.chooseCat")
        )
    }

    private func catButton(
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
            HStack(spacing: 4) {
                candidatePortrait(cat)
                Image(
                    systemName:
                        AdventureExpeditionPresentation.roleIcon(cat.role)
                )
                .font(.caption2.weight(.bold))
            }
            .frame(maxWidth: .infinity, minHeight: 38)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(
                        selected
                            ? color.opacity(0.17)
                            : Color.secondary.opacity(0.05)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
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
            .overlay(alignment: .topTrailing) {
                if counters {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(color)
                        .padding(3)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            AdventureExpeditionPresentation.roleName(cat.role)
        )
        .accessibilityValue(
            selected
                ? L10n.t("adventure.cat.selected")
                : L10n.t("adventure.cat.notSelected")
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

    @ViewBuilder
    private func candidatePortrait(_ cat: AdventureCat) -> some View {
        if let candidate = expedition.candidates.first(
            where: { $0.id == cat.id }
        ) {
            PawpetView(
                summary: candidate.summary,
                size: 29,
                streakDays: candidate.streakDays,
                showsAura: false
            )
            .accessibilityHidden(true)
        } else {
            Image(
                systemName:
                    AdventureExpeditionPresentation.roleIcon(cat.role)
            )
            .frame(width: 29, height: 29)
            .background(Circle().fill(Color.secondary.opacity(0.10)))
            .accessibilityHidden(true)
        }
    }

    private func actionLabel(
        title: String,
        caption: String,
        systemImage: String
    ) -> some View {
        VStack(spacing: 2) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.bold))
                .lineLimit(1)
            Text(caption)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 35)
    }

    private func manaLabel(
        _ state: AdventureExpeditionState
    ) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<state.maximumMana, id: \.self) { index in
                Image(
                    systemName:
                        index < state.mana
                            ? "diamond.fill"
                            : "diamond"
                )
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(
                    index < state.mana
                        ? Color.cyan
                        : Color.secondary.opacity(0.4)
                )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            L10n.t(
                "adventure.expedition.hud.mana",
                state.mana,
                state.maximumMana
            )
        )
    }

    private var lastTurnFeedback: some View {
        Group {
            if let resolution = expedition.turnHistory.last {
                let combat = resolution.combat
                Text(
                    L10n.t(
                        "adventure.expedition.hud.lastTurn",
                        combat.damageDealt,
                        combat.damageReceived,
                        combat.healing
                    )
                )
            } else {
                Text(L10n.t("adventure.expedition.hud.waiting"))
            }
        }
        .font(.caption2.monospacedDigit())
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func relicContent(
        _ offer: AdventureRelicOffer,
        state: AdventureExpeditionState
    ) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 24))
                .foregroundStyle(Color.accentColor)

            VStack(spacing: 2) {
                Text(L10n.t("adventure.expedition.relic.choose"))
                    .font(.callout.weight(.bold))
                Text(
                    L10n.t(
                        "adventure.expedition.relic.chooseCaption",
                        state.stageIndex + 1
                    )
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            ForEach(offer.options, id: \.self) { relic in
                Button {
                    expedition.choose(
                        relic: relic,
                        expectedRunID: state.runID,
                        expectedOffer: offer
                    )
                } label: {
                    HStack(spacing: 8) {
                        Image(
                            systemName:
                                AdventureExpeditionPresentation
                                    .relicIcon(relic)
                        )
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 20)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(
                                AdventureExpeditionPresentation
                                    .relicName(relic)
                            )
                            .font(.caption.weight(.bold))
                            Text(
                                AdventureExpeditionPresentation
                                    .relicDescription(relic)
                            )
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, minHeight: 43)
                    .background(
                        RoundedRectangle(
                            cornerRadius: 9,
                            style: .continuous
                        )
                        .fill(Color.secondary.opacity(0.07))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func resultContent(
        _ result: AdventureExpeditionResult,
        runID: String
    ) -> some View {
        let color =
            AdventureExpeditionPresentation.resultColor(result.status)

        return VStack(spacing: 9) {
            Spacer(minLength: 0)

            ZStack {
                Circle().fill(color.opacity(0.14))
                Text(result.rank.rawValue)
                    .font(.system(size: 27, weight: .black, design: .rounded))
                    .foregroundStyle(color)
            }
            .frame(width: 58, height: 58)

            Text(
                AdventureExpeditionPresentation.resultTitle(result.status)
            )
            .font(.headline)

            Text(
                L10n.t(
                    "adventure.expedition.result.rewardSummary",
                    result.adventureXP,
                    result.routeStampDelta,
                    result.counteredTurnCount,
                    result.totalTurnCount
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            HStack(spacing: 7) {
                Button {
                    expedition.reset(expectedRunID: runID)
                } label: {
                    Text(
                        L10n.t(
                            "adventure.expedition.detail.changeParty"
                        )
                    )
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    expedition.retryDraft(expectedRunID: runID)
                } label: {
                    Text(
                        L10n.t(
                            "adventure.battle.result.retry"
                        )
                    )
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .controlSize(.small)

            Spacer(minLength: 0)
        }
    }

    private func fallbackFinishedContent(runID: String) -> some View {
        VStack(spacing: 12) {
            Text(L10n.t("adventure.expedition.result.completed"))
                .font(.headline)
            Button {
                expedition.reset(expectedRunID: runID)
            } label: {
                Text(
                    L10n.t(
                        "adventure.expedition.detail.changeParty"
                    )
                )
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var idleContent: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                AdventureRouteMenu(
                    selection: draftRouteBinding,
                    adventureLevel: expedition.rewardProgress.level
                )

                Spacer(minLength: 4)

                Label(
                    L10n.t(
                        "adventure.expedition.progress.level",
                        expedition.rewardProgress.level
                    ),
                    systemImage: "seal.fill"
                )
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            }

            Text(L10n.t(expedition.draftRoute.descriptionKey))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(hudController.isExpanded ? 3 : 1)

            HStack(spacing: 5) {
                Text(
                    AdventureExpeditionPresentation.routeOverview(
                        expedition.draftRoute
                    )
                )
                .lineLimit(hudController.isExpanded ? 2 : 1)
                Spacer(minLength: 3)
                Text(
                    AdventureExpeditionPresentation.routeReward(
                        expedition.draftRoute
                    )
                )
                .foregroundStyle(
                    expedition.draftRoute.rewardMultiplierPercent > 100
                        ? Color.accentColor
                        : Color.secondary
                )
            }
            .font(.caption2.weight(.semibold))

            if !expedition.isRouteUnlocked(expedition.draftRoute) {
                Label(
                    AdventureExpeditionPresentation.routeUnlockRequirement(
                        expedition.draftRoute
                    ),
                    systemImage: "lock.fill"
                )
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.orange)
            }

            HStack {
                Text(
                    L10n.t(
                        "adventure.expedition.hud.setupParty",
                        expedition.draftSelectedIDs.count
                    )
                )
                .font(.caption.weight(.semibold))

                Spacer()

                if expedition.draftCandidates.count >= 3 {
                    Button {
                        expedition.selectRecommendedDraft()
                    } label: {
                        Label(
                            L10n.t(
                                "adventure.expedition.hud.recommend"
                            ),
                            systemImage: "wand.and.stars"
                        )
                    }
                    .buttonStyle(.plain)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                }
            }

            if expedition.draftCandidates.count < 3 {
                setupEmptyState
            } else {
                draftRoster

                HStack {
                    Label(
                        L10n.t(
                            "adventure.expedition.progress.routeStamps",
                            expedition.rewardProgress.stampCount(
                                for: expedition.draftRoute.rawValue
                            )
                        ),
                        systemImage: "pawprint.fill"
                    )
                    Spacer()
                    if !draftContextSummary.isEmpty {
                        Text(draftContextSummary)
                        .lineLimit(1)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)

                Button {
                    selectedCatID = nil
                    expedition.startDraft()
                } label: {
                    Label(
                        expedition.isRouteUnlocked(expedition.draftRoute)
                            ? L10n.t("adventure.expedition.start")
                            : AdventureExpeditionPresentation
                                .routeUnlockRequirement(
                                    expedition.draftRoute
                                ),
                        systemImage:
                            expedition.isRouteUnlocked(
                                expedition.draftRoute
                            )
                                ? "play.fill"
                                : "lock.fill"
                    )
                    .font(.caption.weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 25)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!expedition.canStartDraft)

                Text(
                    L10n.t(
                        "adventure.expedition.setup.pauseNotice"
                    )
                )
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: hudController.isExpanded ? .infinity : nil,
            alignment: .top
        )
    }

    @ViewBuilder
    private var draftRoster: some View {
        let candidates =
            AdventureExpeditionPresentation.gradeSortedCandidates(
                expedition.draftCandidates
            )

        if hudController.isExpanded {
            ScrollView(
                .vertical,
                showsIndicators: candidates.count > 10
            ) {
                LazyVGrid(
                    columns: [
                        GridItem(
                            .adaptive(minimum: 76, maximum: 88),
                            spacing: 8
                        ),
                    ],
                    spacing: 8
                ) {
                    ForEach(candidates) { candidate in
                        draftCandidateButton(candidate)
                    }
                }
                .padding(2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .layoutPriority(1)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.secondary.opacity(0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.secondary.opacity(0.10), lineWidth: 1)
            )
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 6) {
                    ForEach(candidates) { candidate in
                        draftCandidateButton(candidate)
                    }
                }
                .padding(.horizontal, 1)
            }
            .frame(minHeight: 64)
        }
    }

    private var setupEmptyState: some View {
        VStack(spacing: 7) {
            Spacer(minLength: 0)
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)
            Text(L10n.t("adventure.expedition.hud.notEnoughCats"))
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)
            Text(
                L10n.t(
                    "adventure.expedition.hud.notEnoughCatsBody",
                    expedition.draftCandidates.count
                )
            )
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var draftRouteBinding: Binding<AdventureExpeditionRoute> {
        Binding(
            get: { expedition.draftRoute },
            set: { expedition.setDraftRoute($0) }
        )
    }

    private var draftRoleSummary: String {
        expedition.draftSelectedCandidates
            .map {
                AdventureExpeditionPresentation.roleName(
                    $0.profile.role
                )
            }
            .joined(separator: " · ")
    }

    private var draftContextSummary: String {
        if let candidate = expedition.draftCandidates.first(
            where: { $0.id == hoveredDraftCandidateID }
        ) {
            return [
                AdventureExpeditionPresentation.roleName(
                    candidate.profile.role
                ),
                AdventureExpeditionPresentation.affinityName(
                    candidate.profile.affinity
                ),
                AdventureExpeditionPresentation.passiveName(
                    candidate.profile.passive
                ),
                candidate.profile.grade.rawValue,
            ].joined(separator: " · ")
        }
        guard !draftRoleSummary.isEmpty else { return "" }
        return L10n.t(
            "adventure.expedition.hud.roles",
            draftRoleSummary
        )
    }

    private func draftCandidateButton(
        _ candidate: PawpetAdventureCandidate
    ) -> some View {
        let selectionIndex = expedition.draftSelectedIDs
            .firstIndex(of: candidate.id)
            .map { $0 + 1 }
        let isSelected = selectionIndex != nil
        let isUnavailable =
            expedition.draftSelectedIDs.count == 3 && !isSelected
        let grade = candidate.profile.grade.rawValue

        return Button {
            expedition.setDraftCandidate(
                id: candidate.id,
                selected: !isSelected
            )
        } label: {
            draftCandidateLabel(
                candidate,
                selectionIndex: selectionIndex,
                selected: isSelected,
                unavailable: isUnavailable
            )
        }
        .buttonStyle(.plain)
        .disabled(isUnavailable)
        .onHover { isHovering in
            if isHovering {
                hoveredDraftCandidateID = candidate.id
            } else if hoveredDraftCandidateID == candidate.id {
                hoveredDraftCandidateID = nil
            }
        }
        .help(
            "\(Formatters.dayLabel(candidate.summary.day)) · "
                + candidateTraitSummary(candidate)
                + " · \(grade)"
        )
        .accessibilityLabel(
            L10n.t(
                "adventure.cat.accessibility",
                Formatters.dayLabel(candidate.summary.day),
                candidateTraitSummary(candidate),
                grade
            )
        )
        .accessibilityValue(
            selectionIndex.map {
                L10n.t("adventure.cat.selectedPosition", $0)
            } ?? L10n.t("adventure.cat.notSelected")
        )
    }

    private func draftCandidateLabel(
        _ candidate: PawpetAdventureCandidate,
        selectionIndex: Int?,
        selected: Bool,
        unavailable: Bool
    ) -> some View {
        let roleColor =
            AdventureExpeditionPresentation.roleColor(
                candidate.profile.role
            )
        let roleIcon =
            AdventureExpeditionPresentation.roleIcon(
                candidate.profile.role
            )
        let grade = candidate.profile.grade.rawValue
        let isExpanded = hudController.isExpanded

        return VStack(spacing: 2) {
            ZStack(alignment: .topTrailing) {
                PawpetView(
                    summary: candidate.summary,
                    size: isExpanded ? 44 : 37,
                    streakDays: candidate.streakDays,
                    showsAura: false
                )
                .accessibilityHidden(true)

                if let selectionIndex {
                    Text("\(selectionIndex)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 14, height: 14)
                        .background(Circle().fill(roleColor))
                }
            }

            HStack(spacing: 3) {
                Image(systemName: roleIcon)
                Text(grade)
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(
                selected ? roleColor : Color.secondary
            )

            if isExpanded {
                Text(
                    Formatters.shortDayLabel(
                        candidate.summary.day
                    )
                )
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            }
        }
        .frame(width: isExpanded ? nil : 48)
        .frame(
            maxWidth: isExpanded ? .infinity : nil,
            minHeight: isExpanded ? 76 : 59
        )
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(
                    selected
                        ? roleColor.opacity(0.14)
                        : Color.secondary.opacity(0.05)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(
                    selected
                        ? roleColor
                        : Color.secondary.opacity(0.14),
                    lineWidth: selected ? 1.5 : 1
                )
        )
        .opacity(unavailable ? 0.42 : 1)
    }

    private func candidateTraitSummary(
        _ candidate: PawpetAdventureCandidate
    ) -> String {
        [
            AdventureExpeditionPresentation.roleName(
                candidate.profile.role
            ),
            AdventureExpeditionPresentation.affinityName(
                candidate.profile.affinity
            ),
            AdventureExpeditionPresentation.passiveName(
                candidate.profile.passive
            ),
        ].joined(separator: " · ")
    }

    private func refreshDraftCandidates() {
        expedition.replaceDraftCandidates(
            AdventureRosterCatalog.candidates(
                todaySummary: activityCenter.todaySummary,
                dayStartHour: activityCenter.settings.dayStartHour
            )
        )
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
}
