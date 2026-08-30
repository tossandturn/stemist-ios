# Stemist iPad Acceptance Matrix

This is the release gate for an internal QA build. It complements the automated Simulator checks and must be completed on an iPad running iPadOS 17 or later with a disposable test account and test files only.

## Build Boundary

| Build | Required bundle setting | Expected account visibility |
| --- | --- | --- |
| Student | `STEMIST_FULL_FEATURE_TEST=NO` | No Profile tab or web account entry is presented by the shell. Server authentication and authorization remain unchanged. |
| Internal QA | `STEMIST_FULL_FEATURE_TEST=YES` | Profile, account entry, login, registration, recovery, and SSO remain visible for test coverage. |

The QA setting is an internal build configuration, not a student-facing control. Never enable it in a production student artifact.

## Native Shell

| Journey | Pass condition |
| --- | --- |
| Cold launch and relaunch | The expected tab set renders without a blank screen or crash in portrait and landscape. |
| Normal student build | Today, IELTS, STEM, and Notebook are present. Profile is absent. `stemist://open/ielts-account` does not reveal the account route after the system confirmation. |
| Internal QA build | Profile is present. Tapping Profile then Open account reaches IELTSist account flow after the iOS custom-scheme confirmation. |
| Cross-product navigation | IELTSist, STEM, and AI Coach remain in the shared WebKit session. Back, forward, reload, close, and external-link fallback behave predictably. |
| Recovery | Airplane mode, a server error, a web-content-process termination, and an interrupted load each expose a recoverable state. |

## Account And SSO

| Journey | Pass condition |
| --- | --- |
| Registration and sign-in | Valid, invalid, duplicate, and password-reset paths show the expected server response. No native bypass is introduced. |
| SSO | Apple, Google, and Microsoft redirects return to the product WebView session when enabled by the backend. |
| Session continuity | Sign in on IELTSist, open STEM, then return to IELTSist. The same authorized test account remains active. |
| Sign out | Logout clears the product session as designed and protected pages return to their unauthenticated state. |

## IELTS Journeys

| Journey | Pass condition |
| --- | --- |
| Listening and Reading | Start, pause, answer, submit, review, and resume work after an app background/foreground cycle. |
| Writing | Type, paste, upload supported test files, cancel picker, submit, and receive the server-side AI marking or an honest recoverable failure state. |
| Speaking | Test microphone allow and deny paths, start and stop recording, interruption recovery, and server feedback. |
| Vocabulary and AI Coach | Open vocabulary from an allowed STEM context, return to the matching route, send a prompt, and verify loading, response, error, and retry states. |

## STEM And Pencil Journeys

| Journey | Pass condition |
| --- | --- |
| Curriculum separation | IG, AS, and A2 routes remain separate. Topic practice, past papers, and notebook retain route and stage context. |
| Paper content | A question with diagrams or source imagery renders completely before a student starts work. |
| Notebook and handwriting | Apple Pencil ink is continuous across multiple strokes. Finger scroll remains available, and Pencil input is not consumed by the parent scroll view. |
| Submission and marking | Upload or capture a disposable handwritten response, submit it, verify pending and result states, and distinguish student self-score, AI provisional score, teacher score, and official mark-scheme outcome where applicable. |
| STEM Coach | Open Coach from Today and a paper context. Verify contextual prompt, streaming or loading state, failure state, retry, and no cross-account history leakage. |

## Privacy, Accessibility, And Evidence

| Journey | Pass condition |
| --- | --- |
| Permissions | Camera, microphone, and photo library display a clear system purpose string. Allow, deny, and later Settings changes are all recoverable. |
| Accessibility | Dynamic Type, VoiceOver focus order, contrast, keyboard focus, and portrait/landscape layouts remain usable. |
| Evidence | Record build number, device and iPadOS version, route, test-data identifier, result, screenshot or screen recording, and any server request ID. Do not attach credentials, tokens, student work, or personal information. |

## Release Rule

An internal QA build may move to TestFlight only after every applicable row passes. A student build may move to production only after the normal-mode account boundary and the authenticated QA journeys both pass on a real iPad.
