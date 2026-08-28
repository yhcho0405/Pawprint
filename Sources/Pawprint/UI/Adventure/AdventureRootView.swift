import SwiftUI
import PawprintCore

/// First playable slice of Pawprint's adventure mode.
///
/// It intentionally owns only in-memory state: completed cats are read from the existing history,
/// a short battle is driven by the pure core engine, and nothing is written back to the database.
@MainActor
struct AdventureRootView: View {
    @Bindable private var activityCenter = ActivityCenter.shared
    @Bindable private var localization = LocalizationManager.shared
    @Bindable private var expeditionCenter = AdventureExpeditionCenter.shared

    @State private var battleLaunch: AdventureBattleLaunch?
    @State private var runNumber: UInt64 = 0

    private let encounter = AdventureEncounter(
        id: "sunlit-clearing",
        affinity: .morning,
        power: 70
    )

    private var candidates: [PawpetAdventureCandidate] {
        expeditionCenter.draftCandidates
    }

    private var selectedIDs: [String] {
        expeditionCenter.draftSelectedIDs
    }

    private var selectedCandidates: [PawpetAdventureCandidate] {
        expeditionCenter.draftSelectedCandidates
    }

    private var canStart: Bool {
        expeditionCenter.canStartDraft
    }

    private var isPartyReady: Bool {
        selectedCandidates.count == 3
    }

    private var selectedRoute: AdventureExpeditionRoute {
        expeditionCenter.draftRoute
    }

    private var isSelectedRouteUnlocked: Bool {
        expeditionCenter.isRouteUnlocked(selectedRoute)
    }

    private var selectedRouteBinding: Binding<AdventureExpeditionRoute> {
        Binding(
            get: { expeditionCenter.draftRoute },
            set: { expeditionCenter.setDraftRoute($0) }
        )
    }

