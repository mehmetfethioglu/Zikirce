-- Kilerce Cloudflare D1 Schema: 23,933 Recipes + Entitlements + RevenueCat + AdMob SSV
-- Note: Executed remotely via `wrangler d1 execute` (no explicit BEGIN/COMMIT transactions).

CREATE TABLE IF NOT EXISTS recipes (
    id TEXT PRIMARY KEY,
    source TEXT NOT NULL,
    title TEXT NOT NULL,
    subtitle TEXT NOT NULL,
    emoji TEXT NOT NULL,
    category TEXT NOT NULL,
    kilerce_category TEXT NOT NULL,
    region_id TEXT NOT NULL,
    prep_minutes INTEGER NOT NULL,
    cook_minutes INTEGER NOT NULL,
    total_minutes INTEGER NOT NULL,
    servings_count INTEGER NOT NULL,
    servings_unit TEXT NOT NULL,
    servings_label TEXT NOT NULL,
    difficulty TEXT NOT NULL,
    cooking_method TEXT NOT NULL,
    contains_gluten INTEGER NOT NULL,
    contains_lactose INTEGER NOT NULL,
    is_vegan INTEGER NOT NULL,
    is_vegetarian INTEGER NOT NULL,
    has_margarine INTEGER NOT NULL,
    is_refined_sugar_free INTEGER NOT NULL,
    is_healthy_clean INTEGER NOT NULL,
    base_health_score INTEGER NOT NULL,
    quality_score INTEGER NOT NULL,
    clean_label_badges_json TEXT NOT NULL,
    diet_tags_json TEXT NOT NULL,
    meal_slots_json TEXT NOT NULL,
    required_tags_json TEXT NOT NULL,
    optional_tags_json TEXT NOT NULL,
    ingredients_json TEXT NOT NULL,
    steps_json TEXT NOT NULL,
    image_rel_path TEXT NOT NULL,
    search_fold TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS recipe_ingredients (
    id INTEGER PRIMARY KEY,
    recipe_id TEXT NOT NULL,
    seq INTEGER NOT NULL,
    display TEXT NOT NULL,
    name TEXT NOT NULL,
    amount REAL,
    amount_max REAL,
    unit TEXT NOT NULL,
    note TEXT NOT NULL,
    tag TEXT NOT NULL,
    is_optional INTEGER NOT NULL,
    is_pantry_staple INTEGER NOT NULL
);

CREATE VIRTUAL TABLE IF NOT EXISTS recipes_fts USING fts5(
    recipe_id UNINDEXED,
    title,
    ingredients_text,
    search_fold,
    tokenize='unicode61'
);

CREATE TABLE IF NOT EXISTS user_entitlements (
    app_user_id TEXT PRIMARY KEY,
    tier TEXT NOT NULL DEFAULT 'free',
    source TEXT NOT NULL DEFAULT 'none',
    pro_until_ms INTEGER NOT NULL DEFAULT 0,
    is_lifetime INTEGER NOT NULL DEFAULT 0,
    ad_progress_count INTEGER NOT NULL DEFAULT 0,
    ad_window_reset_ms INTEGER NOT NULL DEFAULT 0,
    last_ad_reward_ms INTEGER NOT NULL DEFAULT 0,
    daily_detail_date TEXT NOT NULL DEFAULT '',
    daily_detail_used INTEGER NOT NULL DEFAULT 0,
    updated_at_ms INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS admob_ssv_events (
    transaction_id TEXT PRIMARY KEY,
    app_user_id TEXT NOT NULL,
    ad_unit TEXT,
    reward_amount INTEGER NOT NULL DEFAULT 1,
    created_at_ms INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS revenuecat_events (
    event_id TEXT PRIMARY KEY,
    app_user_id TEXT NOT NULL,
    event_type TEXT NOT NULL,
    product_id TEXT,
    expiration_at_ms INTEGER,
    created_at_ms INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_recipes_kilerce_cat ON recipes(kilerce_category);
CREATE INDEX IF NOT EXISTS idx_recipes_category ON recipes(category);
CREATE INDEX IF NOT EXISTS idx_recipes_region ON recipes(region_id);
CREATE INDEX IF NOT EXISTS idx_recipes_quality ON recipes(quality_score DESC);
CREATE INDEX IF NOT EXISTS idx_recipes_clean ON recipes(is_healthy_clean);
CREATE INDEX IF NOT EXISTS idx_ri_recipe_id ON recipe_ingredients(recipe_id);
CREATE INDEX IF NOT EXISTS idx_ri_tag ON recipe_ingredients(tag);
CREATE INDEX IF NOT EXISTS idx_user_entitlements_pro_until ON user_entitlements(pro_until_ms);
