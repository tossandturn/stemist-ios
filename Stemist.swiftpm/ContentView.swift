import SwiftUI

enum AppTab: Hashable {
    case today
    case ielts
    case stem
    case notebook
    case profile
}

@MainActor
final class WebWorkspaceCoordinator: ObservableObject {
    @Published private(set) var activeLaunch: WebRouteLaunch?
    private var pendingLaunch: WebRouteLaunch?
    private var isDismissing = false

    func present(_ launch: WebRouteLaunch) {
        if activeLaunch != nil || isDismissing {
            pendingLaunch = launch
            if activeLaunch != nil {
                setPresentedLaunch(nil)
            }
            return
        }

        activeLaunch = launch
    }

    func setPresentedLaunch(_ launch: WebRouteLaunch?) {
        if launch == nil, activeLaunch != nil {
            isDismissing = true
        }
        activeLaunch = launch
    }

    func completeDismissal() {
        isDismissing = false
        guard pendingLaunch != nil else { return }

        // Let SwiftUI finish removing the old full-screen cover before replaying a route.
        Task { @MainActor [weak self] in
            await Task.yield()
            guard let self, self.activeLaunch == nil, !self.isDismissing,
                  let pendingLaunch = self.pendingLaunch else { return }
            self.pendingLaunch = nil
            self.activeLaunch = pendingLaunch
        }
    }
}

@MainActor
struct ContentView: View {
    let configuration: AppRuntimeConfiguration
    @ObservedObject private var routeCoordinator: AppRouteCoordinator
    @State private var selectedTab: AppTab = .today
    @StateObject private var webWorkspace = WebWorkspaceCoordinator()

    init(
        configuration: AppRuntimeConfiguration = .current,
        routeCoordinator: AppRouteCoordinator
    ) {
        self.configuration = configuration
        _routeCoordinator = ObservedObject(wrappedValue: routeCoordinator)
    }

    private func normalizeSelectedTab() {
        if !configuration.showsAccountEntry && selectedTab == .profile {
            selectedTab = .today
        }
    }

    private func present(_ route: WebRoute) {
        present(WebRouteLaunch(route: route))
    }

    private func present(_ launch: WebRouteLaunch) {
        webWorkspace.present(launch)
    }

    private var activeWebLaunch: Binding<WebRouteLaunch?> {
        Binding(
            get: { webWorkspace.activeLaunch },
            set: webWorkspace.setPresentedLaunch
        )
    }

    private func consumePendingExternalURL() {
        guard let url = routeCoordinator.peekPendingURL() else { return }
        guard let launch = WebRouteLaunch(
            url: url,
            allowsAccountEntry: configuration.showsAccountEntry
        ) else {
            routeCoordinator.acknowledgePendingURL(url)
            return
        }
        present(launch)
        routeCoordinator.acknowledgePendingURL(url)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(selectedTab: $selectedTab, openRoute: present)
                .tabItem { Label("Today", systemImage: "house") }
                .tag(AppTab.today)
                .accessibilityIdentifier("tab-today")

            ModuleHomeView(
                title: "IELTS",
                subtitle: "Choose a skill and continue in the same IELTSist account.",
                routes: [
                    .ieltsListening,
                    .ieltsReading,
                    .ieltsWriting,
                    .ieltsSpeaking,
                    .ieltsVocabulary,
                ],
                openRoute: present
            )
            .tabItem { Label("IELTS", systemImage: "text.book.closed") }
            .tag(AppTab.ielts)
            .accessibilityIdentifier("tab-ielts")

            ModuleHomeView(
                title: "STEM",
                subtitle: "Open a separate IG, AS, A2 or exam practice route.",
                routes: [
                    .stemIG,
                    .stemAS,
                    .stemA2,
                    .stemTopics,
                    .stemPastPapers,
                    .stemNotebook,
                    .stemCoach,
                ],
                openRoute: present
            )
            .tabItem { Label("STEM", systemImage: "atom") }
            .tag(AppTab.stem)
            .accessibilityIdentifier("tab-stem")

            NotebookView(openRoute: present)
                .tabItem { Label("Notebook", systemImage: "square.and.pencil") }
                .tag(AppTab.notebook)
                .accessibilityIdentifier("tab-notebook")

            if configuration.showsAccountEntry {
                ProfileView(openRoute: present)
                    .tabItem { Label("Profile", systemImage: "person") }
                    .tag(AppTab.profile)
                    .accessibilityIdentifier("tab-profile")
            }
        }
        .tint(StemistTheme.brand)
        .environment(\.stemistAllowsAccountEntry, configuration.showsAccountEntry)
        .fullScreenCover(
            item: activeWebLaunch,
            onDismiss: webWorkspace.completeDismissal
        ) { launch in
            WebModuleView(
                launch: launch,
                presentedLaunch: activeWebLaunch,
                requestLaunch: present
            )
            .environment(\.stemistAllowsAccountEntry, configuration.showsAccountEntry)
        }
        .onAppear {
            normalizeSelectedTab()
            consumePendingExternalURL()
        }
        .onChange(of: selectedTab) { _, _ in
            normalizeSelectedTab()
        }
        .task(id: routeCoordinator.pendingURL) {
            consumePendingExternalURL()
        }
        .accessibilityIdentifier("stemist-root")
    }
}

