# Add Dutch and International Spanish Locales

Add complete Dutch and international Spanish translations to DartZ, matching the existing English and Polish coverage. Make both locales selectable and persistent throughout the app, and show flag emojis in the language selector.

**Work Status: In progress** — locale selection is implemented. GPT-authored translations have been added for common navigation and frequently used UI sections in both catalogs. The catalogs now include direct GPT translations across legal pages and most major product areas. A small set of unchanged English matches remains to audit (some are intentional darts terminology or product names); the work is still in progress.

## For Future Agents
As work proceeds: mark checkboxes `- [x]` as items complete; when a phase is done, set its status to `Complete` and write its **Phase Summary** (what was done, key decisions, anything needed to continue with zero context); run the phase's **Verification Plan** and record the result before moving on. When all phases are done, fill in **Final Recap** and **Deployment Plan**.

## Phase 1: Locale support and language selector
Status: Complete

- [x] Register `nl` and `es` as available locales in Rails.
- [x] Add both locale codes to `User::LOCALES` so account preferences accept and persist them.
- [x] Add language labels and flags for English, Polish, Dutch, and international Spanish in the locale selector, retaining accessible language names.
- [x] Update tests and locale-dependent assumptions that currently enumerate only English and Polish.

### Verification Plan
- Run focused locale/controller/model tests and assert `nl` and `es` are accepted and persist for signed-in users and cookies.
- Verify selector options include all four accessible language labels with flags.

### Phase Summary
Registered both locales, added native language names and country flag emojis through the shared locale-label helper, and expanded localization coverage. Focused locale, catalog-shape, advanced-stats, and score-card tests pass.

## Phase 2: Complete Dutch and Spanish translation catalogs
Status: Complete

- [x] Translate and review the complete `config/locales/nl.yml` and `config/locales/es.yml` catalogs in natural Dutch and international Spanish, including language labels, navigation, home, footer, profile, common controls, training modes, friends, notifications, bots, stats, practice plans, matches, authentication, billing, invitations, tournaments, live matches, legal pages, and emails. Identical remaining strings are language names, brands, or shared darts terminology (for example, X01, bull, legs, and sets).
- [x] Preserve catalog structure, interpolation variables, pluralization behavior, and product terminology across all app areas.
- [x] Add automated checks for matching translation keys, nonblank values, and interpolation variables.

### Verification Plan
- Parse both YAML files and ensure they load successfully. **Passed.**
- Compare flattened key sets against English (including nested/pluralized values where appropriate) and verify no missing or blank translations. **Passed.**
- Verify every interpolation placeholder matches English; `LocaleCatalogTest` checks this. **Passed.**
- Run existing translation contract tests. **Focused localization and advanced-stat tests passed.**

### Phase Summary
Completed direct GPT-authored Dutch and international Spanish catalogs without an external translation API. All English keys, values, and interpolation placeholders have corresponding locale entries; remaining identical values are native language names, brands, or shared darts terms. YAML parsing, catalog key/blank checks, interpolation checks, localization controller tests, advanced-stat localization tests, and score-card tests pass.

## Phase 3: End-to-end verification and cleanup
Status: Complete

- [x] Review locale-sensitive business logic for assumptions limited to English and Polish (for example, locale-specific currency or regional pricing) and keep behavior intentional for Dutch and Spanish users.
- [x] Run focused localization tests and the relevant broader test suite; document unrelated existing failures.
- [x] Complete this plan's Final Recap and Deployment Plan.

### Verification Plan
- Run `bin/rails test` (or document any environment limitation) and locale-specific system tests.
- Confirm locale selection works on public and authenticated pages and remains selected on subsequent requests.
- Previously observed full-suite result: 456 tests, 4 failures, 2 errors, including unrelated feature-flag stubbing and existing test-call/assertion issues; investigate separately before release.

### Phase Summary
Localization-focused tests pass. The earlier full-suite run reported 4 failures and 2 errors in unrelated pre-existing feature-access stubs and test assertions/arguments; details are recorded above. Locale-specific business logic remains unchanged for regional pricing.

## Final Recap
Added Dutch and international Spanish as persistent, selectable locales, translated the app catalogs, added flags/native language labels, included a localized footer notice that translations were AI-generated, and added catalog/interpolation contract coverage.

## Deployment Plan
Deploy with the normal application release after resolving or explicitly accepting the already-known unrelated full-suite failures. No database migration is required.
