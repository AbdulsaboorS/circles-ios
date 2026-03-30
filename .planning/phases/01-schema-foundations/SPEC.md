# Phase 1 — Schema + Model Foundations

**Goal:** All DB migrations + Swift model updates. No UI changes. Sets the ground truth every other phase builds on.

---

## SQL Migrations (run in Supabase Dashboard → SQL Editor)

### 1. Modify `habits`
```sql
ALTER TABLE habits ADD COLUMN IF NOT EXISTS is_accountable BOOLEAN DEFAULT false;
ALTER TABLE habits ADD COLUMN IF NOT EXISTS circle_id UUID REFERENCES circles(id) ON DELETE SET NULL;
```

### 2. Modify `circles`
```sql
ALTER TABLE circles ADD COLUMN IF NOT EXISTS gender_setting TEXT DEFAULT 'mixed' CHECK (gender_setting IN ('brothers', 'sisters', 'mixed'));
ALTER TABLE circles ADD COLUMN IF NOT EXISTS group_streak_days INT DEFAULT 0;
ALTER TABLE circles ADD COLUMN IF NOT EXISTS core_habits JSONB DEFAULT '[]'::jsonb;
```

### 3. Modify `profiles`
```sql
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS avatar_url TEXT;
```

### 4. New: `comments`
```sql
CREATE TABLE IF NOT EXISTS comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL,
  post_type TEXT NOT NULL CHECK (post_type IN ('moment', 'habit_checkin', 'streak_milestone')),
  circle_id UUID NOT NULL REFERENCES circles(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  text TEXT NOT NULL CHECK (char_length(text) <= 500),
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Circle members can read comments"
ON comments FOR SELECT TO authenticated
USING (circle_id IN (SELECT auth_user_circle_ids()));

CREATE POLICY "Circle members can insert comments"
ON comments FOR INSERT TO authenticated
WITH CHECK (
  user_id = auth.uid()
  AND circle_id IN (SELECT auth_user_circle_ids())
);

CREATE POLICY "Users can delete own comments"
ON comments FOR DELETE TO authenticated
USING (user_id = auth.uid());
```

### 5. New: `habit_plans`

**Existing project out of sync?** Use the idempotent script `habit_plans_align_app.sql` in this folder (adds missing columns + RLS policy) if the app errors on `milestones` / schema cache.

```sql
CREATE TABLE IF NOT EXISTS habit_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  habit_id UUID NOT NULL REFERENCES habits(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  milestones JSONB DEFAULT '[]'::jsonb,
  week_number INT DEFAULT 1,
  refinement_count INT DEFAULT 0,
  refinement_week INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(habit_id, user_id)
);

ALTER TABLE habit_plans ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own habit plans"
ON habit_plans FOR ALL TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());
```

### 6. New: `daily_moments`
```sql
CREATE TABLE IF NOT EXISTS daily_moments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  prayer_name TEXT NOT NULL CHECK (prayer_name IN ('fajr', 'dhuhr', 'asr', 'maghrib', 'isha')),
  moment_date DATE NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Publicly readable (needed to determine if window is active)
ALTER TABLE daily_moments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can read daily moments"
ON daily_moments FOR SELECT TO authenticated
USING (true);
```

---

## Swift Model Updates

### `Circles/Models/Circle.swift`
Add: `genderSetting: String?`, `groupStreakDays: Int?`, `coreHabits: [String]?`

### `Circles/Models/Habit.swift`
Add: `isAccountable: Bool`, `circleId: UUID?`

### `Circles/Models/Profile.swift` (new file)
```swift
struct Profile: Codable, Identifiable, Sendable {
    let id: UUID
    var preferredName: String?
    var gender: String?
    var avatarUrl: String?
    // ... existing fields
}
```

### `Circles/Models/Comment.swift` (new file)
```swift
struct Comment: Codable, Identifiable, Sendable {
    let id: UUID
    let postId: UUID
    let postType: String
    let circleId: UUID
    let userId: UUID
    var text: String
    let createdAt: Date
}
```

### `Circles/Models/HabitPlan.swift` (new file)
```swift
struct HabitMilestone: Codable, Sendable {
    let day: Int
    let title: String
    let description: String
}

struct HabitPlan: Codable, Identifiable, Sendable {
    let id: UUID
    let habitId: UUID
    let userId: UUID
    var milestones: [HabitMilestone]
    var weekNumber: Int
    var refinementCount: Int
    var refinementWeek: Int
    let createdAt: Date
    var updatedAt: Date
}
```

### `Circles/Models/DailyMoment.swift` (new file)
```swift
struct DailyMoment: Codable, Identifiable, Sendable {
    let id: UUID
    let prayerName: String  // "fajr" | "dhuhr" | "asr" | "maghrib" | "isha"
    let momentDate: String  // DATE as String per project convention
    let createdAt: Date
}
```

---

## Success Criteria
- All SQL migrations run without error
- All Swift models compile with zero errors
- No existing functionality broken (all existing fields still decode correctly — new fields are optional or have defaults)
- Build succeeds