private struct DashboardView: View {
    @Binding var selectedTab: AppTab
    let openRoute: (WebRoute) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Today")
                            .font(.largeTitle.weight(.bold))
                        Text("Choose where to continue your study.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 20) {
                        Label("Your learning spaces", systemImage: "rectangle.grid.2x2")
                            .font(.headline)
                            .foregroundStyle(StemistTheme.brand)

                        LearningSpaceButton(
                            title: "IELTS practice",
                            subtitle: "Language preparation",
                            icon: "text.book.closed.fill",
                            tint: StemistTheme.ielts
                        ) {
                            selectedTab = .ielts
                        }

                        LearningSpaceButton(
                            title: "STEM study",
                            subtitle: "IG, AS and A2 courses",
                            icon: "atom",
                            tint: StemistTheme.stem
                        ) {
                            selectedTab = .stem
                        }

                        LearningSpaceButton(
                            title: "AI Coach",
                            subtitle: "Get contextual help across both products",
                            icon: "sparkles",
                            tint: StemistTheme.brand
                        ) {
                            openRoute(.aiCoach)
                        }
                    }

                    Button {
                        selectedTab = .notebook
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "square.and.pencil")
                                .font(.title3)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Open notebook")
                                    .font(.headline)
                                Text("Review your STEM workspace")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                        .background(StemistTheme.secondarySurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open notebook")
                    .accessibilityIdentifier("open-notebook")
                }
                .frame(maxWidth: 760, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .background(StemistTheme.background)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct LearningSpaceButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(tint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                Image(systemName: "arrow.right")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 44, height: 44)
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 88)
            .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(tint.opacity(0.18), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens \(title)")
        .accessibilityIdentifier("learning-space-\(title.lowercased().replacingOccurrences(of: " ", with: "-"))")
    }
}

private struct ModuleHomeView: View {
    let title: String
    let subtitle: String
    let routes: [WebRoute]
    let openRoute: (WebRoute) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title)
                            .font(.largeTitle.weight(.bold))
                        Text(subtitle)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 10)
                    .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 18, trailing: 20))
                    .listRowBackground(Color.clear)
                }

                Section {
                    ForEach(routes) { route in
                        Button {
                            openRoute(route)
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: route.symbol)
                                    .foregroundStyle(route.tint)
                                    .frame(width: 28, height: 28)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(route.title)
                                        .foregroundStyle(.primary)
                                    Text(route.subtitle)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 8)
                                Image(systemName: "arrow.up.right")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(minHeight: 52)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open \(route.title)")
                        .accessibilityIdentifier("route-\(route.id)")
                    }
                } header: {
                    Text("Study")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(StemistTheme.background)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct NotebookView: View {
    let openRoute: (WebRoute) -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notebook")
                        .font(.largeTitle.weight(.bold))
                    Text("Your STEM workspace")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                Button {
                    openRoute(.stemNotebook)
                } label: {
                    Label("Open STEM notebook", systemImage: "square.and.pencil")
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.borderedProminent)
                .tint(StemistTheme.stem)
                .accessibilityIdentifier("open-stem-notebook")

                Spacer()
            }
            .frame(maxWidth: 760, maxHeight: .infinity, alignment: .topLeading)
            .padding(20)
            .background(StemistTheme.background)
        }
    }
}

