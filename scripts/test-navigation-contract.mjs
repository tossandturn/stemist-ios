import assert from 'node:assert/strict'
import fs from 'node:fs'

const contentView = fs.readFileSync('Stemist.swiftpm/ContentView.swift', 'utf8')
const webModule = fs.readFileSync('Stemist.swiftpm/WebModuleView.swift', 'utf8')
const stemistApp = fs.readFileSync('Stemist.swiftpm/StemistApp.swift', 'utf8')
const packageSwift = fs.readFileSync('Stemist.swiftpm/Package.swift', 'utf8')
const codemagic = fs.readFileSync('codemagic.yaml', 'utf8')
const readme = fs.readFileSync('README.md', 'utf8')
const gitignore = fs.readFileSync('.gitignore', 'utf8')
const infoPlistPath = 'Stemist.swiftpm/Info.plist'
const githubWorkflowPath = '.github/workflows/ios-simulator.yml'
const cachedManifestPath = 'Stemist.swiftpm/.swiftpm/playgrounds/CachedManifest.plist'
const shellUITestPath = 'Stemist.swiftpm/Tests/StemistShellUITests/StemistShellUITests.swift'
const xcodeProjectPath = 'StemistUITests.xcodeproj/project.pbxproj'
const xcodeSchemePath = 'StemistUITests.xcodeproj/xcshareddata/xcschemes/StemistShellUITests.xcscheme'
const appSchemePath = 'StemistUITests.xcodeproj/xcshareddata/xcschemes/Stemist.xcscheme'

assert.ok(
  !fs.existsSync(cachedManifestPath),
  'stale Swift Playgrounds manifest cache must not override the checked-in package metadata'
)
assert.match(gitignore, /Stemist\.swiftpm\/\.swiftpm\/playgrounds\/CachedManifest\.plist/)

assert.ok(
  fs.existsSync(xcodeProjectPath),
  'XCUIApplication needs a real Xcode app and UI-test project instead of a standalone SwiftPM test bundle'
)
assert.ok(
  fs.existsSync(xcodeSchemePath),
  'the real UI-test target needs a shared scheme for reproducible macOS CI runs'
)
assert.ok(
  fs.existsSync(appSchemePath),
  'the Xcode app target needs its own shared scheme for student and QA artifact builds'
)
const xcodeProject = fs.readFileSync(xcodeProjectPath, 'utf8')
const xcodeScheme = fs.readFileSync(xcodeSchemePath, 'utf8')
const appScheme = fs.readFileSync(appSchemePath, 'utf8')

assert.ok(
  fs.existsSync('Stemist.swiftpm/AppRuntimeConfiguration.swift'),
  'test-only account visibility requires an explicit runtime configuration'
)
const runtimeConfiguration = fs.readFileSync('Stemist.swiftpm/AppRuntimeConfiguration.swift', 'utf8')

