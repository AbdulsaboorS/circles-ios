# Phase 14: Meaningful Habits — Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-20
**Phase:** 14-meaningful-habits
**Areas discussed:** Niyyah prompt, Catalog/habit selection, Quiz visual style, Habit suggestion surfacing, Check-off ritual, Streak pattern rendering

---

## Niyyah Prompt

| Option | Description | Selected |
|--------|-------------|----------|
| In scope — optional field | Single text field in creation flow, feeds AI + Habit Detail | ✓ |
| Out of scope | Remove from Phase 14 entirely | |

**User's choice:** Initially uncertain ("I don't know if I want it in scope"). After explanation of Islamic context (niyyah as intention before acts, "Actions are judged by intentions"), user confirmed in scope.
**Notes:** User noted that onboarding personalization + quiz would help with the same anchoring goal, but the niyyah prompt adds a different layer — the personal statement of why, feeding the AI roadmap.

---

## Catalog — Habit Selection

| Option | Description | Selected |
|--------|-------------|----------|
| Fixed 30-item catalog + branching rules | Expand from 10 to 30 habits across 5 categories, simple tag matching | |
| Show personalized 5–6 only (quiz-matched) + custom | No full catalog browsing | ✓ |
| AI-generated suggestions (no catalog) | Gemini generates suggestions from quiz answers, catalog eliminated entirely | ✓ |

**User's choice:** First narrowed to personalized 5–6 only, then proposed replacing catalog entirely with AI suggestions. Confirmed: catalog eliminated.
**Notes:** User insight: "30 items is not good, that is why personalization is important, we narrow down habits based on questions or what we know about the user, max 5-6, and then add a custom field." Then escalated to: "what if our AI finds specific habits for people and personalizes based on what they answered?"

---

## Quiz Gate — Existing Users

| Option | Description | Selected |
|--------|-------------|----------|
| Hard intercept | Quiz required for all users including existing, no fallback | ✓ |
| Soft prompt | Existing users see default habits until they do quiz from Settings | |
| No intercept | Existing users just see top 6 defaults | |

**User's choice:** Hard intercept (Option A).
**Notes:** "A for sure, existing users are just testers."

---

## Quiz Visual Style

| Option | Description | Selected |
|--------|-------------|----------|
| Full-width rows + gold highlight | Matches existing familiarity step — deliberate, sacred feel | ✓ |
| Chip grid (pills) | Lighter, playful, Instagram-style | |
| Card grid (2-col, text only) | Heavier, structured | |

**User's choice:** Full-width rows (confirmed when content was presented and approved).
**Notes:** Used app-onboarding-questionnaire skill framework to draft Screen A and B content. User response: "both look great to be honest!"

---

## Screen A — Islamic Struggles Content

| Option | Description | Selected |
|--------|-------------|----------|
| Confirmed as drafted | All 8 items approved | ✓ |

**User's choice:** Approved as-is.

---

## Screen B — Life Struggles Content

| Option | Description | Selected |
|--------|-------------|----------|
| Confirmed as drafted | All 8 items approved | ✓ |

**User's choice:** Approved as-is.

---

## Habit Suggestion Surfacing

| Option | Description | Selected |
|--------|-------------|----------|
| A — Dedicated confirmation screen | "Your Intentions" screen before creation sheet | |
| B — Drop into redesigned creation sheet | Quiz flows directly into pre-filtered creation sheet | ✓ |
| C — Home banner/nudge | Return to home, user adds at own pace | |

**User's choice:** B — creation sheet pre-filtered.

---

## Check-off Ritual

| Option | Description | Selected |
|--------|-------------|----------|
| Hold-to-complete + animation + "Alhamdulillah" | Full ritual as originally scoped | |
| No check-off mechanic change | Keep tap, remove from scope | |
| Tap unchanged + micro-moment | "الحمد لله" fade-in + haptic, no gesture change | ✓ |

**User's choice:** Keep micro-moment, remove hold mechanic.
**Notes:** User questioned the hold mechanic ("I think there doesn't need to be a check off mechanic rn"). Offered middle ground: keep spiritual resonance via micro-moment without UX risk of changing gesture. User: "keep micro moment."

---

## Streak Visual — Placement

| Option | Description | Selected |
|--------|-------------|----------|
| Behind streak counter only | Contained, subtle | |
| Full-width behind header section | More presence, more alive | ✓ |
| On habit rows | Grows around each completed habit | |

**User's choice:** Full-width header.

---

## Streak Visual — Intensity Mechanism

| Option | Description | Selected |
|--------|-------------|----------|
| Opacity only | Fades in with streak | |
| Tile density | Smaller tiles = more complex | |
| Layered rings + gold gradient + rotation | Multiple overlapping instances, slow drift, gold strokes | ✓ |

**User's choice:** Layered approach confirmed.

---

## Streak Visual — Aesthetic Quality

| Option | Description | Selected |
|--------|-------------|----------|
| Current 8-pointed star tiling | Simple outlines, functional | |
| Elevated — girih-style geometry | Complex polygon tessellations, gold gradient, slow rotation | ✓ |

**User's choice:** "Should we do something more aesthetic than the current one?" — yes, full upgrade.
**Notes:** SuperDesign mockups to be produced before implementation. Referenced Ottoman/Andalusian girih tile aesthetic.

---

## Claude's Discretion

- Exact niyyah prompt step placement in creation flow coordinator
- Gemini prompt wording for habit suggestion generation
- Fallback habit list composition
- Haptic pattern type and intensity
- Canvas path math for girih geometry
- Layer rotation angles and drift speeds

## Deferred Ideas

- Hold-to-complete gesture (removed, may revisit post-MVP)
- Per-user streak pattern seeding
- Quiz v2 AI synthesis
- Pattern-based nudges
- 30-item catalog across 5 categories (eliminated entirely)