private struct ProfileView: View {
    let openRoute: (WebRoute) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        openRoute(.ieltsAccount)
                    } label: {
                        Label("Open account", systemImage: "person.crop.circle")
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                    .frame(minHeight: 44)
                    .accessibilityLabel("Open account")
                    .accessibilityIdentifier("route-\(WebRoute.ieltsAccount.id)")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Profile")
        }
    }
}

enum WebDestination: Hashable {
    case ielts
    case stem
    case ai

    var symbol: String {
        switch self {
        case .ielts: "text.book.closed"
        case .stem: "atom"
        case .ai: "sparkles"
        }
    }

    var tint: Color {
        switch self {
        case .ielts: StemistTheme.ielts
        case .stem: StemistTheme.stem
        case .ai: StemistTheme.brand
        }
    }
}

enum WebRoute: Hashable, Identifiable {
    case ieltsListening
    case ieltsReading
    case ieltsWriting
    case ieltsSpeaking
    case ieltsVocabulary
    case ieltsAccount
    case stemHome
    case stemIG
    case stemAS
    case stemA2
    case stemTopics
    case stemPastPapers
    case stemNotebook
    case stemCoach
    case aiCoach

    static let all: [WebRoute] = [
        .ieltsListening,
        .ieltsReading,
        .ieltsWriting,
        .ieltsSpeaking,
        .ieltsVocabulary,
        .ieltsAccount,
        .stemHome,
        .stemIG,
        .stemAS,
        .stemA2,
        .stemTopics,
        .stemPastPapers,
        .stemNotebook,
        .stemCoach,
        .aiCoach,
    ]