    private var colorScheme: ColorScheme? {
        switch activityCenter.settings.theme {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var body: some View {
        // Reading the revision makes this standalone window redraw immediately after a language
        // change, just like the popover root does.
        let _ = localization.revision

        Group {
            if expeditionCenter.state != nil {
                AdventureExpeditionDetailView()
            } else if let battleLaunch {
                AdventureBattleView(
                    initialState: battleLaunch.state,
                    partyCandidates: battleLaunch.candidates,
                    onReturnToParty: {
                        self.battleLaunch = nil
                    },
                    onRetry: {
                        startEncounter()
                    }
                )
                .id(battleLaunch.id)
            } else {
                setupView
            }
        }
        .frame(minWidth: 780, minHeight: 560)
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(colorScheme)
        .onAppear(perform: load)
        .onChange(of: activityCenter.currentDayString) { _, _ in load() }
        .onChange(of: activityCenter.settings.dayStartHour) { _, _ in load() }
        .onChange(of: localization.revision) { _, _ in
            AdventureWindowController.shared.refreshLocalizedTitle()
        }
    }

    private var setupView: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if candidates.count < 3 {
                emptyState
            } else {
                HSplitView {
                    rosterPanel
                        .frame(minWidth: 440, idealWidth: 520)
                    expeditionPanel
                        .frame(minWidth: 300, idealWidth: 360)
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.28), Color.purple.opacity(0.18)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "map.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.t("adventure.header.title"))
                    .font(.title2.weight(.bold))
                Text(L10n.t("adventure.header.subtitle"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Label(L10n.t("adventure.today.notice"), systemImage: "clock.badge.checkmark")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.secondary.opacity(0.10))
                )
        }
        .padding(18)
    }

    private var rosterPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("adventure.roster.title"))
                        .font(.headline)
                    Text(L10n.t("adventure.roster.caption"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(L10n.t("adventure.selection.count", selectedIDs.count))
                    .font(.callout.weight(.semibold).monospacedDigit())
                    .foregroundStyle(selectedIDs.count == 3 ? Color.accentColor : Color.secondary)
            }

            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 126, maximum: 160), spacing: 10)
                    ],
                    spacing: 10
                ) {
                    ForEach(candidates) { candidate in
                        candidateCard(candidate)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(16)
    }

    private func candidateCard(_ candidate: PawpetAdventureCandidate) -> some View {
        let isSelected = selectedIDs.contains(candidate.id)
        let selectionIndex = selectedIDs.firstIndex(of: candidate.id).map { $0 + 1 }
        let isUnavailable = selectedIDs.count == 3 && !isSelected
        let traits = PawpetTraits.forDay(
            candidate.summary,
            streakDays: candidate.streakDays
        )

        return Button {
            expeditionCenter.setDraftCandidate(
                id: candidate.id,
                selected: !isSelected
            )
        } label: {
            VStack(spacing: 7) {
                ZStack(alignment: .topTrailing) {
                    CatFoil(
                        lustre: traits.lustre,
                        seed: candidate.summary.day,
                        size: 92
                    ) {
                        PawpetView(
                            summary: candidate.summary,
                            size: 92,
                            streakDays: candidate.streakDays,
                            showsAura: true
                        )
                    }

                    if let selectionIndex {
                        Text("\(selectionIndex)")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color.accentColor))
                            .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 1))
                    }
                }

                VStack(spacing: 3) {
                    Text(Formatters.shortDayLabel(candidate.summary.day))
                        .font(.caption.weight(.semibold))
                    HStack(spacing: 5) {
                        Text(candidate.profile.grade.rawValue)
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(gradeColor(candidate.profile.grade))
                        Text(roleLabel(candidate.profile.role))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(
                        isSelected ? Color.accentColor : Color.secondary.opacity(0.14),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .opacity(isUnavailable ? 0.48 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isUnavailable)
        .accessibilityLabel(
            L10n.t(
                "adventure.cat.accessibility",
                Formatters.dayLabel(candidate.summary.day),
                roleLabel(candidate.profile.role),
                candidate.profile.grade.rawValue
            )
        )
        .accessibilityValue(
            selectionIndex.map {
                L10n.t("adventure.cat.selectedPosition", $0)
            } ?? L10n.t("adventure.cat.notSelected")
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var expeditionPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                partySection
                Divider()
                ambientExpeditionSection
            }
            .padding(16)
        }
    }

    private var ambientExpeditionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(
                L10n.t("adventure.expedition.setup.title"),
                systemImage: "checkerboard.shield"
            )
            .font(.headline)

            Text(L10n.t("adventure.expedition.setup.description"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            AdventureRouteMenu(
                selection: selectedRouteBinding,
                adventureLevel: expeditionCenter.rewardProgress.level,
                showsFieldLabel: true
            )

            Text(L10n.t(selectedRoute.descriptionKey))
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Text(
                    AdventureExpeditionPresentation.routeOverview(
                        selectedRoute
                    )
                )
                .lineLimit(2)
                Spacer(minLength: 4)
                Text(
                    AdventureExpeditionPresentation.routeReward(
                        selectedRoute
                    )
                )
                .foregroundStyle(
                    selectedRoute.rewardMultiplierPercent > 100
                        ? Color.accentColor
                        : Color.secondary
                )
            }
            .font(.caption2.weight(.semibold))

            if !isSelectedRouteUnlocked {
                Label(
                    AdventureExpeditionPresentation
                        .routeUnlockRequirement(selectedRoute),
                    systemImage: "lock.fill"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
            }

            VStack(spacing: 7) {
                setupRule(
                    icon: "shield.lefthalf.filled",
                    text: L10n.t(
                        "adventure.expedition.setup.ruleBattles"
                    )
                )
                setupRule(
                    icon: "diamond.fill",
                    text: L10n.t(
                        "adventure.expedition.setup.ruleMana"
                    )
                )
                setupRule(
                    icon: "shippingbox.fill",
                    text: L10n.t(
                        "adventure.expedition.setup.ruleRelics"
                    )
                )
            }

            HStack {
                Label(
                    L10n.t(
                        "adventure.expedition.progress.level",
                        expeditionCenter.rewardProgress.level
                    ),
                    systemImage: "seal.fill"
                )
                Spacer()
                Text(
                    L10n.t(
                        "adventure.expedition.progress.routeStamps",
                        expeditionCenter.rewardProgress.stampCount(
                            for: selectedRoute.rawValue
                        )
                    )
                )
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)

            Button {
                startExpedition()
            } label: {
                Label(
                    isSelectedRouteUnlocked
                        ? L10n.t("adventure.expedition.start")
                        : AdventureExpeditionPresentation
                            .routeUnlockRequirement(selectedRoute),
                    systemImage: isSelectedRouteUnlocked
                        ? "play.fill"
                        : "lock.fill"
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canStart)

            Label(
                L10n.t(
                    "adventure.expedition.setup.pauseNotice"
                ),
                systemImage: "pause.circle"
            )
            .font(.caption2)
            .foregroundStyle(.secondary)

            Label(
                L10n.t(
                    "adventure.expedition.result.persistenceNotice"
                ),
                systemImage: "internaldrive"
            )
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.accentColor.opacity(0.055))
        )
    }

    private func setupRule(
        icon: String,
        text: String
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .frame(width: 18)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.secondary.opacity(0.06))
        )
    }

    private var partySection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(L10n.t("adventure.party.title"))
                    .font(.headline)
                Spacer()
                Image(systemName: isPartyReady ? "checkmark.circle.fill" : "circle.dashed")
                    .foregroundStyle(isPartyReady ? Color.green : Color.secondary)
            }

            Text(L10n.t("adventure.party.hint"))
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(0..<3, id: \.self) { index in
                partySlot(index)
            }
        }
    }

    @ViewBuilder
    private func partySlot(_ index: Int) -> some View {
        if index < selectedCandidates.count {
            let candidate = selectedCandidates[index]
            HStack(spacing: 9) {
                PawpetView(
                    summary: candidate.summary,
                    size: 48,
                    streakDays: candidate.streakDays,
                    showsAura: false
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(Formatters.dayLabel(candidate.summary.day))
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(
                        L10n.t(
                            "adventure.cat.summary",
                            roleLabel(candidate.profile.role),
                            affinityLabel(candidate.profile.affinity),
                            passiveLabel(candidate.profile.passive)
                        )
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                Button {
                    remove(candidate)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help(L10n.t("adventure.party.remove"))
                .accessibilityLabel(L10n.t("adventure.party.remove"))
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.secondary.opacity(0.07))
            )
        } else {
            HStack {
                Image(systemName: "pawprint")
                    .foregroundStyle(.tertiary)
                    .frame(width: 48, height: 32)
                Text(L10n.t("adventure.party.slot.empty"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(8)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.secondary.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [4]))
            )
        }
    }

    private var encounterSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(L10n.t("adventure.encounter.section"))
                .font(.headline)

            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color.orange.opacity(0.14))
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 25))
                        .foregroundStyle(.orange)
                }
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("adventure.encounter.title"))
                        .font(.callout.weight(.semibold))
                    Text(L10n.t("adventure.encounter.description"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Label(
                            affinityLabel(encounter.affinity),
                            systemImage: "sparkles"
                        )
                        Label(
                            L10n.t("adventure.encounter.power", encounter.power),
                            systemImage: "shield.lefthalf.filled"
                        )
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.orange.opacity(0.06))
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "pawprint")
                .font(.system(size: 42))
                .foregroundStyle(.tertiary)
            Text(L10n.t("adventure.empty.title"))
                .font(.title3.weight(.semibold))
            Text(L10n.t("adventure.empty.caption"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private func load() {
        expeditionCenter.replaceDraftCandidates(
            AdventureRosterCatalog.candidates(
                todaySummary: activityCenter.todaySummary,
                dayStartHour: activityCenter.settings.dayStartHour
            )
        )

        // Screenshot harness only: exercise the current turn-based expedition layout without UI
        // automation or access to the user's real database. Normal launches never set this.
        if AdventureSnapshotHarness.shouldAutorun(),
           expeditionCenter.state == nil,
           candidates.count >= 3 {
            expeditionCenter.selectDraftCandidates(
                Array(candidates.prefix(3).map(\.id))
            )
            startExpedition()
        }
    }

    private func remove(_ candidate: PawpetAdventureCandidate) {
        expeditionCenter.setDraftCandidate(
            id: candidate.id,
            selected: false
        )
    }

    private func startEncounter() {
        let profiles = selectedCandidates.map(\.profile)
        guard let party = try? AdventureParty(members: profiles) else { return }

        runNumber &+= 1
        battleLaunch = AdventureBattleLaunch(
            id: runNumber,
            state: AdventureEngine.beginBattle(
                party: party,
                encounter: encounter,
                seed: runSeed(for: profiles, runNumber: runNumber)
            ),
            candidates: selectedCandidates
        )
    }

    private func startExpedition() {
        guard canStart else { return }
        let didStart = expeditionCenter.startDraft()
        if didStart {
            AdventureExpeditionHUDController.shared.show()
        }
    }

    /// Stable across launches and architectures; unlike `hashValue`, this is suitable for replay.
    private func runSeed(
        for cats: [AdventureCat],
        runNumber: UInt64,
        salt: String = ""
    ) -> UInt64 {
        var value: UInt64 = 0xCBF29CE484222325
        let bytes = cats.flatMap { Array($0.id.utf8) } + Array(salt.utf8)
        for byte in bytes {
            value ^= UInt64(byte)
            value = value &* 0x100000001B3
        }
        return value ^ (runNumber &* 0x9E3779B97F4A7C15)
    }

    private func roleLabel(_ role: AdventureRole) -> String {
        switch role {
        case .guardian: return L10n.t("adventure.role.guardian")
        case .striker: return L10n.t("adventure.role.striker")
        case .support: return L10n.t("adventure.role.support")
        }
    }

    private func affinityLabel(_ affinity: AdventureAffinity) -> String {
        switch affinity {
        case .dawn: return L10n.t("adventure.affinity.dawn")
        case .morning: return L10n.t("adventure.affinity.morning")
        case .afternoon: return L10n.t("adventure.affinity.afternoon")
        case .evening: return L10n.t("adventure.affinity.evening")
        case .night: return L10n.t("adventure.affinity.night")
        case .deepNight: return L10n.t("adventure.affinity.deepNight")
        }
    }

    private func passiveLabel(_ passive: AdventurePassive) -> String {
        switch passive {
        case .steady: return L10n.t("adventure.passive.steady")
        case .resilient: return L10n.t("adventure.passive.resilient")
        case .focused: return L10n.t("adventure.passive.focused")
        case .opportunist: return L10n.t("adventure.passive.opportunist")
        case .alert: return L10n.t("adventure.passive.alert")
        }
    }

    private func gradeColor(_ grade: AdventureGrade) -> Color {
        switch grade {
        case .s: return Color(red: 1.0, green: 0.72, blue: 0.20)
        case .a: return Color(red: 0.72, green: 0.48, blue: 0.98)
        case .b: return Color(red: 0.32, green: 0.62, blue: 0.95)
        case .c: return Color(red: 0.35, green: 0.72, blue: 0.52)
        case .d: return Color.secondary
        }
    }
}

private struct AdventureBattleLaunch {
    let id: UInt64
    let state: AdventureBattleState
    let candidates: [PawpetAdventureCandidate]
}
