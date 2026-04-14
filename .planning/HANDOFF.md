# Handoff — 2026-04-13 (Session 18 — Aligned Presence / Niyyah)

## Current Build State
**BUILD VERIFIED ✅** — zero errors on `main`.

---

## What Landed This Session

### Wave 5.1 — Aligned Presence (Niyyah + Noor Aura + Spiritual Ledger)

Full implementation of the "Aligned Presence" feature — transforms the social feed from a BeReal clone into a spiritually-grounded experience rooted in Ikhlas (sincerity).

#### 1. Niyyah Capture Overlay (Post-Photo Ritual)
- **`NiyyahCaptureOverlay.swift`** (new) — `.ultraThinMaterial` frosted overlay with Islamic geometric pattern, serif prompt "Align your Niyyah for this act.", multi-line text input, gold capsule "Set Niyyah" button
- Optional: skip via downward swipe or "Skip" chevron button
- Appears automatically after photo capture, before caption/post UI

#### 2. Niyyah Dissolve Animation
- **`NiyyahDissolveView.swift`** (new) — `TimelineView(.animation)` + `Canvas` particle system
- Sequence: shimmer sweep on text → text fades to gold → 40 gold particles drift outward radially → completion callback triggers Noor Aura

#### 3. Noor Aura on Feed Cards
- **`NoorAuraOverlay.swift`** (new) — soft gold inner-glow with breathing animation (opacity 0.35↔0.55, 3s easeInOut)
- Applied conditionally when `hasNiyyah == true` on `MomentFeedCard`
- Visible even on locked/blurred cards (glow exists but content hidden)

#### 4. Islamic Geometric Pattern
- **`IslamicGeometricPattern.swift`** (new) — Canvas-based tiling 8-pointed star pattern at 2.5% opacity
- Used on Niyyah overlay and Spiritual Ledger backgrounds only

#### 5. Spiritual Ledger (Private Archive)
- **`SpiritualLedgerView.swift`** (new) — full-screen paging journal with `.scrollTargetBehavior(.paging)`
- Each page: date (Gregorian), Niyyah text as hero in serif font, small photo thumbnail with NoorAura
- Empty state with moon.stars icon
- Entry point on ProfileView: "Spiritual Ledger" button with count badge (only shows when count > 0)

#### 6. Privacy Protocol
- **`MomentNiyyah.swift`** (new model) — `moment_niyyahs` table with owner-only RLS
- **`NiyyahService.swift`** (new) — save (upsert), fetchAll, fetchCount
- Niyyah text NEVER stored in `circle_moments` — only `has_niyyah: Bool` on that table
- Feed model only sees the boolean to render the aura

#### 7. Data Flow Changes
- `CircleMoment` — added `hasNiyyah: Bool` with backward-compat decoder
- `MomentFeedItem` — added `hasNiyyah: Bool`
- `MomentService.postMomentToAllCircles` — new `niyyahText: String?` param; sets `has_niyyah` on each row, saves niyyah after successful post (graceful failure)
- `MomentService.fetchMomentForDate` — new helper for Ledger photo lookups
- `FeedService.CircleMomentRow` — added `hasNiyyah` with backward-compat decoder
- `MomentPreviewView.onPost` — signature changed from `(String?, Bool)` to `(String?, Bool, String?)`
- Both `CommunityView` and `CircleDetailView` updated to forward niyyahText

#### 8. Corner Radius Upgrade
- 16pt → 32pt on all moment photo containers: `MomentFeedCard`, `MomentPreviewView`, `MomentFullScreenView`

---

## DB Migration Required

**User must run this SQL in Supabase Dashboard → SQL Editor:**

```sql
ALTER TABLE circle_moments ADD COLUMN has_niyyah BOOLEAN NOT NULL DEFAULT FALSE;

CREATE TABLE moment_niyyahs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  niyyah_text TEXT NOT NULL,
  photo_date DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, photo_date)
);

ALTER TABLE moment_niyyahs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "owner_select" ON moment_niyyahs FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "owner_insert" ON moment_niyyahs FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "owner_delete" ON moment_niyyahs FOR DELETE USING (auth.uid() = user_id);

NOTIFY pgrst, 'reload schema';
```

---

## Files Created/Modified

| File | Status |
|------|--------|
| `Circles/Models/MomentNiyyah.swift` | **New** — Codable model for moment_niyyahs |
| `Circles/Models/CircleMoment.swift` | Modified — added hasNiyyah + memberwise init + backward-compat decoder |
| `Circles/Models/FeedItem.swift` | Modified — added hasNiyyah to MomentFeedItem |
| `Circles/Services/NiyyahService.swift` | **New** — owner-only niyyah CRUD |
| `Circles/Services/MomentService.swift` | Modified — niyyahText param, fetchMomentForDate, hasNiyyah threading |
| `Circles/Services/FeedService.swift` | Modified — hasNiyyah in CircleMomentRow + MomentFeedItem construction |
| `Circles/DesignSystem/IslamicGeometricPattern.swift` | **New** — tiling 8-pointed star pattern |
| `Circles/Feed/NoorAuraOverlay.swift` | **New** — gold inner-glow breathing overlay |
| `Circles/Moment/NiyyahDissolveView.swift` | **New** — text → particles → settle animation |
| `Circles/Moment/NiyyahCaptureOverlay.swift` | **New** — post-capture ritual overlay |
| `Circles/Moment/MomentPreviewView.swift` | Modified — niyyah phase flow, onPost signature change |
| `Circles/Community/CommunityView.swift` | Modified — forward niyyahText |
| `Circles/Circles/CircleDetailView.swift` | Modified — forward niyyahText |
| `Circles/Feed/MomentFeedCard.swift` | Modified — NoorAura overlay + 32pt corners |
| `Circles/Feed/FeedViewModel.swift` | Modified — thread hasNiyyah in caption update |
| `Circles/Feed/MomentFullScreenView.swift` | Modified — 32pt corners |
| `Circles/Profile/SpiritualLedgerView.swift` | **New** — private journal archive |
| `Circles/Profile/ProfileView.swift` | Modified — Spiritual Ledger entry point |

---

## What's Next

1. **User must run DB migration** (see SQL above) before testing
2. **User QA** — test the full Niyyah capture flow, dissolve animation, feed aura, Spiritual Ledger
3. **Animation polish** — dissolve particle positions are randomized within a fixed rect; may need tuning after seeing it on device
4. **STATE.md update** after QA
5. **Continue Phase 13** — Waves 4 (Feed Cards), 6 (Profile), 7 (Auth) per STATE.md tracker

## Plan File
Full implementation plan at `.claude/plans/synchronous-petting-dusk.md`

## Simulator UDID
`AAD4DE32-6D0C-4C10-BCF1-1A4612DD9D92` (iPhone 17 Pro, OS 26.3.1)