    init?(url: URL, allowsAccountEntry: Bool) {
        guard let scheme = url.scheme?.lowercased() else { return nil }

        switch scheme {
        case "stemist":
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                return nil
            }

            let routeQueryNames = Set(["route", "routeid", "route_id"])
            let routeQueryItems = (components.queryItems ?? []).filter { item in
                routeQueryNames.contains(item.name.lowercased())
            }
            guard routeQueryItems.count <= 1 else { return nil }

            let pathID = components.path
                .split(separator: "/", omittingEmptySubsequences: true)
                .last
                .map(String.init)
            let hostID = components.host?.lowercased()
            let queryID = routeQueryItems.first?.value
            guard routeQueryItems.isEmpty || queryID != nil else { return nil }

            let structuralRouteIDs = [
                pathID,
                hostID.flatMap { id in
                    id == "open" || id == "route" ? nil : id
                },
            ].compactMap { $0 }
            let normalizedStructuralIDs = structuralRouteIDs.compactMap(Self.normalizeRouteID)
            guard normalizedStructuralIDs.count == structuralRouteIDs.count,
                  Set(normalizedStructuralIDs).count <= 1 else {
                return nil
            }

            let normalizedQueryID = Self.normalizeRouteID(queryID)
            guard queryID == nil || normalizedQueryID != nil else { return nil }
            if let normalizedQueryID,
               let structuralID = normalizedStructuralIDs.first,
               normalizedQueryID != structuralID {
                return nil
            }

            guard let decodedID = normalizedQueryID ?? normalizedStructuralIDs.first,
                  let matchingRoute = Self.all.first(where: { $0.id == decodedID }) else {
                return nil
            }
            guard allowsAccountEntry || matchingRoute != .ieltsAccount else { return nil }
            self = matchingRoute

        case "https":
            guard let matchingRoute = Self.all
                .sorted(by: { $0.expectedQueryItemCount > $1.expectedQueryItemCount })
                .first(where: { $0.matches(url) }) else {
                return nil
            }
            guard allowsAccountEntry || matchingRoute != .ieltsAccount else { return nil }
            self = matchingRoute

        default:
            return nil
        }
    }

    private var expectedQueryItemCount: Int {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.count ?? 0
    }

    private static func normalizeRouteID(_ value: String?) -> String? {
        value?.removingPercentEncoding?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func matches(_ incomingURL: URL) -> Bool {
        guard let expected = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let incoming = URLComponents(url: incomingURL, resolvingAgainstBaseURL: false),
              expected.scheme?.lowercased() == incoming.scheme?.lowercased(),
              expected.host?.lowercased() == incoming.host?.lowercased(),
              normalizedPath(expected.path) == normalizedPath(incoming.path) else {
            return false
        }

        if let expectedFragment = expected.fragment {
            guard incoming.fragment == expectedFragment else { return false }
        } else if incoming.fragment != nil {
            return false
        }

        let expectedItems = expected.queryItems ?? []
        let incomingItems = incoming.queryItems ?? []
        return matchesQueryItems(expectedItems, in: incomingItems)
    }

    private func matchesQueryItems(
        _ expectedItems: [URLQueryItem],
        in incomingItems: [URLQueryItem]
    ) -> Bool {
        expectedItems.allSatisfy { expectedItem in
            let matchingItems = incomingItems.filter { incomingItem in
                incomingItem.name.caseInsensitiveCompare(expectedItem.name) == .orderedSame
            }
            return matchingItems.count == 1 && matchingItems.first?.value == expectedItem.value
        }
    }

    private func normalizedPath(_ path: String) -> String {
        path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
    }

    var id: String {
        switch self {
        case .ieltsListening: "ielts-listening"
        case .ieltsReading: "ielts-reading"
        case .ieltsWriting: "ielts-writing"
        case .ieltsSpeaking: "ielts-speaking"
        case .ieltsVocabulary: "ielts-vocabulary"
        case .ieltsAccount: "ielts-account"
        case .stemHome: "stem-home"
        case .stemIG: "stem-ig"
        case .stemAS: "stem-as"
        case .stemA2: "stem-a2"
        case .stemTopics: "stem-topics"
        case .stemPastPapers: "stem-past-papers"
        case .stemNotebook: "stem-notebook"
        case .stemCoach: "stem-coach"
        case .aiCoach: "ai-coach"
        }
    }

    var destination: WebDestination {
        switch self {
        case .ieltsListening, .ieltsReading, .ieltsWriting, .ieltsSpeaking, .ieltsVocabulary, .ieltsAccount:
            .ielts
        case .stemHome, .stemIG, .stemAS, .stemA2, .stemTopics, .stemPastPapers, .stemNotebook, .stemCoach:
            .stem
        case .aiCoach:
            .ai
        }
    }

    var opensCoachOnLoad: Bool {
        switch self {
        case .stemCoach, .aiCoach: true
        default: false
        }
    }

    var title: String {
        switch self {
        case .ieltsListening: "Listening"
        case .ieltsReading: "Reading"
        case .ieltsWriting: "Writing"
        case .ieltsSpeaking: "Speaking"
        case .ieltsVocabulary: "Vocabulary"
        case .ieltsAccount: "IELTSist account"
        case .stemHome: "STEM Today"
        case .stemIG: "IG course"
        case .stemAS: "AS course"
        case .stemA2: "A2 course"
        case .stemTopics: "Topic practice"
        case .stemPastPapers: "Past papers"
        case .stemNotebook: "STEM notebook"
        case .stemCoach: "STEM AI Coach"
        case .aiCoach: "AI Coach"
        }
    }

    var subtitle: String {
        switch self {
        case .ieltsListening: "Practice sections with captions and review."
        case .ieltsReading: "Work through passages and evidence."
        case .ieltsWriting: "Write, submit and receive feedback."
        case .ieltsSpeaking: "Practise Parts 1, 2 and 3 with AI."
        case .ieltsVocabulary: "Review IELTS and STEM terminology."
        case .ieltsAccount: "Membership, drafts and saved work."
        case .stemHome: "Your cross-subject study dashboard."
        case .stemIG: "IGCSE route and practice inventory."
        case .stemAS: "AS route and paper components."
        case .stemA2: "A2 route and paper components."
        case .stemTopics: "Topic-based practice in the selected route."
        case .stemPastPapers: "Verified question papers and source evidence."
        case .stemNotebook: "Private notes and review queue."
        case .stemCoach: "Contextual help for the current STEM task."
        case .aiCoach: "Unified AI conversation workspace."
        }
    }

    var symbol: String { destination.symbol }
    var tint: Color { destination.tint }

    var url: URL {
        switch self {
        case .ieltsListening:
            URL(string: "https://ieltsist.com/?module=listening#single")!
        case .ieltsReading:
            URL(string: "https://ieltsist.com/?module=reading#single")!
        case .ieltsWriting:
            URL(string: "https://ieltsist.com/?module=writing#writing-upload")!
        case .ieltsSpeaking:
            URL(string: "https://ieltsist.com/?module=speaking#bank")!
        case .ieltsVocabulary:
            URL(string: "https://ieltsist.com/#vocabulary")!
        case .ieltsAccount:
            URL(string: "https://ieltsist.com/#mine")!
        case .stemHome:
            URL(string: "https://stem.ieltsist.com/today")!
        case .stemIG:
            URL(string: "https://stem.ieltsist.com/practice?routeId=cie-0625-igcse-physics&stage=IGCSE&course=0625&tab=recommended")!
        case .stemAS:
            URL(string: "https://stem.ieltsist.com/practice?routeId=cie-9702-as-physics&stage=AS&course=9702&tab=recommended")!
        case .stemA2:
            URL(string: "https://stem.ieltsist.com/practice?routeId=cie-9702-a2-physics&stage=A2&course=9702&tab=recommended")!
        case .stemTopics:
            URL(string: "https://stem.ieltsist.com/practice?tab=topics")!
        case .stemPastPapers:
            URL(string: "https://stem.ieltsist.com/papers")!
        case .stemNotebook:
            URL(string: "https://stem.ieltsist.com/notebook")!
        case .stemCoach:
            URL(string: "https://stem.ieltsist.com/today?coach=1")!
        case .aiCoach:
            URL(string: "https://ieltsist.com/#ai-coach")!
        }
    }
}

