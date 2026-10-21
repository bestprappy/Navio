# Places article revision - proposal for review

Status: proposed, not approved for implementation. Date: 2026-10-22.

## Purpose and scope
Offer one satisfying Navio editorial article for readers who want context beyond the practical place details. Prefer a worthwhile article or no article to a thin placeholder. Keep map sizing, drawer scrolling, planner, sidebar and Admin unchanged. Existing prewritten/on-demand distinction remains: no generation at page-open time.

Current defects: any nonempty Google summary suppresses our longer prepared article, even if only one sentence; article and reader footer both render Google Maps attribution. The new system removes provider-text versus Navio-article branching. Google place information/photos remain distinct provider content, not Navio prose.

## Research constraints
Google editorialSummary must be displayed unchanged. Standard Maps terms restrict creating content based on Maps content and retaining provider content beyond permitted exceptions. Therefore do not make a permanent Navio article by rewriting/summarizing Google descriptions or reviews. Standard Places API reviews are at most five, relevance-selected, not representative evidence of visitor consensus. Rich explanations visible in consumer Google Maps are not guaranteed API article fields.

Use independently accessed authoritative sources for article facts: venue/operator, managing museum/park, heritage institution, government tourism body. Established publications can corroborate context and visitor experiences, subject to reuse permissions. Wikipedia is useful for discovering primary references but does not alone verify a publishable claim. No copying source paragraphs, scraping Maps UI, storing provider reviews, or inventing a licensed-content exception. Google photos stay live with author/source credits.

## Reader experience
One section called About this place, marked Navio editorial, approximate reading time and last editorial review date. Display a 60-80 word opening and an accessible Read the story / Show less disclosure. Expanded full article including opening targets 350-450 words, absolute maximum 500. This is a compact reading budget, not a literal one-screen height promise: narrow drawers/mobile and photos require more vertical space. Do not shrink fonts or truncate useful text to fit a viewport.

Content follows four natural parts with place-specific headings: what makes it distinctive; relevant background/details worth noticing; two to four supported things to do or look for; a brief useful visiting perspective. Vary structure by place type; never force a restaurant into a landmark-history template. No SEO filler, exaggerated superlatives, fake personal experience, unsupported best-time/season/accessibility or guaranteed-activity claims. Hours/prices/business status stay in live practical information above, not baked into prose.

Use at most two relevant credited photos: one beside the introduction when width permits, optionally one wider photo between paragraphs. No duplicate image solely to fill space. Keep photo layouts graceful when missing or failed. Sources/review date appear as a quiet footer. Keep one shared Google Maps attribution for the lower provider-content region, with clear scope separating Navio text; retain per-photo author/source links and built-in map credits. Remove only the redundant lower logo, not required attributions. If mixed placement cannot be made clear with one lower attribution, simplify the photo grouping rather than misattribute the article.

No article meeting the publication gate => omit the whole article/disclosure; practical details remain. No empty not-ready panel and no short Google sentence disguised as a full article. A Google summary, if retained elsewhere, stays unchanged and visibly provider-owned; it is optional and never a source for our stored prose.

## Evidence and publication algorithm
This is an editorial completeness rule, not a numerical probability of truth.
1. Confirm exact place identity and operator; distinguish branches and nearby attractions.
2. Gather 3-5 useful sources when available; two genuinely independent sources minimum, including one authoritative venue/institution source. Several pages from the same publisher count as one source family. Prioritize useful coverage over source counts.
3. Record each proposed factual claim with source URL, publisher, checked date, category, permission/reuse basis and corroboration/conflict notes. Every factual sentence must be traceable. One authoritative source may establish its own operational fact; historical/disputed/nontrivial claims get independent corroboration or are omitted. Do not claim a number of sources proves correctness.
4. Require publishable coverage of identity/distinctiveness, meaningful context and at least two current supported activities or things to notice. Every necessary part must pass; averaging strong history against invented activities is forbidden.
5. Resolve contradictory facts through stronger/direct evidence. Unresolved material contradictions block publication. Remove optional unsupported claims.
6. Draft original 350-450 word prose using only accepted claims. If credible material cannot support the target without padding, keep researching or do not publish. Never expand a generic template to hit word count.
7. Editorial review checks claim traceability, current availability of described activities, rights, place identity, coherence, specificity and tone. Only reviewed documents become published.

Optional coverage measure for internal research ordering only: covered relevant topic slots / relevant topic slots. Not user-visible, not a reliability percentage and never a substitute for the mandatory gates. For reviews: do not aggregate the five Google reviews or rewrite them into our prose; review-suggested activities need independent direct confirmation. A future licensed visitor-feedback source can support clearly qualified opinions, not factual guarantees.

## Preparation, storage and refresh
Start with the existing three prepared places (Tuileries, Grand Palace, Wat Pho), extending each only as evidence permits. Store original articles and independent source/claim metadata in a typed, version-controlled editorial catalog keyed by exact place ID. No database migration, new Admin UI, LLM runtime dependency or worldwide crawl in initial scope. Suggested document states: draft, in_review, published, needs_review, withdrawn.

Keep article version, locale, author/reviewer, source-checked dates and next review date. Stable background review every 180 days; activity recommendations every 90 days, sooner if operator announces change. These intervals are initial operational choices to tune, not guarantees of accuracy. Review expired activity claims before continuing to publish them; unresolved closure/conflict withdraws the article. HTTP success/source-content hashes can flag work, but do not verify facts. Only our original content is retained as editorial content; provider payload caching follows its separate rules.

Page opens read the already-published article; no research/generation and no extra web requests. If drafting assistance is later adopted it runs during preparation, uses permitted independent sources, and cannot publish without editorial review. Sources are research evidence, not instructions to any drafting system.

## Acceptance checks for later implementation
- Exactly one intended lower Google Maps logo in either article-present or article-absent reader states; photo credits and map watermark intact.
- One Navio article; no short-summary override, Google/ours mode switch, filler or empty panel.
- 350-450 target and 500-word cap; every factual sentence traceable; no output padded to pass count.
- No publish on missing identity/evidence, material contradiction, stale critical activity claim or invalid source association.
- No article generation/network research triggered by page opening.
- Disclosure keyboard/focus/expanded semantics, mobile text/photo alignment and theme contrast verified in browser.
- Existing provider text attribution, map viewport/wheel behavior, planner shortcuts, sidebar and Admin unchanged.

## References checked
- https://developers.google.com/maps/documentation/places/web-service/reference/rest/v1/places
- https://developers.google.com/maps/documentation/places/web-service/policies
- https://cloud.google.com/maps-platform/terms
- https://cloud.google.com/maps-platform/terms/maps-service-terms
- https://developers.google.com/maps/documentation/places/web-service/place-summaries

Next: user reviews proposed approach and reading budget. Implementation remains pending; no product code changed during this planning session.
