import assert from 'node:assert/strict'
import fs from 'node:fs'

const contentView = fs.readFileSync('Stemist.swiftpm/ContentView.swift', 'utf8')
const webModule = fs.readFileSync('Stemist.swiftpm/WebModuleView.swift', 'utf8')
const packageSwift = fs.readFileSync('Stemist.swiftpm/Package.swift', 'utf8')
const codemagic = fs.readFileSync('codemagic.yaml', 'utf8')
const readme = fs.readFileSync('README.md', 'utf8')
const gitignore = fs.readFileSync('.gitignore', 'utf8')
const infoPlistPath = 'Stemist.swiftpm/Info.plist'
const githubWorkflowPath = '.github/workflows/ios-simulator.yml'
const cachedManifestPath = 'Stemist.swiftpm/.swiftpm/playgrounds/CachedManifest.plist'

assert.ok(
  !fs.existsSync(cachedManifestPath),
  'stale Swift Playgrounds manifest cache must not override the checked-in package metadata'
)
assert.match(gitignore, /Stemist\.swiftpm\/\.swiftpm\/playgrounds\/CachedManifest\.plist/)

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
  /EnvironmentValues[\s\S]*?stemistAllowsAccountEntry/,
  'account visibility must propagate to every presented web module'
)
assert.match(contentView, /configuration\.showsAccountEntry/, 'the Profile account entry must be hidden by default')
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
assert.match(packageSwift, /\.iOS\("17\.0"\)/, 'the app should support iPadOS 17 and newer')
assert.doesNotMatch(packageSwift, /\.iOS\("18\.6"\)/, 'the deployment target must not require the newest iPadOS')
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
assert.match(contentView, /\.onOpenURL\s*\{/, 'the root view must accept app deep links')
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
assert.match(contentView, /fullScreenCover\(item:/, 'learning workspaces must open as immersive full-screen flows')
assert.match(contentView, /accessibilityIdentifier\(/, 'primary routes need stable UI-test identifiers')

assert.match(contentView, /enum WebRoute\s*:/, 'ContentView must define typed web routes')
assert.match(contentView, /selectedRoute\s*=\s*\.aiCoach/, 'Today must expose the unified AI Coach entry')
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
assert.match(infoPlist, /CFBundleURLTypes/, 'Info.plist must declare URL types')
assert.match(infoPlist, /CFBundleURLSchemes/, 'Info.plist must declare URL schemes')
assert.match(infoPlist, /<string>stemist<\/string>/, 'Info.plist must register the stemist scheme')
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
assert.match(webModule, /CoachAutoOpenScript/, 'native Coach routes need a bounded web-side open action')
assert.match(webModule, /globalHelpButton/, 'the Coach script must support the IELTSist global Coach trigger')
assert.match(webModule, /ai-coach-trigger/, 'the Coach script must support the STEM Coach trigger')
assert.match(webModule, /setTimeout\(\(\) => observer\.disconnect\(\),\s*10_000\)/, 'the Coach auto-open observer must have a bounded lifetime')
assert.match(webModule, /opensCoachOnLoad/, 'the Coach user script must only run for explicit Coach routes')
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
assert.match(
  webModule,
  /onDisappear\s*\{[\s\S]*?stopForDismissal\(\)/,
  'the media cleanup must run when the full-screen module is dismissed'
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
assert.match(codemagic, /PlistBuddy/, 'CI must verify privacy metadata in the built app')
assert.match(codemagic, /Print :CFBundleIdentifier/, 'Codemagic must verify the stable bundle identifier')
assert.match(codemagic, /com\.ieltsist\.stemist/, 'Codemagic must check the expected bundle identifier value')
assert.match(codemagic, /Print :CFBundleDisplayName/, 'Codemagic must verify the stable display name')
assert.match(codemagic, /Print :CFBundleName/, 'Codemagic must verify the stable bundle name')
assert.ok(fs.existsSync(githubWorkflowPath), 'a macOS CI build is required when Windows cannot compile Swift')
const githubWorkflow = fs.readFileSync(githubWorkflowPath, 'utf8')
assert.match(githubWorkflow, /runs-on:\s*macos-14|runs-on:\s*macos-latest/, 'macOS CI must use an Apple runner')
assert.match(githubWorkflow, /xcodebuild[\s\S]*iphonesimulator/, 'macOS CI must compile the iOS Simulator product')
assert.match(githubWorkflow, /PlistBuddy/, 'macOS CI must verify generated app metadata')
assert.match(githubWorkflow, /Print :CFBundleIdentifier/, 'macOS CI must verify the stable bundle identifier')
assert.match(githubWorkflow, /com\.ieltsist\.stemist/, 'macOS CI must check the expected bundle identifier value')
assert.match(githubWorkflow, /Print :CFBundleDisplayName/, 'macOS CI must verify the stable display name')
assert.match(githubWorkflow, /Print :CFBundleName/, 'macOS CI must verify the stable bundle name')
assert.match(githubWorkflow, /(?:^|\n)\s*STEMIST_FULL_FEATURE_TEST=YES\s*\\/, 'macOS CI must build a separate QA app with the full-feature switch')

for (const [workflowName, workflow] of [
  ['GitHub Actions', githubWorkflow],
  ['Codemagic', codemagic],
]) {
  assert.match(workflow, /xcrun simctl create/, `${workflowName} must create an isolated iPad simulator for launch verification`)
  assert.match(workflow, /xcrun simctl bootstatus/, `${workflowName} must wait for the simulator boot to complete`)
  assert.match(workflow, /xcrun simctl install/, `${workflowName} must install the built app before launch verification`)
  assert.match(workflow, /xcrun simctl launch/, `${workflowName} must launch the app in the simulator`)
  assert.match(workflow, /QA_APP_PATH/, `${workflowName} must install the separately built full-function QA app`)
  assert.match(
    workflow,
    /xcrun simctl openurl[\s\S]*?stemist:\/\/open\/ielts-account/,
    `${workflowName} must exercise the otherwise hidden account route only after full-function QA launch`
  )
  assert.ok(
    (workflow.match(/xcrun simctl launch/g) ?? []).length >= 2,
    `${workflowName} must launch both normal student mode and full-function QA mode`
  )
}

console.log('iOS navigation contract passed.')