/// A typed launch keeps route identity separate from the safe study context
/// carried by a vocabulary or question return link.
struct WebRouteLaunch: Hashable, Identifiable {
    let route: WebRoute
    let url: URL

    init(route: WebRoute) {
        self.route = route
        url = route.url
    }

    var id: String {
        "\(route.id):\(url.absoluteString)"
    }

    private static let sensitiveQueryNames: Set<String> = [
        "api_key",
        "apikey",
        "authorization",
        "access_token",
        "id_token",
        "refresh_token",
        "token",
        "code",
        "state",
        "session",
        "password",
    ]

    static func sensitiveQueryName(_ name: String) -> Bool {
        sensitiveQueryNames.contains(
            name
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .replacingOccurrences(of: "[]", with: "")
        )
    }

    private static let contextQueryNames: [String: String] = [
        "contractversion": "contractVersion",
        "family": "family",
        "taxonomyid": "taxonomyId",
        "routeid": "routeId",
        "route_id": "routeId",
        "subjectcode": "subjectCode",
        "specificationversion": "specificationVersion",
        "stage": "stage",
        "course": "course",
        "tab": "tab",
        "topicid": "topicId",
        "questionpartid": "questionPartId",
        "question_part_id": "questionPartId",
        "termid": "termIds",
        "termids": "termIds",
        "term_ids": "termIds",
        "attemptid": "attemptId",
        "returnto": "returnTo",
        "source": "source",
        "sourcestatus": "sourceStatus",
        "terminventorystatus": "termInventoryStatus",
        "availablecount": "availableCount",
        "focus": "focus",
        "question": "question",
        "part": "part",
        "coach": "coach",
    ]