assert.match(runtimeConfiguration, /stemist-full-feature-test/, 'full-function tests need a dedicated launch argument')
assert.match(runtimeConfiguration, /STEMIST_FULL_FEATURE_TEST/, 'CI tests need a dedicated environment switch')
assert.match(runtimeConfiguration, /fullFeatureTestInfoKey/, 'internal device QA builds need an explicit Info.plist switch')
assert.match(
  runtimeConfiguration,
  /Bundle\.main\.object\(forInfoDictionaryKey:\s*Self\.fullFeatureTestInfoKey\)/,
  'the runtime configuration must read the signed bundle QA switch without exposing a student-facing toggle'
)
assert.match(runtimeConfiguration, /showsAccountEntry/, 'runtime configuration must own account-entry visibility')
assert.match(runtimeConfiguration, /static let current\s*=\s*AppRuntimeConfiguration\(\)/, 'normal builds must use a deterministic default configuration')
assert.match(
  runtimeConfiguration,
  /#if DEBUG[\s\S]{0,260}fullFeatureTestEnvironmentKey[\s\S]{0,260}#else[\s\S]{0,260}let environmentValue:\s*String\?\s*=\s*nil[\s\S]{0,120}#endif/,
  'release artifacts must not expose QA account controls through an arbitrary process environment value'
)
assert.match(
  runtimeConfiguration,
  /EnvironmentValues[\s\S]*?stemistAllowsAccountEntry/,
  'account visibility must propagate to every presented web module'
)
assert.match(contentView, /configuration\.showsAccountEntry/, 'the Profile account entry must be hidden by default')
assert.match(contentView, /enum\s+StemistTheme/, 'the native shell must use shared semantic theme tokens')
assert.match(contentView, /brand\s*=\s*Color\(red:\s*0\.451,\s*green:\s*0\.341,\s*blue:\s*0\.910\)/, 'the native shell brand must match the production purple token')
assert.match(
  contentView,
  /\.environment\(\\\.stemistAllowsAccountEntry,\s*configuration\.showsAccountEntry\)/,
  'the root view must propagate account visibility into presented web modules'
)
assert.match(contentView, /WebRoute\.ieltsAccount/, 'the account route must remain available for explicit full-function tests')
assert.match(
  contentView,
  /WebRouteLaunch\(\s*url:\s*url,[\s\S]*?allowsAccountEntry:\s*configuration\.showsAccountEntry\s*\)/,
  'normal deep links must not expose the hidden account route'
)
assert.match(contentView, /normalizeSelectedTab/, 'normal mode must recover from a restored hidden Profile tab')
assert.match(
  contentView,
  /selectedTab\s*==\s*\.profile/,
  'normal mode must explicitly guard a restored Profile selection'
)
assert.match(contentView, /onChange\(of:\s*selectedTab/, 'tab selection normalization must also handle state restoration')
assert.match(stemistApp, /@UIApplicationDelegateAdaptor\(StemistAppDelegate\.self\)\s+private\s+var\s+appDelegate/, 'the app delegate must retain cold-launch routes above the root view lifecycle')
assert.doesNotMatch(
  contentView,
  /routeCoordinator:\s*AppRouteCoordinator\s*=\s*AppRouteCoordinator\(\)/,
  'the app-owned main-actor route coordinator must be injected instead of constructed in a nonisolated default argument'
)
assert.match(stemistApp, /didFinishLaunchingWithOptions[\s\S]{0,360}?routeCoordinator\.receive\(url,\s*source:\s*"appDelegate\.didFinishLaunching"\)/, 'the app delegate must retain launch URLs with an explicit source')
assert.match(
  stemistApp,
  /didFinishLaunchingWithOptions[\s\S]{0,360}?routeCoordinator\.observeLifecycle\(\s*"appDelegate\.didFinishLaunching",\s*urlCount:/,
  'debug builds must record whether the app-delegate launch boundary received a URL'
)
assert.match(stemistApp, /application\([\s\S]{0,260}?open\s+url:\s*URL[\s\S]{0,260}?routeCoordinator\.receive\(url,\s*source:\s*"appDelegate\.openURL"\)/, 'the app delegate must retain warm URLs with an explicit source')
assert.match(stemistApp, /configurationForConnecting[\s\S]*?connectionOptions\.urlContexts[\s\S]*?routeCoordinator\.receive\([\s\S]*?context\.url,[\s\S]*?source:\s*"appDelegate\.configurationForConnecting"/, 'cold-launch scene connection must capture URL contexts before the root mounts')
assert.match(
  stemistApp,
  /configurationForConnecting[\s\S]{0,520}?routeCoordinator\.observeLifecycle\(\s*"appDelegate\.configurationForConnecting",\s*urlCount:\s*connectionOptions\.urlContexts\.count/,
  'debug builds must expose whether scene configuration received cold-launch URL contexts'
)
assert.match(stemistApp, /configuration\.delegateClass\s*=\s*StemistSceneDelegate\.self/, 'cold-launch URL delivery must use an explicit scene delegate')
assert.match(stemistApp, /final\s+class\s+StemistSceneDelegate[\s\S]{0,1400}?willConnectTo[\s\S]{0,500}?receive\(connectionOptions\.urlContexts,\s*source:\s*"scene\.willConnectTo"\)/, 'the scene delegate must retain URL contexts during cold launch')
assert.match(
  stemistApp,
  /private\s+func\s+receive\(_\s+contexts:[\s\S]{0,300}?routeCoordinator\.observeLifecycle\(source,\s*urlCount:\s*contexts\.count\)/,
  'debug builds must expose URL counts at every scene lifecycle boundary'
)
assert.match(stemistApp, /func\s+scene\(_\s+scene:\s*UIScene,\s*openURLContexts\s+URLContexts:\s*Set<UIOpenURLContext>\)/, 'the scene delegate must receive URLs delivered after scene connection')
assert.match(stemistApp, /scene\(_\s*scene:\s*UIScene,\s*openURLContexts[\s\S]{0,360}?receive\(URLContexts,\s*source:\s*"scene\.openURLContexts"\)/, 'the scene delegate must retain URLs delivered after scene connection with an explicit source')
assert.doesNotMatch(stemistApp, /routeCoordinator:\s*AppRouteCoordinator\?/, 'scene URL capture must not depend on a nil coordinator delegate')
assert.match(stemistApp, /func\s+peekPendingURL\(\)\s*->\s*URL\?/, 'route coordinator must expose a non-destructive pending URL read')
assert.match(stemistApp, /func\s+acknowledgePendingURL\(_\s+url:\s*URL\)/, 'route coordinator must acknowledge only the URL that was presented')
assert.match(stemistApp, /func\s+receive\(_\s+url:\s*URL,\s*source:\s*String\s*=\s*"unknown"\)\s*\{[\s\S]{0,120}?guard\s+pendingURL\s*!=\s*url\s+else\s*\{\s*return\s*\}/, 'duplicate scene and app URL callbacks must be coalesced while a route is pending')
assert.match(stemistApp, /lastAcknowledgedURL[\s\S]{0,220}?lastAcknowledgedAt/, 'duplicate callbacks arriving after acknowledgement must have a bounded suppression marker')
assert.match(stemistApp, /receive\(_\s+url:\s*URL,\s*source:\s*String[\s\S]{0,420}?lastAcknowledgedURL\s*==\s*url[\s\S]{0,220}?lastAcknowledgedAt/, 'URL deduplication must also cover callbacks delivered after the first route was consumed')
assert.doesNotMatch(stemistApp, /func\s+takePendingURL\(\)/, 'route consumption must not clear a cold-launch URL before presentation succeeds')
assert.match(contentView, /@ObservedObject\s+private\s+var\s+routeCoordinator:\s*AppRouteCoordinator/, 'the root shell must observe the app-owned route coordinator')
assert.match(
  contentView,
  /peekPendingURL\(\)[\s\S]{0,260}?WebRouteLaunch\([\s\S]{0,260}?present\(launch\)/,
  'the root shell must present a retained URL before acknowledging it'
)
assert.match(
  contentView,
  /func\s+acknowledgeMountedLaunch\(_\s+launch:\s*WebRouteLaunch\)[\s\S]{0,520}?pendingLaunch\.id\s*==\s*launch\.id[\s\S]{0,180}?acknowledgePendingURL\(url\)/,
  'a deep link must be acknowledged only after its workspace has mounted'
)
assert.match(
  contentView,
  /WebWorkspaceHost[\s\S]{0,1800}?onChange\(of:\s*launch\.id\)[\s\S]{0,260}?onMount\(launch\)/,
  'a resident workspace must acknowledge a pending deep link when an in-place route replacement changes its launch'
)
assert.match(
  contentView,
  /guard\s+let\s+url\s*=\s*routeCoordinator\.peekPendingURL\(\)[\s\S]{0,260}?guard\s+let\s+launch\s*=\s*WebRouteLaunch\([\s\S]{0,320}?else\s*\{[\s\S]{0,180}?acknowledgePendingURL\(url\)[\s\S]{0,80}?return/,
  'a blocked or malformed deep link must be acknowledged after rejection instead of remaining pending forever'
)
assert.match(
  contentView,
  /\.task\(id:\s*pendingExternalURLTaskID\)[\s\S]{0,1600}?consumePendingExternalURLIfReady\(\)/,
  'cold-launch route consumption must react to the retained URL after the root is mounted'
)
assert.match(
  contentView,
  /\.onAppear\s*\{[\s\S]{0,500}?normalizeSelectedTab\(\)[\s\S]{0,500}?rootIsReady\s*=\s*true/,
  'cold-launch URL contexts received before SwiftUI observation must be consumed again when the root appears'
)
assert.match(
  contentView,
  /\.onChange\(of:\s*rootIsReady\)[\s\S]{0,320}?consumePendingExternalURLIfReady\(\)/,
  'root readiness must actively retry a retained cold-launch URL'
)
assert.match(
  contentView,
  /\.onChange\(of:\s*routeCoordinator\.pendingURL\)[\s\S]{0,220}?consumePendingExternalURLIfReady\(\)/,
  'new URL delivery must trigger the same idempotent pending-route consumer'
)
assert.match(
  contentView,
  /#if DEBUG[\s\S]{0,260}?routeCoordinator\.debugSnapshot[\s\S]{0,180}?webWorkspace\.debugSnapshot/,
  'debug builds must expose both routing and workspace snapshots for lifecycle diagnosis'
)
assert.match(
  contentView,
  /accessibilityIdentifier\("stemist-root"\)[\s\S]{0,220}?#if DEBUG[\s\S]{0,260}?accessibilityValue\("\\\(routeCoordinator\.debugSnapshot\) \| \\\(webWorkspace\.debugSnapshot\)"\)/,
  'the root accessibility element must expose routing diagnostics to the iPad UI suite'
)
assert.match(
  contentView,
  /accessibilityIdentifier\("tab-today"\)[\s\S]{0,220}?accessibilityValue\("\\\(routeCoordinator\.lifecycleRevision\)\|\\\(webWorkspace\.lifecycleRevision\)"\)/,
  'the stable Today tab must expose a monotonic lifecycle token because root accessibility containers may return an empty value'
)
assert.doesNotMatch(
  contentView,
  /scenePhase/,
  'retained deep links must not depend on a lossy scene-phase event ordering'
)
assert.equal(
  (contentView.match(/\.fullScreenCover\(/g) ?? []).length,
  0,
  'learning routes must not depend on SwiftUI full-screen presenter transitions'
)
assert.doesNotMatch(
  contentView,
  /@State\s+private\s+var\s+selectedRoute/,
  'tab-local presentation state races with TabView and List transitions on iPad'
)
assert.match(
  contentView,
  /@StateObject\s+private\s+var\s+webWorkspace\s*=\s*WebWorkspaceCoordinator\(\)/,
  'the root must own one observable workspace coordinator'
)
assert.match(
  contentView,
  /private\s+struct\s+WebWorkspaceHost[\s\S]{0,1600}?var\s+body:\s+some\s+View\s*\{\s*VStack\(spacing:\s*0\)\s*\{[\s\S]{0,600}?WebWorkspaceChrome\([\s\S]{0,600}?WebModuleView\(/,
  'the workspace host must vertically separate chrome from the web view so close controls stay hittable'
)
assert.match(
  contentView,
  /@Published\s+private\(set\)\s+var\s+activeLaunch:\s*WebRouteLaunch\?/,
  'the coordinator must expose the active route to the workspace host'
)
assert.match(
  contentView,
  /@Published\s+private\(set\)\s+var\s+activePresentationID:\s*UUID\?/,
  'the coordinator must expose a presentation identity for stale dismissal protection'
)
// Root-level presentation is driven directly by activeLaunch.
assert.doesNotMatch(contentView, /private\s+var\s+pendingLaunch|private\s+var\s+isDismissing|private\s+var\s+dismissalFallbackTask/, 'route presentation must not depend on modal transition state')
assert.match(
  contentView,
  /func\s+present\(_\s+launch:\s*WebRouteLaunch\)[\s\S]{0,500}?activeLaunch\s*=\s*launch/,
  'the workspace must replace resident content in place and present fresh routes'
)
assert.match(
  contentView,
  /func\s+dismiss\(\)[\s\S]{0,260}?activeLaunch\s*=\s*nil/,
  'the explicit close action must remove the active workspace without modal feedback'
)
assert.match(
  contentView,
  /func\s+completeDismissal\(for\s+presentationID:\s*UUID\?\)[\s\S]{0,300}?activePresentationID\s*==\s*presentationID/,
  'late workspace disappearance callbacks must be scoped to their original presentation'
)
assert.doesNotMatch(contentView, /scheduleDismissalFallback|setPresented/, 'the workspace must not expose unscoped modal callback plumbing')
assert.doesNotMatch(contentView, /@State\s+private\s+var\s+isWorkspacePresented/, 'the root presenter must not maintain a second presentation state')
assert.doesNotMatch(contentView, /workspacePresentation|fullScreenCover/, 'the root must not depend on modal presenter callbacks')
assert.match(
  contentView,
  /ZStack\s*\{/,
  'the workspace must be a root-level immersive overlay'
)
assert.match(contentView, /if\s+let\s+launch\s*=\s*webWorkspace\.activeLaunch/, 'the overlay must render the active route')
assert.match(contentView, /WebWorkspaceHost\(\s*launch:\s*launch/, 'the overlay host must receive the typed launch')
assert.match(contentView, /allowsHitTesting\(webWorkspace\.activeLaunch\s*==\s*nil\)/, 'background tabs must not receive taps while a workspace is open')
assert.match(contentView, /accessibilityHidden\(webWorkspace\.activeLaunch\s*!=\s*nil\)/, 'VoiceOver must stay inside the active workspace')
assert.match(contentView, /\.zIndex\(10\)/, 'the workspace overlay must stay above the tab shell')
assert.match(contentView, /tab-today[\s\S]{0,1200}?tab-ielts[\s\S]{0,1200}?tab-stem[\s\S]{0,1200}?tab-notebook[\s\S]{0,1200}?tab-profile/, 'each tab needs a stable accessibility identifier')
assert.doesNotMatch(
  contentView,
  /queuedWebLaunches|presentNextQueuedWebLaunch/,
  'the root workspace must not call a removed modal queue implementation'
)
assert.match(webModule, /func\s+updateUIView\(_\s+webView:\s*WKWebView[\s\S]{0,500}?requestedURL\s*!=\s*url[\s\S]{0,240}?load\(url,\s*in:\s*webView\)/, 'route changes must update the resident WKWebView instead of rebuilding it')
assert.doesNotMatch(contentView, /WebModuleView\([\s\S]{0,320}?\.id\(launch\.id\)/, 'in-place route changes must not recreate the resident WebModuleView and WKWebView')
assert.match(
  webModule,
  /let\s+dismissWorkspace:\s*\(\)\s*->\s*Void/,
  'the web module must request dismissal through the workspace coordinator'
)
assert.match(
  webModule,
  /EmbeddedWebView\([\s\S]{0,700}?accessibilityIdentifier:\s*"web-module-\\\(route\.id\)"[\s\S]{0,700}?loadWatchdogToken:/,
  'the presented WKWebView must receive a stable route identifier and watchdog binding'
)
assert.doesNotMatch(
  webModule,
  /@Binding\s+private\s+var\s+isDismissing:/,
  'the web module must not independently mutate root dismissal phase state'
)
assert.match(webModule, /let\s+requestLaunch:\s*\(WebRouteLaunch\)\s*->\s*Void/, 'the web module must expose an in-process route request to its parent')
assert.match(contentView, /WebWorkspaceChrome[\s\S]{0,1400}?allowsAccountEntry[\s\S]{0,900}?requestLaunch\(WebRouteLaunch\(route:\s*\.ieltsAccount\)\)[\s\S]{0,900}?accessibilityIdentifier\("web-open-account"\)/, 'the QA-only account control must request an in-process account route')
assert.match(contentView, /private\s+struct\s+WebWorkspaceChrome:\s*View/, 'the native workspace chrome must live in the root host')
assert.match(contentView, /private\s+struct\s+WebWorkspaceChrome[\s\S]{0,1800}?accessibilityIdentifier\("web-close"\)/, 'the root workspace chrome must own the close control')
assert.match(
  contentView,
  /VStack\(spacing:\s*0\)[\s\S]{0,700}?WebWorkspaceChrome\([\s\S]{0,700}?WebModuleView\(/,
  'the host must vertically place native workspace chrome above the embedded web module'
)
assert.doesNotMatch(webModule, /private\s+var\s+workspaceHeader:/, 'the web module must not own host-level dismissal chrome')
assert.doesNotMatch(webModule, /\.toolbar\b/, 'workspace actions must not depend on a delayed NavigationStack toolbar')
assert.match(
  contentView,
  /let\s+openRoute:\s*\(WebRoute\)\s*->\s*Void/,
  'tab content must report typed route intent to the root presenter'
)
assert.match(
  contentView,
  /init\(route:\s*WebRoute\)\s*\{\s*self\.route\s*=\s*route\s*url\s*=\s*route\.url\s*\}/,
  'native route presentation needs an explicit non-failable launch initializer'
)
assert.match(
  contentView,
  /present\(WebRouteLaunch\(route:\s*route\)\)/,
  'native route presentation must use the explicit typed launch initializer'
)
assert.match(packageSwift, /\.iOS\("17\.0"\)/, 'the app should support iPadOS 17 and newer')
assert.doesNotMatch(packageSwift, /\.iOS\("18\.6"\)/, 'the deployment target must not require the newest iPadOS')
assert.match(
  packageSwift,
  /\.executableTarget\([\s\S]*?path:\s*"\."[\s\S]*?exclude:\s*\[\s*"Tests"\s*\]/,
  'the app target must exclude UI-test sources so SwiftPM has no overlapping targets'
)
assert.match(
  packageSwift,
  /bundleIdentifier:\s*"com\.ieltsist\.stemist"/,
  'device builds need a stable App Store Connect bundle identifier'
)
assert.match(
  contentView,
  /init\?\(url:\s*URL,\s*allowsAccountEntry:\s*Bool/,
  'typed routes must parse app deep links with account visibility policy'
)
assert.doesNotMatch(
  contentView,
  /init\?\(url:\s*URL,\s*allowsAccountEntry:\s*Bool\s*=\s*true/,
  'account visibility must be explicit at every deep-link call site'
)
assert.match(
  contentView,
  /\.onOpenURL\s*\{\s*url\s+in[\s\S]{0,220}?routeCoordinator\.receive\(url,\s*source:\s*"contentView\.onOpenURL"\)/,
  'the root view may receive a supplementary URL callback only when it forwards the URL with an explicit source'
)
assert.match(contentView, /queryItems/, 'deep links must support route query parameters')
assert.match(
  contentView,
  /struct\s+WebRouteLaunch\s*:\s*Hashable\s*,\s*Identifiable/,
  'deep links must retain the matched route and its safe launch context'
)
assert.match(
  contentView,
  /WebRouteLaunch\(\s*url:\s*url[\s\S]*?allowsAccountEntry:\s*configuration\.showsAccountEntry\s*\)/,
  'the root deep-link handler must preserve the incoming URL through a typed launch value'
)
assert.match(
  contentView,
  /sensitiveQueryNames/,
  'deep-link context must have an explicit sensitive-query deny list'
)
for (const queryName of ['contractVersion', 'taxonomyId', 'routeId', 'subjectCode', 'stage', 'topicId', 'termIds', 'attemptId', 'returnTo', 'sourceStatus', 'termInventoryStatus', 'availableCount']) {
  assert.match(contentView, new RegExp(`"${queryName}"`, 'i'), `the shared vocabulary context must preserve ${queryName}`)
}
assert.match(
  contentView,
  /contextQueryNames/,
  'incoming URLs must use an explicit context allow list instead of forwarding arbitrary query values'
)
assert.match(contentView, /singletonContextItems/, 'critical one-value vocabulary context must be collected separately from term lists')
assert.match(contentView, /termContextItems/, 'term IDs must have a bounded collection path')
assert.match(
  contentView,
  /singletonContextItems\s*\+\s*termContextItems/,
  'route, attempt and return context must survive before optional term-list values'
)
assert.match(
  contentView,
  /returnURL\.user\s*==\s*nil[\s\S]*?returnURL\.password\s*==\s*nil/,
  'return links must reject embedded credentials'
)
assert.match(
  contentView,
  /host\s*==\s*"ieltsist\.com"\s*\|\|\s*host\.hasSuffix\("\.ieltsist\.com"\)/,
  'absolute return links must remain on a product host'
)
assert.match(
  contentView,
  /returnTo/,
  'STEM vocabulary return context must remain available to the iOS launch URL'
)
assert.match(
  webModule,
  /launchURL/,
  'the WebView must load the sanitized deep-link URL instead of dropping its context'
)
assert.match(
  webModule,
  /init\(launch:\s*WebRouteLaunch\)[\s\S]*?launchURL\s*=\s*launch\.url/,
  'the launch-specific WebView initializer must consume the filtered URL'
)
assert.match(
  webModule,
  /EmbeddedWebView\(\s*url:\s*launchURL/,
  'the embedded browser must receive launch-specific context'
)
assert.match(
  contentView,
  /caseInsensitiveCompare\(expectedItem\.name\)[\s\S]*?matchingItems\.count\s*==\s*1/,
  'deep-link route matching must reject ambiguous duplicate query keys'
)
assert.match(
  contentView,
  /routeQueryItems[\s\S]*?count\s*<=\s*1/,
  'custom-scheme deep links must reject duplicate route query keys'
)
assert.match(
  contentView,
  /structuralRouteIDs/,
  'custom-scheme deep links must collect path and host route IDs'
)
assert.match(
  contentView,
  /normalizedQueryID[\s\S]*?structuralID[\s\S]*?!=\s*structuralID/,
  'custom-scheme deep links must reject conflicting path, host and query route IDs'
)
assert.match(contentView, /ZStack\s*\{/, 'learning workspaces must open as one immersive root-level flow')
assert.match(contentView, /if\s+let\s+launch\s*=\s*webWorkspace\.activeLaunch[\s\S]{0,500}?WebWorkspaceHost\(/, 'the immersive flow must render a typed workspace host')
assert.match(contentView, /accessibilityIdentifier\(/, 'primary routes need stable UI-test identifiers')
assert.match(
  contentView,
  /ForEach\(routes\)[\s\S]{0,1800}?\.frame\(maxWidth:\s*\.infinity,\s*minHeight:\s*52,\s*alignment:\s*\.leading\)[\s\S]{0,160}?\.contentShape\(Rectangle\(\)\)[\s\S]{0,320}?\.buttonStyle\(\.plain\)/,
  'route rows must expose the same full-width hit target that accessibility reports'
)
assert.match(
  contentView,
  /Button\s*\{\s*openRoute\(\.stemNotebook\)[\s\S]{0,800}?\.accessibilityIdentifier\("open-stem-notebook"\)/,
  'the Notebook entry needs a stable native test identifier'
)

assert.match(contentView, /enum WebRoute\s*:/, 'ContentView must define typed web routes')
assert.match(contentView, /openRoute\(\.aiCoach\)/, 'Today must expose the unified AI Coach entry')
for (const route of [
  'ieltsListening',
  'ieltsReading',
  'ieltsWriting',
  'ieltsSpeaking',
  'ieltsVocabulary',
  'stemIG',
  'stemAS',
  'stemA2',
  'stemTopics',
  'stemPastPapers',
  'stemNotebook',
  'stemCoach',
  'ieltsAccount',
  'stemHome',
  'aiCoach',
]) {
  assert.match(contentView, new RegExp(`case ${route}\\b`), `missing route ${route}`)
}
assert.match(contentView, /static let all:\s*\[WebRoute\]/, 'the full route catalog must be available to QA')
assert.match(contentView, /\.stemCoach,/, 'STEM Coach must be reachable from the app shell')
assert.match(contentView, /opensCoachOnLoad/, 'native Coach routes must declare their auto-open behavior')
assert.match(
  contentView,
  /case \.stemCoach, \.aiCoach:\s*true/,
  'STEM and IELTSist Coach routes must request the web Coach surface'
)
for (const host of ['ieltsist.com', 'stem.ieltsist.com']) {
  assert.match(contentView, new RegExp(`https:\\/\\/${host.replaceAll('.', '\\.')}`), `missing product host ${host}`)
}

assert.match(
  contentView,
  /case \.stemIG:[\s\S]*?routeId=cie-0625-igcse-physics[\s\S]*?stage=IGCSE[\s\S]*?course=0625/,
  'IG route must carry an explicit routeId, stage and course'
)
assert.match(
  contentView,
  /case \.stemAS:[\s\S]*?routeId=cie-9702-as-physics[\s\S]*?stage=AS[\s\S]*?course=9702/,
  'AS route must carry an explicit routeId, stage and course'
)
assert.match(
  contentView,
  /case \.stemA2:[\s\S]*?routeId=cie-9702-a2-physics[\s\S]*?stage=A2[\s\S]*?course=9702/,
  'A2 route must carry an explicit routeId, stage and course'
)
assert.ok(fs.existsSync(infoPlistPath), 'the app bundle needs an Info.plist for native deep links')
const infoPlist = fs.readFileSync(infoPlistPath, 'utf8')
assert.match(
  infoPlist,
  /<key>CFBundleDisplayName<\/key>\s*<string>Stemist<\/string>/,
  'the app must expose a stable Stemist display name on the iPad home screen'
)
assert.match(
  infoPlist,
  /<key>CFBundleName<\/key>\s*<string>Stemist<\/string>/,
  'the app bundle must keep a stable product name when display metadata is unavailable'
)
assert.match(
  infoPlist,
  /<key>CFBundleIdentifier<\/key>\s*<string>\$\(PRODUCT_BUNDLE_IDENTIFIER\)<\/string>/,
  'the checked-in Info.plist must let the Xcode app target emit its stable bundle identifier'
)
assert.match(
  infoPlist,
  /<key>CFBundleExecutable<\/key>\s*<string>\$\(EXECUTABLE_NAME\)<\/string>/,
  'the checked-in Info.plist must declare the app executable'
)
assert.match(
  infoPlist,
  /<key>CFBundlePackageType<\/key>\s*<string>APPL<\/string>/,
  'the checked-in Info.plist must declare an application bundle'
)
for (const versionKey of ['CFBundleShortVersionString', 'CFBundleVersion']) {
  assert.match(
    infoPlist,
    new RegExp(`<key>${versionKey}<\\/key>\\s*<string>\\$\\([A-Z_]+\\)<\\/string>`),
    `the checked-in Info.plist must declare ${versionKey} for signed app artifacts`
  )
}
assert.match(infoPlist, /CFBundleURLTypes/, 'Info.plist must declare URL types')
assert.match(infoPlist, /CFBundleURLSchemes/, 'Info.plist must declare URL schemes')
assert.match(infoPlist, /<string>stemist<\/string>/, 'Info.plist must register the stemist scheme')
for (const privacyKey of [
  'NSMicrophoneUsageDescription',
  'NSCameraUsageDescription',
  'NSPhotoLibraryUsageDescription',
]) {
  assert.match(
    infoPlist,
    new RegExp(`<key>${privacyKey}<\\/key>\\s*<string>[^<]+<\\/string>`),
    `the checked-in Info.plist must contain ${privacyKey} for the Xcode app target`
  )
}
assert.match(
  infoPlist,
  /<key>STEMIST_FULL_FEATURE_TEST<\/key>\s*<string>\$\(STEMIST_FULL_FEATURE_TEST\)<\/string>/,
  'Info.plist must contain the build-time QA switch used by internal device builds'
)
assert.match(
  packageSwift,
  /additionalInfoPlistContentFilePath:\s*"Info\.plist"/,
  'the Swift Package app product must include the deep-link Info.plist'
)
assert.doesNotMatch(
  packageSwift,
  /\.testTarget\(/,
  'SwiftPM test targets cannot supply the target application path required by XCUIApplication'
)
assert.match(
  xcodeProject,
  /productType = "com\.apple\.product-type\.application";/,
  'the Xcode project must declare a real Stemist application target'
)
assert.match(
  xcodeProject,
  /productType = "com\.apple\.product-type\.bundle\.ui-testing";/,
  'the shell suite must be built as a genuine UI-testing bundle'
)
assert.match(xcodeProject, /TEST_TARGET_NAME = Stemist;/, 'the UI test bundle must target the Stemist application')
assert.match(xcodeProject, /USES_XCTRUNNER = YES;/, 'the UI test bundle must use Xcode\'s UI test runner')
assert.match(
  xcodeProject,
  /TestTargetID = A00000000000000000000050;/,
  'the Xcode project must bind the UI-test target to the Stemist app target'
)
assert.match(
  xcodeProject,
  /path = Stemist\.swiftpm\/Tests\/StemistShellUITests\/StemistShellUITests\.swift;/,
  'the real UI-test target must compile the shell coverage source'
)
assert.match(xcodeScheme, /BlueprintName = "Stemist"/, 'the shared test scheme must build Stemist')
assert.match(xcodeScheme, /BlueprintName = "StemistShellUITests"/, 'the shared test scheme must execute the UI suite')
assert.match(appScheme, /BlueprintName = "Stemist"/, 'the shared app scheme must build the student artifact target')
assert.ok(fs.existsSync(shellUITestPath), 'the native shell UI suite must exist')
const shellUITests = fs.readFileSync(shellUITestPath, 'utf8')
assert.match(shellUITests, /XCUIApplication/, 'the shell suite must launch the real app')
assert.match(shellUITests, /testStudentBuildHidesAccountEntryAndRejectsAccountDeepLinks/, 'the shell suite must cover student account visibility')
assert.match(shellUITests, /testStudentBuildCanOpenAndCloseEveryIELTSRoute/, 'the shell suite must cover every IELTS route')
assert.match(shellUITests, /testStudentBuildCanOpenAndCloseEverySTEMRoute/, 'the shell suite must cover every STEM route')
assert.match(shellUITests, /testStudentBuildCanNavigateDashboardLearningSpacesAndNotebook/, 'the shell suite must cover dashboard learning spaces and Notebook')
assert.match(shellUITests, /testFullFeatureQABuildKeepsAccountEntryAndAllLearningRoutes/, 'the shell suite must cover QA mode and every learning route')
assert.match(shellUITests, /testFullFeatureQABuildOpensAccountDeepLinkFromColdLaunch/, 'the shell suite must cover cold-launch QA account deep links')
assert.match(shellUITests, /testFullFeatureQABuildQueuesAccountRouteDuringModuleReplacement/, 'the shell suite must cover in-process route replacement during dismissal')
assert.match(shellUITests, /testFullFeatureQABuildReopensWarmAccountDeepLinkAfterModuleReplacement/, 'the shell suite must cover replaying a warm account deep link after replacement')
assert.match(shellUITests, /app\.terminate\(\)[\s\S]{0,220}?openCustomURLFromSafari\(accountURL\)/, 'the student account boundary must also survive a real cold-launch custom-scheme deep link')
assert.match(shellUITests, /app\.buttons\["web-open-account"\]/, 'the QA dismissal regression must use an in-process route request')
assert.doesNotMatch(
  shellUITests,
  /app\.tabBars\.buttons/,
  'iPadOS floating tab controls must be queried through the application button hierarchy'
)
assert.match(
  shellUITests,
  /app\.buttons[\s\S]*?matching\([\s\S]*?label == %@[\s\S]*?visibleLabel[\s\S]*?\)\s*\.firstMatch/,
  'tab navigation must select the first label match because iPadOS exposes nested floating-tab buttons'
)
assert.match(
  shellUITests,
  /tabButton\("Profile"\)/,
  'student mode must verify account-entry absence through the same floating-tab hierarchy used for navigation'
)
assert.match(shellUITests, /XCUIApplication\(bundleIdentifier:\s*"com\.apple\.mobilesafari"\)/, 'the cold-launch custom-scheme regression must retain a real Safari handoff')
assert.match(shellUITests, /openCustomURLFromSafari\(accountURL\)/, 'cold-launch coverage must exercise the account deep link through Safari')
assert.match(shellUITests, /private func openCustomURLDirectly\(_ url: URL\)/, 'warm account replacement must have a deterministic system URL handoff')
assert.match(shellUITests, /XCUIDevice\.shared\.system\.open\(url\)/, 'warm account replacement must use the system default-app URL handoff')
assert.match(shellUITests, /waitForStemistHandoff/, 'the custom-scheme regression must wait for the iOS handoff to finish')
assert.match(
  shellUITests,
  /let\s+workspaceChrome\s*=\s*app\.otherElements\["web-workspace-chrome"\][\s\S]{0,220}?workspaceChrome\.waitForExistence[\s\S]{0,220}?let\s+closeButton\s*=\s*app\.buttons\["web-close"\]/,
  'workspace dismissal tests must wait for native chrome before resolving the global close accessibility element'
)
assert.match(
  shellUITests,
  /let\s+closeFrame\s*=\s*closeButton\.frame[\s\S]{0,260}?guard\s+!closeFrame\.isEmpty\s+else\s+\{\s*return\s*\}[\s\S]{0,260}?closeButton\.coordinate\(withNormalizedOffset:\s*CGVector\(dx:\s*0\.5,\s*dy:\s*0\.5\)\)\.tap\(\)/,
  'workspace dismissal must tap the visible button center after validating a non-empty frame instead of depending on flaky XCTest hit-point inference above WKWebView'
)
assert.doesNotMatch(
  shellUITests,
  /waitUntilHittable\(closeButton/,
  'workspace close coverage must not use XCTest hittability, which can report an invalid activation point for a visible SwiftUI button above WKWebView'
)
assert.match(
  shellUITests,
  /let\s+workspaceChrome\s*=\s*app\.otherElements\["web-workspace-chrome"\][\s\S]{0,1800}?workspaceChrome\.waitForNonExistence\(timeout:\s*3\)[\s\S]{0,2200}?let\s+restoredTabCandidates\s*=\s*app\.buttons\.matching\([\s\S]{0,220}?identifier IN %@[\s\S]{0,500}?restoredTabCandidates\.allElementsBoundByIndex\.first\(where:\s*\{[\s\S]{0,260}?\$0\.exists\s+&&\s+\$0\.isHittable[\s\S]{0,260}?restoredTabCandidates\.firstMatch[\s\S]{0,500}?waitUntilHittable\(restoredTab\)/,
  'workspace dismissal must verify that the native chrome is gone and a root tab is interactive again without using an invalid compound hittability predicate'
)
assert.doesNotMatch(
  shellUITests,
  /identifier IN %@ AND hittable == true/,
  'restored root-tab lookup must not combine identifier IN with XCTest hittability in one predicate'
)
assert.doesNotMatch(
  shellUITests,
  /private\s+func\s+closeWebModule[\s\S]{0,2200}?module\.waitForNonExistence/,
  'workspace dismissal must not use a retained WKWebView accessibility node as the authoritative close signal'
)
assert.match(
  shellUITests,
  /addressField\.tap\(\)[\s\S]{0,520}?safari\.typeText\(url\.absoluteString\)/,
  'Safari custom-scheme input must type through the focused application instead of re-resolving a duplicated iPad address-field element'
)
assert.match(
  shellUITests,
  /addressField\.tap\(\)[\s\S]{0,420}?safari\.typeKey\(\s*["']a["']\s*,\s*modifierFlags:\s*\.command\s*\)[\s\S]{0,220}?safari\.typeText\(url\.absoluteString\)/,
  'each Safari custom-scheme attempt must replace the existing address instead of appending to the previous URL'
)
assert.match(
  shellUITests,
  /waitForCustomURLReplayWindow\(\)[\s\S]{0,520}?closeWebModule\(accountModule[\s\S]{0,520}?openCustomURLDirectly\(accountURL\)[\s\S]{0,320}?reopenedAccountModule\.waitForExistence/,
  'the warm replay regression must wait out duplicate suppression, close the prior module, then reopen the same URL deterministically'
)
assert.match(
  shellUITests,
  /SearchFieldItemView[\s\S]{0,260}?\.firstMatch/,
  'Safari address input must prefer the stable focused search-field identifier over duplicate accessibility labels'
)
assert.doesNotMatch(
  shellUITests,
  /addressField\.typeText\(/,
  'iPad Safari can expose two Address text fields after focus, so typing through the original query is ambiguous'
)
assert.match(
  shellUITests,
  /let\s+promptPredicate\s*=\s*NSPredicate\(format:\s*"label IN %@",\s*buttonLabels\)[\s\S]{0,360}?springboard\.buttons\.matching\(promptPredicate\)\.firstMatch[\s\S]{0,360}?safari\.buttons\.matching\(promptPredicate\)\.firstMatch/,
  'custom-scheme prompt polling must query every accepted label per host so one slow accessibility pass cannot exhaust the deadline'
)
assert.match(
  shellUITests,
  /private func waitForStemistHandoff[\s\S]{0,1800}?previousLifecycleValue[\s\S]{0,1800}?didObserveSafariForeground[\s\S]{0,1800}?didObserveStemistBackground[\s\S]{0,1800}?lifecycleChanged[\s\S]{0,500}?app\.state\s*==\s*\.runningForeground[\s\S]{0,220}?root\.exists/,
  'custom-scheme handoff must observe a new Safari-to-Stemist lifecycle and token, not just an already-foreground app'
)
assert.match(
  shellUITests,
  /private\s+func\s+todayLifecycleProbe\(\)\s*->\s*XCUIElement[\s\S]{0,420}?identifier\s*==\s*%@/,
  'custom-scheme handoff tests must read the stable Today-tab lifecycle token'
)
assert.doesNotMatch(
  shellUITests,
  /if\s+app\.state\s*==\s*\.runningForeground,\s*root\.exists\s*\{\s*return\s+true\s*\}/,
  'custom-scheme handoff must not return early from a stale foreground state'
)
assert.match(
  shellUITests,
  /goButton\.tap\(\)[\s\S]{0,320}?waitForStemistHandoff\(from:\s*safari,\s*previousLifecycleValue:\s*previousLifecycleValue\)/,
  'submitting the Safari URL must wait for the app handoff instead of returning after the prompt tap'
)
assert.doesNotMatch(
  shellUITests,
  /promptButton\.tap\(\)\s*\n\s*return/,
  'a synthesized Open-prompt tap is not proof that iOS launched Stemist'
)
assert.match(
  shellUITests,
  /var\s+didTapOpenPrompt\s*=\s*false[\s\S]{0,1400}?if\s+!didTapOpenPrompt\s*\{[\s\S]{0,1200}?promptButton\.tap\(\)[\s\S]{0,300}?didTapOpenPrompt\s*=\s*true/,
  'custom-scheme handoff must stop querying Safari and SpringBoard prompt elements after the first successful tap'
)
assert.match(
  shellUITests,
  /private func safeHierarchyDescription\(for application: XCUIApplication\)[\s\S]{0,500}?application\.state[\s\S]{0,500}?\.runningForeground[\s\S]{0,500}?application\.debugDescription/,
  'custom-scheme failure diagnostics must not snapshot an application that is no longer foreground'
)
assert.doesNotMatch(
  shellUITests,
  /for\s+label\s+in\s+buttonLabels/,
  'custom-scheme prompt polling must not exhaust its deadline with a label-major accessibility loop'
)
assert.match(shellUITests, /web-module-ielts-account/, 'the shell suite must assert account module visibility by mode')
assert.match(shellUITests, /openAndCloseRoute/, 'the shell suite must assert that launched web modules can be closed')
assert.match(
  shellUITests,
  /private func webModule\(_ identifier: String\) -> XCUIElement[\s\S]*?app\.webViews\[identifier\]/,
  'iPad UI tests must query module identifiers through XCUIElementTypeWebView'
)
assert.doesNotMatch(
  shellUITests,
  /app\.otherElements\[(?:moduleIdentifier|"web-module-)/,
  'module identifiers resolve to WebView elements on iPad and must not be queried as Other elements'
)
assert.match(shellUITests, /XCUIScreen\.main\.screenshot\(\)/, 'UI tests must retain rendered iPad evidence instead of relying on fixed sleeps')
assert.match(shellUITests, /attachment\.lifetime = \.keepAlways/, 'route evidence must survive successful CI test runs')
assert.match(
  shellUITests,
  /private func waitUntilHittable\([\s\S]*?exists == true AND hittable == true[\s\S]*?XCTNSPredicateExpectation/,
  'route tests must wait for controls to become hittable after tab and cover transitions'
)
assert.match(
  shellUITests,
  /private func openAndCloseRoute[\s\S]*?waitUntilHittable(?:ByScrolling)?\(routeButton[\s\S]*?routeButton\.tap\(\)/,
  'route tests must not tap a control while a prior presentation is still dismissing'
)
assert.match(
  shellUITests,
  /private func openAndCloseRoute[\s\S]{0,700}?waitUntilHittableByScrolling\(routeButton\)/,
  'route tests must scroll off-screen rows into view before asserting iPad hittability'
)
assert.match(
  shellUITests,
  /Expected[\s\S]{0,80}buttonIdentifier[\s\S]{0,220}?app\.debugDescription/,
  'route control failures must retain the accessibility hierarchy for diagnosis'
)
assert.doesNotMatch(
  shellUITests,
  /XCTAssertFalse\(\s*module\.waitForExistence\(/,
  'waitForExistence returns immediately for an existing module and cannot wait for dismissal'
)
for (const [buttonIdentifier, moduleIdentifier] of [
  ['route-ielts-listening', 'web-module-ielts-listening'],
  ['route-ielts-reading', 'web-module-ielts-reading'],
  ['route-ielts-writing', 'web-module-ielts-writing'],
  ['route-ielts-speaking', 'web-module-ielts-speaking'],
  ['route-ielts-vocabulary', 'web-module-ielts-vocabulary'],
  ['route-stem-ig', 'web-module-stem-ig'],
  ['route-stem-as', 'web-module-stem-as'],
  ['route-stem-a2', 'web-module-stem-a2'],
  ['route-stem-topics', 'web-module-stem-topics'],
  ['route-stem-past-papers', 'web-module-stem-past-papers'],
  ['route-stem-notebook', 'web-module-stem-notebook'],
  ['route-stem-coach', 'web-module-stem-coach'],
]) {
  assert.match(
    shellUITests,
    new RegExp(`"${buttonIdentifier}"[\\s\\S]*?"${moduleIdentifier}"`),
    `the shell suite must exercise ${buttonIdentifier}`
  )
}
for (const identifier of ['learning-space-ielts-practice', 'learning-space-stem-study', 'learning-space-ai-coach', 'open-notebook', 'open-stem-notebook']) {
  assert.match(shellUITests, new RegExp(`"${identifier}"`), `the shell suite must exercise ${identifier}`)
}

assert.match(
  contentView,
  /case \.aiCoach:[\s\S]*?https:\/\/ieltsist\.com\/#ai-coach/,
  'the native AI Coach route must open the actual IELTSist chat surface'
)
assert.doesNotMatch(
  contentView,
  /case \.aiCoach:[\s\S]*?https:\/\/ai\.ieltsist\.com\//,
  'the API management site must not be presented as the student chat surface'
)

assert.match(webModule, /final class WebViewStore/, 'WebView navigation must be instance scoped')
assert.doesNotMatch(
  webModule,
  /if\s+let\s+loadError\s*\{/,
  'the load-error view must not shadow the @State loadError binding'
)
assert.match(webModule, /processPool\s*=/, 'all product pages must share a WKProcessPool for SSO')
assert.match(webModule, /hasSuffix\("\.ieltsist\.com"\)/, 'product subdomains must stay in the app')
assert.match(webModule, /navigationAction\.targetFrame\s*==\s*nil/, 'target blank links need an in-app policy')
assert.match(webModule, /currentURL/, 'Safari fallback must preserve the current page')
assert.doesNotMatch(webModule, /stemistWebGoBack|stemistWebGoForward/, 'global navigation notifications must be removed')
assert.match(webModule, /static let websiteDataStore\s*=\s*WKWebsiteDataStore\.default\(\)/, 'SSO needs one persistent WebKit data store')
assert.match(webModule, /websiteDataStore\s*=\s*WebViewEnvironment\.websiteDataStore/, 'every product page must use the shared persistent WebKit data store')
assert.match(webModule, /WKUIDelegate/, 'WebKit UI delegate is required for upload and media flows')
assert.match(webModule, /contextMenuConfigurationForElement/, 'WebKit context menus must not cover Pencil writing with copy or lookup actions')
assert.match(webModule, /contextMenuConfigurationForElement[\s\S]{0,420}?completionHandler\(nil\)/, 'the native WebView must explicitly suppress its contextual menu')
assert.match(webModule, /runJavaScriptAlertPanelWithMessage/, 'web alert dialogs must complete on iPad')
assert.match(webModule, /runJavaScriptConfirmPanelWithMessage/, 'web confirm dialogs must complete on iPad')
assert.match(webModule, /runJavaScriptTextInputPanelWithPrompt/, 'web prompt dialogs must complete on iPad')
assert.match(webModule, /UIAlertController/, 'JavaScript dialogs need native iPad presentation')
assert.doesNotMatch(
  webModule,
  /autocapitalizationType\s*=\s*\.sentences/,
  'web prompt input must not silently change case-sensitive values such as verification or invitation codes'
)
assert.match(webModule, /onUnavailable:\s*\{\s*completionHandler\(false\)/, 'unpresentable confirms must fail closed instead of hanging the page')
assert.match(webModule, /onUnavailable:\s*\{\s*completionHandler\(nil\)/, 'unpresentable prompts must complete without inventing input')
assert.match(webModule, /WKUserScript/, 'normal mode must be able to hide account controls inside the web shell')
assert.match(
  webModule,
  /const host = window\.location\.hostname\.toLowerCase\(\);\s*if \(host !== 'ieltsist\.com' && !host\.endsWith\('\.ieltsist\.com'\)\) return;\s*const styleId/s,
  'account hiding must remain scoped to product hosts and leave third-party OAuth pages untouched'
)
assert.match(webModule, /CoachAutoOpenScript/, 'native Coach routes need a bounded web-side open action')
assert.match(webModule, /globalHelpButton/, 'the Coach script must support the IELTSist global Coach trigger')
assert.match(webModule, /ai-coach-trigger/, 'the Coach script must support the STEM Coach trigger')
assert.match(webModule, /setTimeout\(\(\) => observer\.disconnect\(\),\s*10_000\)/, 'the Coach auto-open observer must have a bounded lifetime')
assert.match(webModule, /opensCoachOnLoad/, 'the Coach user script must only run for explicit Coach routes')
assert.doesNotMatch(
  webModule,
  /if\s+opensCoachOnLoad\s*\{[\s\S]{0,500}?addUserScript\(/,
  'Coach auto-open must not be frozen into the WKWebView configuration from its first route'
)
assert.match(
  webModule,
  /openCoachIfRequested[\s\S]{0,500}?parent\.opensCoachOnLoad[\s\S]{0,500}?evaluateJavaScript\(\s*CoachAutoOpenScript\.open/,
  'Coach injection must read the current dynamic route instead of the WKWebView creation route'
)
assert.match(
  webModule,
  /didFinish[\s\S]{0,900}?openCoachIfRequested\(in:\s*webView\)/,
  'each completed navigation must run the route-aware Coach injection hook'
)
assert.match(
  webModule,
  /if\s+!allowsAccountEntry\s*\{[\s\S]*?addUserScript\(/,
  'account-hiding JavaScript must only be installed outside full-function test mode'
)
assert.match(webModule, /injectionTime:\s*\.atDocumentStart/, 'account controls must be hidden before the product page renders')
assert.match(webModule, /forMainFrameOnly:\s*true/, 'account-hiding JavaScript must stay scoped to the product document')
assert.match(webModule, /#sidebarAccountEntry/, 'the account visibility script must target the production account button')
assert.match(webModule, /sidebar-account-entry/, 'the account visibility script must target the production account entry')
assert.ok(
  webModule.includes("replace(/\\\\s+/g, ' ')"),
  'JavaScript regular-expression escapes must remain escaped inside the Swift multiline string'
)
assert.match(webModule, /data-view=\\?"mine/, 'the account visibility script must cover SPA account navigation')
assert.match(webModule, /data-home-action=\\?"mine/, 'the account visibility script must cover dashboard account actions')
assert.match(webModule, /account-trigger/, 'the account visibility script must target the STEM header account entry')
assert.match(webModule, /Sign in to STEM/, 'the account visibility script must cover the STEM sign-in control')
assert.match(webModule, /Log in or create account/, 'the account visibility script must cover the STEM content account action')
assert.match(webModule, /allowsAccountEntry/, 'WebView configuration must receive the explicit account visibility mode')
assert.match(webModule, /static func isAccountEntry\(_ url: URL\)/, 'the product policy must identify account navigation explicitly')
assert.match(
  webModule,
  /if\s+!parent\.allowsAccountEntry\s*&&\s*ProductWebPolicy\.isAccountEntry\(targetURL\)[\s\S]{0,140}?decisionHandler\(\.cancel\)/,
  'student WebViews must block hidden account routes even when a page navigates there programmatically'
)
assert.match(readme, /Normal-mode WebViews also hide the known account controls/, 'the account-hiding behavior must be documented as presentation-only')
assert.match(readme, /Product deep links resolve to a typed route/, 'the safe deep-link context boundary must be documented for QA')
assert.match(
  webModule,
  /const pendingRoots = new Set\(\)/,
  'account visibility updates must batch only newly changed DOM roots'
)
assert.match(
  webModule,
  /new MutationObserver\(\(records\) =>/,
  'account visibility updates must inspect mutation records instead of rescanning the page'
)
assert.match(
  webModule,
  /record\.addedNodes\.forEach/,
  'account visibility updates must inspect added nodes directly'
)
assert.match(webModule, /record\.type\s*===\s*["']attributes["']/, 'account visibility must react when SPA controls change attributes')
assert.match(webModule, /attributeFilter/, 'account visibility must limit attribute observation to account-related changes')
assert.match(
  webModule,
  /requestAnimationFrame\(flushPendingRoots\)/,
  'account visibility updates must be coalesced into one animation-frame pass'
)
assert.doesNotMatch(
  webModule,
  /const observer = new MutationObserver\(install\)/,
  'account visibility updates must not rescan every interactive element for each DOM mutation'
)
assert.match(
  webModule,
  /if\s+ProductWebPolicy\.isAllowed\(targetURL\)\s*\|\|\s*ExternalWebPolicy\.canKeepAuthenticationRedirect\(targetURL,\s*from:\s*webView\.url\)/,
  'OAuth popup redirects must remain in the shared WebView session'
)
assert.match(webModule, /runOpenPanelWith/, 'writing and question uploads need a document picker')
assert.match(
  webModule,
  /#if\s+compiler\(>=6\.0\)[\s\S]*?WKOpenPanelParameters[\s\S]*?#endif/,
  'the iOS 18.4 file-picker API must be conditionally compiled for older SDKs'
)
assert.match(webModule, /requestMediaCapturePermissionFor/, 'speaking needs an explicit media permission policy')
assert.match(webModule, /PenInputBehaviorScript/, 'iPad pen input needs a scoped selection-protection script')
assert.match(contentView, /var showsBrowserNavigation: Bool/, 'Web routes must declare immersive browser chrome policy')
assert.match(webModule, /if route\.showsBrowserNavigation/, 'practice modules must hide the bottom browser navigation bar')
assert.match(webModule, /accessibilityIdentifier\("web-browser-navigation"\)/, 'browser navigation needs a stable accessibility identifier')
assert.match(webModule, /import\s+PencilKit/, 'iPad writing must have a native PencilKit capture path')
assert.match(webModule, /NativePencilSurfaceScript/, 'native PencilKit capture must discover explicit web ink surfaces')
assert.match(webModule, /data-ink-interactive/, 'native PencilKit capture must ignore disabled and read-only surfaces')
assert.match(webModule, /dataset\.inkSurfaceId/, 'native PencilKit capture must require a stable web surface ID')
assert.match(webModule, /data-ink-surface-id/, 'surface ID changes must refresh native PencilKit hit regions')
assert.match(webModule, /data-ink-tool/, 'native PencilKit capture must follow the web tool selection')
assert.match(webModule, /coordinateSpace[\s\S]{0,120}webViewViewport/, 'native Pencil strokes must declare their WebView coordinate space')
assert.match(webModule, /surfaceFrame[\s\S]{0,220}surfaceFrame/, 'native Pencil strokes must carry the matched surface frame')
assert.match(webModule, /convert\(localLocation, to: self\)/, 'PencilKit points must be converted into the WebView viewport space')
assert.match(webModule, /consumePendingStrokes/, 'native PencilKit must not drop rapid consecutive strokes')
assert.match(webModule, /for stroke in strokes/, 'native PencilKit must preserve stroke boundaries when flushing')
assert.match(webModule, /visualViewport\?\.addEventListener/, 'surface frames must refresh when the iPad visual viewport moves')
assert.match(webModule, /Fail closed when a page has only the legacy surface marker/, 'legacy ink markers must not let the native overlay swallow unbridged input')
assert.match(webModule, /data-ink-surface="handwriting"\]\[data-ink-interactive="true"/, 'selection protection must target interactive handwriting surfaces')
assert.match(webModule, /data-ink-surface="pdf"\]\[data-ink-interactive="true"/, 'selection protection must target interactive PDF ink surfaces')
assert.match(webModule, /drawingPolicy\s*=\s*\.pencilOnly/, 'native PencilKit capture must be Pencil-only so finger scrolling passes through')
assert.match(webModule, /stemist-native-pencil-stroke/, 'native PencilKit strokes must be returned to the web ink model')
assert.match(webModule, /func\s+forwardLatestPencilStroke\(\)/, 'native PencilKit strokes must flush through the WebView bridge')
assert.match(webModule, /static let handlerName = "stemistPenInput"/, 'pen activity must have a native WebView message channel')
assert.match(webModule, /isTextInteractionEnabled\s*=\s*true/, 'WebKit text interaction must remain stable while drawing CSS and the delegate suppress selection')
assert.doesNotMatch(webModule, /isTextInteractionEnabled\s*=\s*!active/, 'WebKit must not reconfigure text interaction during a Pencil stroke')
assert.match(webModule, /const releasePen[\s\S]{0,320}?activePenPointers\.delete\(event\.pointerId\)[\s\S]{0,180}?notifyPenActivity\(false\)/, 'the WebView must observe the end of a Pencil stroke and restore the pen activity channel')
assert.match(webModule, /addEventListener\(['"]pointerup['"],\s*releasePen/, 'the WebView must observe the end of a Pencil stroke')
assert.match(webModule, /handwriting-pad__canvas\[data-ink-interactive/, 'handwriting canvases must be protected only when interactive')
assert.match(webModule, /pdf-ink-layer\[data-ink-interactive/, 'PDF ink canvases must be protected only when interactive')
assert.match(webModule, /-webkit-user-select:\s*none/, 'drawing surfaces must opt out of native text selection')
assert.match(webModule, /-webkit-touch-callout:\s*none/, 'drawing surfaces must suppress the iPad callout menu')
assert.match(webModule, /touch-action:\s*none/, 'drawing surfaces must retain pen pointer ownership')
assert.match(webModule, /const scrollSelector = ['"]\.pdf-canvas-scroll/, 'PDF scrolling must have an explicit native touch-action policy')
assert.match(webModule, /const activePenPointers = new Set\(\)/, 'Pencil selection suppression must be scoped to active Pencil pointers')
assert.match(webModule, /const isEditableTarget = /, 'global selection suppression must preserve editable controls')
assert.match(webModule, /const clearReadOnlySelection = /, 'non-editable WebView text must clear system selection handles')
assert.match(webModule, /document\.addEventListener\('selectionchange', clearReadOnlySelection, true\)/, 'system text selection must be suppressed outside editable controls')
assert.doesNotMatch(webModule, /const drawingSelector = \[[\s\S]{0,160}['"]canvas['"]\s*,/, 'selection protection must not apply touch-action:none to every PDF base canvas')
assert.match(webModule, /pointerType\s*!==\s*['"]pen['"]/, 'pen pointer capture must stay scoped to Apple Pencil input')
assert.match(webModule, /CameraCaptureIntentScript/, 'Take photo must have an explicit native camera intent bridge')
assert.match(webModule, /window\.__stemistCameraIntentAt\s*=\s*Date\.now\(\)/, 'camera intent must be recorded synchronously before the hidden input opens')
assert.match(webModule, /resolveCameraCaptureIntent\(in:\s*webView/, 'the native open panel must recheck the DOM camera intent before falling back to Files')
assert.match(webModule, /window\.__stemistCameraIntentAt/, 'native camera fallback must inspect the web intent timestamp when message delivery races')
assert.match(webModule, /WKScriptMessageHandler/, 'the WebView must receive the camera intent from the product page')
assert.match(webModule, /UIImagePickerController\.isSourceTypeAvailable\(\.camera\)/, 'Take photo must verify camera availability')
assert.match(webModule, /sourceType\s*=\s*\.camera/, 'Take photo must present the native camera picker')
assert.match(webModule, /AVCaptureDevice\.requestAccess\(for:\s*\.video\)/, 'camera permission must be requested before presenting capture')
assert.match(webModule, /presentCameraAttachmentFailure/, 'camera conversion failures must remain visible instead of silently returning an empty upload')
assert.match(webModule, /Photo could not be attached/, 'camera conversion failures need an actionable student-facing message')
assert.match(webModule, /Choose Upload photo instead/, 'camera-unavailable state must direct the user to the separate upload flow')
assert.match(webModule, /userInterfaceIdiom\s*==\s*\.pad/, 'iPad input needs a dedicated gesture policy')
assert.match(webModule, /allowedTouchTypes/, 'the scroll gesture must not consume Apple Pencil input')
assert.match(webModule, /TouchType\.direct/, 'finger scrolling must remain enabled on iPad')
assert.match(webModule, /TouchType\.indirectPointer/, 'trackpad and pointer scrolling must remain enabled on iPad')
assert.match(webModule, /WebContentProcessDidTerminate/, 'a crashed web content process must recover')
assert.match(
  webModule,
  /func\s+load\([\s\S]*?hasRetriedAfterTermination\s*=\s*false/,
  'each new route or reload must get one fresh web-content-process retry'
)
assert.match(
  webModule,
  /func\s+updateNavigationState[\s\S]*?lastReloadToken\s*=\s*parent\.reloadToken[\s\S]*?hasRetriedAfterTermination\s*=\s*false/,
  'a student-initiated reload must reset the one-retry web-process budget'
)
assert.match(webModule, /loadWatchdogToken/, 'the load watchdog must restart for every navigation attempt')
assert.match(webModule, /task\(id:\s*loadWatchdogToken\)/, 'the watchdog task must be keyed by navigation attempts')
assert.match(webModule, /parent\.loadWatchdogToken\s*=\s*UUID\(\)/, 'WebKit navigation callbacks must restart the watchdog')
assert.doesNotMatch(webModule, /task\(id:\s*reloadToken\)/, 'the watchdog must not be tied only to manual reloads')
assert.match(webModule, /Task\.sleep\(nanoseconds:\s*WebModuleTiming\.loadTimeoutNanoseconds\)/, 'the load watchdog must use an explicit bounded timeout')
assert.match(webModule, /func\s+stopLoading\(\)/, 'the web shell must expose an explicit loading cancellation path')
assert.match(
  webModule,
  /webViewStore\.stopLoading\(\)[\s\S]*?loadError\s*=\s*"The page is taking longer than expected\./,
  'a watchdog timeout must stop the pending request before showing its recoverable error state'
)
assert.match(webModule, /stopForDismissal/, 'leaving a web module must stop active media and loading')
assert.match(webModule, /func\s+pauseForHiding\(\)[\s\S]{0,700}?evaluateJavaScript\(/, 'closing a workspace must pause active media')
assert.match(
  contentView,
  /private\s+struct\s+WebWorkspaceChrome[\s\S]{0,1800}?dismissWorkspace\(\)/,
  'the root close control must dismiss the workspace without depending on WebView toolbar timing'
)
assert.match(
  contentView,
  /private\s+struct\s+WebWorkspaceChrome[\s\S]{0,2200}?accessibilityElement\(children:\s*\.contain\)[\s\S]{0,240}?accessibilityIdentifier\("web-workspace-chrome"\)/,
  'the workspace chrome must preserve separate native controls in the iPad accessibility tree'
)
assert.match(
  contentView,
  /private\s+struct\s+WebWorkspaceHost[\s\S]{0,2400}?accessibilityElement\(children:\s*\.contain\)[\s\S]{0,260}?accessibilityIdentifier\("web-workspace-host"\)/,
  'the workspace host must expose an explicit accessibility container around the embedded module'
)
assert.match(
  contentView,
  /private\s+struct\s+WebWorkspaceHost[\s\S]{0,500}?VStack\(spacing:\s*0\)[\s\S]{0,1200}?WebWorkspaceChrome\([\s\S]{0,900}?WebModuleView\(/,
  'the workspace host must vertically separate the web module from native chrome so iPad controls stay visible and hittable'
)
assert.match(
  webModule,
  /onDisappear\s*\{[\s\S]*?stopForDismissal\(\)/,
  'the loading and media cleanup must run when the full-screen module is dismissed'
)
assert.match(webModule, /UTType\.pdf/, 'writing and source-paper uploads must accept PDF files')
assert.match(webModule, /canKeepAuthenticationRedirect/, 'server auth redirects need a dedicated allowlist policy')
assert.doesNotMatch(
  webModule,
  /guard\s+navigationType\s*==\s*\.other/,
  'authentication redirects must not depend on one WebKit navigation type'
)
assert.match(contentView, /matchesQueryItems/, 'deep-link matching must allow additive query context')
assert.doesNotMatch(
  contentView,
  /guard\s+!expectedItems\.isEmpty\(\)\s+else\s*\{\s*return incomingItems\.isEmpty\s*\}/s,
  'routes without a base query must still accept additive context parameters'
)
assert.doesNotMatch(
  `${contentView}\n${webModule}\n${runtimeConfiguration}`,
  /(?:api[_-]?key|secret|password)\s*[=:]\s*["'][^"']+["']/i,
  'the app source must not contain embedded credentials'
)

assert.match(packageSwift, /capabilities:\s*\[/, 'the iOS product must declare privacy-sensitive capabilities')
assert.match(packageSwift, /\.microphone\s*\(\s*purposeString:/, 'microphone usage must have a user-facing purpose')
assert.match(packageSwift, /\.camera\s*\(\s*purposeString:/, 'camera usage must have a user-facing purpose')
assert.match(packageSwift, /\.photoLibrary\s*\(\s*purposeString:/, 'photo-library usage must have a user-facing purpose')
assert.match(codemagic, /INFOPLIST_KEY_NSMicrophoneUsageDescription/, 'CI must inject the microphone usage description')
assert.match(codemagic, /INFOPLIST_KEY_NSCameraUsageDescription/, 'CI must inject the camera usage description')
assert.match(codemagic, /INFOPLIST_KEY_NSPhotoLibraryUsageDescription/, 'CI must inject the photo-library usage description')
assert.match(codemagic, /(?:^|\n)\s*STEMIST_FULL_FEATURE_TEST=YES\s*\\/, 'Codemagic must build a separate internal QA app with the full-feature switch')
assert.match(codemagic, /xcodebuild test/, 'Codemagic must execute the full native shell UI suite')
assert.match(codemagic, /-project "\$CM_BUILD_DIR\/StemistUITests\.xcodeproj"/, 'Codemagic UI tests must use the real Xcode project')
assert.match(codemagic, /-scheme StemistShellUITests/, 'Codemagic must run the shared UI-test scheme')
assert.match(codemagic, /PlistBuddy/, 'CI must verify privacy metadata in the built app')
assert.match(codemagic, /Print :CFBundleIdentifier/, 'Codemagic must verify the stable bundle identifier')
assert.match(codemagic, /com\.ieltsist\.stemist/, 'Codemagic must check the expected bundle identifier value')
assert.match(codemagic, /Print :CFBundleDisplayName/, 'Codemagic must verify the stable display name')
assert.match(codemagic, /Print :CFBundleName/, 'Codemagic must verify the stable bundle name')
assert.match(
  codemagic,
  /Print :STEMIST_FULL_FEATURE_TEST' "\$PLIST"\)" = "NO"/,
  'Codemagic must reject a student artifact that exposes full-feature account UI'
)
assert.match(
  codemagic,
  /Print :STEMIST_FULL_FEATURE_TEST' "\$QA_PLIST"\)" = "YES"/,
  'Codemagic must prove the internal QA artifact exposes full-feature account UI'
)
assert.ok(fs.existsSync(githubWorkflowPath), 'a macOS CI build is required when Windows cannot compile Swift')
const githubWorkflow = fs.readFileSync(githubWorkflowPath, 'utf8')
assert.match(githubWorkflow, /runs-on:\s*macos-15/, 'macOS CI must use the macOS 15 Apple runner')
assert.match(
  githubWorkflow,
  /group:\s*ios-simulator-\$\{\{\s*github\.workflow\s*\}\}-\$\{\{\s*github\.event_name\s*\}\}-\$\{\{\s*github\.ref\s*\}\}/,
  'push and pull-request simulator evidence must use separate concurrency groups'
)
assert.match(githubWorkflow, /DEVELOPER_DIR:\s*\/Applications\/Xcode_16\.4\.app\/Contents\/Developer/, 'macOS CI must select Xcode 16.4 for XCUIApplication deep links')
assert.match(githubWorkflow, /xcodebuild[\s\S]*iphonesimulator/, 'macOS CI must compile the iOS Simulator product')
assert.match(githubWorkflow, /xcodebuild test/, 'macOS CI must run native shell UI tests')
assert.match(
  githubWorkflow,
  /-project "\$GITHUB_WORKSPACE\/StemistUITests\.xcodeproj"/,
  'native shell tests must use the real Xcode project with the configured target application'
)
assert.match(
  githubWorkflow,
  /-scheme StemistShellUITests[\s\S]*?-only-testing:StemistShellUITests\/StemistShellUITests\/testStudentBuildHidesAccountEntryAndRejectsAccountDeepLinks\s+\\/,
  'macOS CI must start the explicit student-only shell suite with the account-visibility test'
)
assert.match(
  githubWorkflow,
  /set \+e[\s\S]*?xcodebuild test[\s\S]*?-project "\$GITHUB_WORKSPACE\/StemistUITests\.xcodeproj"[\s\S]*?STEMIST_FULL_FEATURE_TEST=NO/,
  'macOS CI must use the app/UI-test project for the student UI test'
)
assert.match(
  githubWorkflow,
  /STUDENT_UI_TEST_STATUS=\$\{PIPESTATUS\[0\]\}[\s\S]*?xcodebuild test[\s\S]*?-project "\$GITHUB_WORKSPACE\/StemistUITests\.xcodeproj"[\s\S]*?STEMIST_FULL_FEATURE_TEST=YES/,
  'macOS CI must use the app/UI-test project for the QA UI test'
)
assert.match(githubWorkflow, /STEMIST_FULL_FEATURE_TEST=NO/, 'macOS CI must run the student UI test mode')
assert.match(githubWorkflow, /STEMIST_FULL_FEATURE_TEST=YES/, 'macOS CI must run the QA UI test mode')
assert.match(
  githubWorkflow,
  /-only-testing:StemistShellUITests\/StemistShellUITests\/testFullFeatureQABuildKeepsAccountEntryAndAllLearningRoutes/,
  'macOS CI must execute the complete QA learning flow'
)
assert.match(
  codemagic,
  /-only-testing:StemistShellUITests\/StemistShellUITests\/testFullFeatureQABuildKeepsAccountEntryAndAllLearningRoutes/,
  'Codemagic must execute the complete QA learning flow'
)
assert.match(
  githubWorkflow,
  /-only-testing:StemistShellUITests\/StemistShellUITests\/testFullFeatureQABuildOpensAccountDeepLinkFromColdLaunch/,
  'macOS CI must execute the cold-launch account regression'
)
assert.match(
  codemagic,
  /-only-testing:StemistShellUITests\/StemistShellUITests\/testFullFeatureQABuildOpensAccountDeepLinkFromColdLaunch/,
  'Codemagic must execute the cold-launch account regression'
)
assert.match(
  githubWorkflow,
  /-only-testing:StemistShellUITests\/StemistShellUITests\/testFullFeatureQABuildQueuesAccountRouteDuringModuleReplacement/,
  'macOS CI must execute the in-process module replacement regression'
)
assert.match(
  codemagic,
  /-only-testing:StemistShellUITests\/StemistShellUITests\/testFullFeatureQABuildQueuesAccountRouteDuringModuleReplacement/,
  'Codemagic must execute the in-process module replacement regression'
)
assert.match(
  githubWorkflow,
  /-only-testing:StemistShellUITests\/StemistShellUITests\/testFullFeatureQABuildReopensWarmAccountDeepLinkAfterModuleReplacement/,
  'macOS CI must execute the warm account deep-link replay regression'
)
assert.match(
  codemagic,
  /-only-testing:StemistShellUITests\/StemistShellUITests\/testFullFeatureQABuildReopensWarmAccountDeepLinkAfterModuleReplacement/,
  'Codemagic must execute the warm account deep-link replay regression'
)

const studentShellTests = [
  'testStudentBuildHidesAccountEntryAndRejectsAccountDeepLinks',
  'testStudentBuildCanOpenAndCloseEveryIELTSRoute',
  'testStudentBuildCanOpenAndCloseEverySTEMRoute',
  'testStudentBuildCanNavigateDashboardLearningSpacesAndNotebook',
]
for (const [workflowName, workflow] of [
  ['GitHub Actions', githubWorkflow],
  ['Codemagic', codemagic],
]) {
  for (const testName of studentShellTests) {
    assert.match(
      workflow,
      new RegExp(`-only-testing:StemistShellUITests/StemistShellUITests/${testName}`),
      `${workflowName} must run the student-only UI test ${testName}`
    )
  }
  assert.doesNotMatch(
    workflow,
    /-only-testing:StemistShellUITests\s+\\/,
    `${workflowName} must not run the QA test inside the student-mode invocation`
  )
}
assert.match(githubWorkflow, /student-shell-ui-tests\.log/, 'macOS CI must retain the student UI test log')
assert.match(githubWorkflow, /qa-shell-ui-tests\.log/, 'macOS CI must retain the QA UI test log')
assert.match(githubWorkflow, /PlistBuddy/, 'macOS CI must verify generated app metadata')
assert.match(githubWorkflow, /Print :CFBundleIdentifier/, 'macOS CI must verify the stable bundle identifier')
assert.match(githubWorkflow, /com\.ieltsist\.stemist/, 'macOS CI must check the expected bundle identifier value')
assert.match(githubWorkflow, /Print :CFBundleDisplayName/, 'macOS CI must verify the stable display name')
assert.match(githubWorkflow, /Print :CFBundleName/, 'macOS CI must verify the stable bundle name')
assert.match(
  githubWorkflow,
  /Print :STEMIST_FULL_FEATURE_TEST' "\$PLIST"\)" = "NO"/,
  'macOS CI must reject a student artifact that exposes full-feature account UI'
)
assert.match(
  githubWorkflow,
  /Print :STEMIST_FULL_FEATURE_TEST' "\$QA_PLIST"\)" = "YES"/,
  'macOS CI must prove the internal QA artifact exposes full-feature account UI'
)
assert.match(githubWorkflow, /(?:^|\n)\s*STEMIST_FULL_FEATURE_TEST=YES\s*\\/, 'macOS CI must build a separate QA app with the full-feature switch')

for (const [workflowName, workflow] of [
  ['GitHub Actions', githubWorkflow],
  ['Codemagic', codemagic],
]) {
  assert.match(workflow, /xcrun simctl create/, `${workflowName} must create an isolated iPad simulator for launch verification`)
  assert.match(workflow, /xcrun simctl bootstatus/, `${workflowName} must wait for the simulator boot to complete`)
  assert.match(workflow, /xcodebuild test/, `${workflowName} must execute the native UI suite instead of a screenshot-only smoke test`)
  assert.match(workflow, /-scheme StemistShellUITests/, `${workflowName} must use the shared real UI-test scheme`)
  assert.match(workflow, /-resultBundlePath/, `${workflowName} must retain the XCTest result bundle as test evidence`)
  assert.match(workflow, /\.xcresult/, `${workflowName} must publish XCTest result bundles for both modes`)
  assert.doesNotMatch(workflow, /\bsleep\s+2\b/, `${workflowName} must not treat a fixed two-second wait as route acceptance evidence`)
}

console.log('iOS navigation contract passed.')
