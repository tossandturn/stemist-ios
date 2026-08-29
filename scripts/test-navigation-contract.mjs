import assert from 'node:assert/strict'
import fs from 'node:fs'

const contentView = fs.readFileSync('Stemist.swiftpm/ContentView.swift', 'utf8')
const webModule = fs.readFileSync('Stemist.swiftpm/WebModuleView.swift', 'utf8')
const packageSwift = fs.readFileSync('Stemist.swiftpm/Package.swift', 'utf8')
const codemagic = fs.readFileSync('codemagic.yaml', 'utf8')
const infoPlistPath = 'Stemist.swiftpm/Info.plist'
const githubWorkflowPath = '.github/workflows/ios-simulator.yml'

assert.ok(
  fs.existsSync('Stemist.swiftpm/AppRuntimeConfiguration.swift'),
  'test-only account visibility requires an explicit runtime configuration'
)
const runtimeConfiguration = fs.readFileSync('Stemist.swiftpm/AppRuntimeConfiguration.swift', 'utf8')

assert.match(runtimeConfiguration, /stemist-full-feature-test/, 'full-function tests need a dedicated launch argument')
assert.match(runtimeConfiguration, /STEMIST_FULL_FEATURE_TEST/, 'CI tests need a dedicated environment switch')
assert.match(runtimeConfiguration, /showsAccountEntry/, 'runtime configuration must own account-entry visibility')
assert.match(runtimeConfiguration, /static let current\s*=\s*AppRuntimeConfiguration\(\)/, 'normal builds must use a deterministic default configuration')
assert.match(contentView, /configuration\.showsAccountEntry/, 'the Profile account entry must be hidden by default')
assert.match(contentView, /WebRoute\.ieltsAccount/, 'the account route must remain available for explicit full-function tests')
assert.match(contentView, /normalizeSelectedTab/, 'normal mode must recover from a restored hidden Profile tab')
assert.match(
  contentView,
  /selectedTab\s*==\s*\.profile/,
  'normal mode must explicitly guard a restored Profile selection'
)
assert.match(contentView, /onChange\(of:\s*selectedTab/, 'tab selection normalization must also handle state restoration')
assert.match(packageSwift, /\.iOS\("17\.0"\)/, 'the app should support iPadOS 17 and newer')
assert.doesNotMatch(packageSwift, /\.iOS\("18\.6"\)/, 'the deployment target must not require the newest iPadOS')
assert.match(contentView, /init\?\(url:\s*URL\)/, 'typed routes must parse app deep links')
assert.match(contentView, /\.onOpenURL\s*\{/, 'the root view must accept app deep links')
assert.match(contentView, /queryItems/, 'deep links must support route query parameters')
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
assert.match(infoPlist, /CFBundleURLTypes/, 'Info.plist must declare URL types')
assert.match(infoPlist, /CFBundleURLSchemes/, 'Info.plist must declare URL schemes')
assert.match(infoPlist, /<string>stemist<\/string>/, 'Info.plist must register the stemist scheme')
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
assert.match(webModule, /websiteDataStore\s*=\s*\.default\(\)/, 'SSO cookies must persist across app launches')
assert.match(webModule, /WKUIDelegate/, 'WebKit UI delegate is required for upload and media flows')
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
assert.match(codemagic, /PlistBuddy/, 'CI must verify privacy metadata in the built app')
assert.ok(fs.existsSync(githubWorkflowPath), 'a macOS CI build is required when Windows cannot compile Swift')
const githubWorkflow = fs.readFileSync(githubWorkflowPath, 'utf8')
assert.match(githubWorkflow, /runs-on:\s*macos-14|runs-on:\s*macos-latest/, 'macOS CI must use an Apple runner')
assert.match(githubWorkflow, /xcodebuild[\s\S]*iphonesimulator/, 'macOS CI must compile the iOS Simulator product')
assert.match(githubWorkflow, /PlistBuddy/, 'macOS CI must verify generated app metadata')

console.log('iOS navigation contract passed.')
