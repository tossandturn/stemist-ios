import assert from 'node:assert/strict'
import fs from 'node:fs'

const contentView = fs.readFileSync('Stemist.swiftpm/ContentView.swift', 'utf8')
const webModule = fs.readFileSync('Stemist.swiftpm/WebModuleView.swift', 'utf8')

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
  'ieltsAccount',
]) {
  assert.match(contentView, new RegExp(`case ${route}\\b`), `missing route ${route}`)
}

assert.match(webModule, /final class WebViewStore/, 'WebView navigation must be instance scoped')
assert.match(webModule, /processPool\s*=/, 'all product pages must share a WKProcessPool for SSO')
assert.match(webModule, /hasSuffix\("\.ieltsist\.com"\)/, 'product subdomains must stay in the app')
assert.match(webModule, /navigationAction\.targetFrame\s*==\s*nil/, 'target blank links need an in-app policy')
assert.match(webModule, /currentURL/, 'Safari fallback must preserve the current page')
assert.doesNotMatch(webModule, /stemistWebGoBack|stemistWebGoForward/, 'global navigation notifications must be removed')

console.log('iOS navigation contract passed.')