    init?(url: URL, allowsAccountEntry: Bool) {
        guard let route = WebRoute(url: url, allowsAccountEntry: allowsAccountEntry) else {
            return nil
        }

        self.route = route
        self.url = Self.sanitizedURL(for: route, incomingURL: url)
    }

    private static func sanitizedURL(for route: WebRoute, incomingURL: URL) -> URL {
        guard var destination = URLComponents(url: route.url, resolvingAgainstBaseURL: false),
              let incoming = URLComponents(url: incomingURL, resolvingAgainstBaseURL: false) else {
            return route.url
        }

        let baseQueryItems = destination.queryItems ?? []
        let destinationNames = Set(baseQueryItems.map { $0.name.lowercased() })
        var singletonContextItems: [URLQueryItem] = []
        var termContextItems: [URLQueryItem] = []
        var seenSingletonNames = Set<String>()
        var seenTermValues = Set<String>()

        for item in incoming.queryItems ?? [] {
            let rawName = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedName = rawName.lowercased().replacingOccurrences(of: "[]", with: "")
            guard !sensitiveQueryName(normalizedName),
                  let canonicalName = contextQueryNames[normalizedName],
                  let value = sanitizedValue(item.value, for: normalizedName),
                  !value.isEmpty else {
                continue
            }

            if destinationNames.contains(normalizedName) || destinationNames.contains(canonicalName.lowercased()) {
                continue
            }

            if canonicalName == "termIds" {
                guard value.utf8.count <= 256,
                      termContextItems.count < 128,
                      seenTermValues.insert(value).inserted else {
                    continue
                }
                termContextItems.append(URLQueryItem(name: canonicalName, value: value))
                continue
            }

            if seenSingletonNames.contains(canonicalName) {
                continue
            }
            seenSingletonNames.insert(canonicalName)
            singletonContextItems.append(URLQueryItem(name: canonicalName, value: value))
        }

        var contextItems = singletonContextItems + termContextItems
        while true {
            destination.queryItems = baseQueryItems + contextItems

            if let sanitized = destination.url,
               sanitized.absoluteString.utf8.count <= 16_000 {
                return sanitized
            }

            guard !termContextItems.isEmpty else {
                return route.url
            }
            termContextItems.removeLast()
            contextItems = singletonContextItems + termContextItems
        }
    }

    private static func sanitizedValue(_ value: String?, for name: String) -> String? {
        let maxByteCount = name == "returnto" ? 2_000 : 256
        guard let value,
              !value.isEmpty,
              value.utf8.count <= maxByteCount,
              !value.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else {
            return nil
        }

        if name == "returnto" {
            guard let returnURL = URL(string: value),
                  returnURL.user == nil,
                  returnURL.password == nil,
                  !(returnURL.fragment?.containsSensitiveQueryName ?? false),
                  !returnURL.queryItemsContainSensitiveName else {
                return nil
            }

            if let scheme = returnURL.scheme?.lowercased() {
                guard scheme == "https",
                      let host = returnURL.host?.lowercased(),
                      host == "ieltsist.com" || host.hasSuffix(".ieltsist.com") else {
                    return nil
                }
            } else if value.hasPrefix("//") || value.contains("\\") || !value.hasPrefix("/") {
                return nil
            }
        }

        return value
    }
}

private extension URL {
    var queryItemsContainSensitiveName: Bool {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return true
        }
        return (components.queryItems ?? []).contains { item in
            WebRouteLaunch.sensitiveQueryName(item.name)
        }
    }
}

private extension String {
    var containsSensitiveQueryName: Bool {
        let lowercased = lowercased()
        let sensitiveNames = ["token", "access_token", "id_token", "refresh_token", "api_key", "code", "state"]
        return sensitiveNames.contains { lowercased.contains("\($0)=") }
    }
}

enum StemistTheme {
    static let brand = Color(red: 0.06, green: 0.34, blue: 0.78)
    static let ielts = Color(red: 0.08, green: 0.38, blue: 0.86)
    static let stem = Color(red: 0.02, green: 0.54, blue: 0.44)
    static let background = Color(uiColor: .systemGroupedBackground)
    static let secondarySurface = Color(uiColor: .secondarySystemGroupedBackground)
}
