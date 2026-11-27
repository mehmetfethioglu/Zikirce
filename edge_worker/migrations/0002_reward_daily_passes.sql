-- Track daily 3-ad -> 3h Pro pass count per user (max 2 passes/day)
ALTER TABLE user_entitlements ADD COLUMN reward_passes_date TEXT NOT NULL DEFAULT '';
ALTER TABLE user_entitlements ADD COLUMN reward_passes_today INTEGER NOT NULL DEFAULT 0;
