import SwiftUI

enum AppTab: Hashable {
    case today
    case ielts
    case stem
    case notebook
    case profile
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(selectedTab: $selectedTab)
                .tabItem { Label("Today", systemImage: "house") }
                .tag(AppTab.today)

            ModuleHomeView(
                title: "IELTS",
                subtitle: "Exam practice",
                modules: ["Listening", "Reading", "Writing", "Speaking", "Vocabulary"],
                destination: .ielts
            )
            .tabItem { Label("IELTS", systemImage: "text.book.closed") }
            .tag(AppTab.ielts)

            ModuleHomeView(
                title: "STEM",
                subtitle: "A-Level study",
                modules: ["IG", "AS", "A2", "Topics", "Past papers"],
                destination: .stem
            )
            .tabItem { Label("STEM", systemImage: "atom") }
            .tag(AppTab.stem)

            NotebookView()
                .tabItem { Label("Notebook", systemImage: "square.and.pencil") }
                .tag(AppTab.notebook)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person") }
                .tag(AppTab.profile)
        }
        .tint(StemistTheme.brand)
    }
}

private struct DashboardView: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Today")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
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
    }
}

private struct ModuleHomeView: View {
    let title: String
    let subtitle: String
    let modules: [String]
    let destination: WebDestination
    @State private var showsWebModule = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                        Text(subtitle)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 10)
                    .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 18, trailing: 20))
                    .listRowBackground(Color.clear)
                }

                Section {
                    ForEach(modules, id: \.self) { module in
                        Button {
                            showsWebModule = true
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: destination.symbol)
                                    .foregroundStyle(destination.tint)
                                    .frame(width: 28, height: 28)
                                Text(module)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open \(module)")
                    }
                } header: {
                    Text("Study")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(StemistTheme.background)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showsWebModule) {
                WebModuleView(destination: destination)
            }
        }
    }
}

private struct NotebookView: View {
    @State private var showsStemNotebook = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notebook")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("Your STEM workspace")
                        .foregroundStyle(.secondary)
                }

                Button {
                    showsStemNotebook = true
                } label: {
                    Label("Open STEM notebook", systemImage: "square.and.pencil")
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.borderedProminent)
                .tint(StemistTheme.stem)

                Spacer()
            }
            .frame(maxWidth: 760, maxHeight: .infinity, alignment: .topLeading)
            .padding(20)
            .background(StemistTheme.background)
            .sheet(isPresented: $showsStemNotebook) {
                WebModuleView(destination: .stem)
            }
        }
    }
}

private struct ProfileView: View {
    @State private var showsAccount = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showsAccount = true
                    } label: {
                        Label("Open account", systemImage: "person.crop.circle")
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Profile")
            .sheet(isPresented: $showsAccount) {
                WebModuleView(destination: .ielts)
            }
        }
    }
}

enum WebDestination {
    case ielts
    case stem

    var title: String {
        switch self {
        case .ielts: "IELTSist"
        case .stem: "STEM"
        }
    }

    var url: URL {
        switch self {
        case .ielts: URL(string: "https://ieltsist.com")!
        case .stem: URL(string: "https://stem.ieltsist.com")!
        }
    }

    var symbol: String {
        switch self {
        case .ielts: "text.book.closed"
        case .stem: "atom"
        }
    }

    var tint: Color {
        switch self {
        case .ielts: StemistTheme.ielts
        case .stem: StemistTheme.stem
        }
    }
}

enum StemistTheme {
    static let brand = Color(red: 0.06, green: 0.34, blue: 0.78)
    static let ielts = Color(red: 0.08, green: 0.38, blue: 0.86)
    static let stem = Color(red: 0.02, green: 0.54, blue: 0.44)
    static let background = Color(uiColor: .systemGroupedBackground)
    static let secondarySurface = Color(uiColor: .secondarySystemGroupedBackground)
}
