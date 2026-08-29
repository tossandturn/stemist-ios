import assert from 'node:assert/strict'
import fs from 'node:fs'

const contentView = fs.readFileSync('Stemist.swiftpm/ContentView.swift', 'utf8')
const webModule = fs.readFileSync('Stemist.swiftpm/WebModuleView.swift', 'utf8')
const packageSwift = fs.readFileSync('Stemist.swiftpm/Package.swift', 'utf8')
const codemagic = fs.readFileSync('codemagic.yaml', 'utf8')

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
for (const host of ['ieltsist.com', 'stem.ieltsist.com', 'ai.ieltsist.com']) {
  assert.match(contentView, new RegExp(`https:\\/\\/${host.replaceAll('.', '\\.')}`), `missing product host ${host}`)
}

assert.match(webModule, /final class WebViewStore/, 'WebView navigation must be instance scoped')
assert.match(webModule, /processPool\s*=/, 'all product pages must share a WKProcessPool for SSO')
assert.match(webModule, /hasSuffix\("\.ieltsist\.com"\)/, 'product subdomains must stay in the app')
assert.match(webModule, /navigationAction\.targetFrame\s*==\s*nil/, 'target blank links need an in-app policy')
assert.match(webModule, /currentURL/, 'Safari fallback must preserve the current page')
assert.doesNotMatch(webModule, /stemistWebGoBack|stemistWebGoForward/, 'global navigation notifications must be removed')
assert.match(webModule, /websiteDataStore\s*=\s*\.default\(\)/, 'SSO cookies must persist across app launches')
assert.match(webModule, /WKUIDelegate/, 'WebKit UI delegate is required for upload and media flows')
assert.match(webModule, /runOpenPanelWith/, 'writing and question uploads need a document picker')
assert.match(webModule, /requestMediaCapturePermissionFor/, 'speaking needs an explicit media permission policy')
assert.match(webModule, /WebContentProcessDidTerminate/, 'a crashed web content process must recover')
assert.match(webModule, /UTType\.pdf/, 'writing and source-paper uploads must accept PDF files')
assert.match(webModule, /navigationType\s*==\s*\.other/, 'server auth redirects must stay inside the shared WebView')
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

console.log('iOS navigation contract passed.')
