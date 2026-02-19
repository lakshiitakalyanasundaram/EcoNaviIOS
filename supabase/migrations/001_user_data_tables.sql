-- EcoNavi user data tables with RLS
-- Run this in the Supabase SQL Editor (Dashboard → SQL Editor → New query).

-- =============================================================================
-- 1. REWARDS
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.rewards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    name TEXT NOT NULL,
    cost INT NOT NULL,
    description TEXT
);

CREATE INDEX IF NOT EXISTS idx_rewards_user_id ON public.rewards(user_id);

ALTER TABLE public.rewards ENABLE ROW LEVEL SECURITY;

CREATE POLICY "rewards_select_own" ON public.rewards
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "rewards_insert_own" ON public.rewards
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "rewards_update_own" ON public.rewards
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "rewards_delete_own" ON public.rewards
    FOR DELETE USING (auth.uid() = user_id);

-- =============================================================================
-- 2. OFFLINE_MAPS
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.offline_maps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    name TEXT NOT NULL,
    downloaded_mb DOUBLE PRECISION NOT NULL DEFAULT 0,
    total_mb DOUBLE PRECISION NOT NULL,
    last_updated TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_offline_maps_user_id ON public.offline_maps(user_id);

ALTER TABLE public.offline_maps ENABLE ROW LEVEL SECURITY;

CREATE POLICY "offline_maps_select_own" ON public.offline_maps
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "offline_maps_insert_own" ON public.offline_maps
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "offline_maps_update_own" ON public.offline_maps
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "offline_maps_delete_own" ON public.offline_maps
    FOR DELETE USING (auth.uid() = user_id);

-- =============================================================================
-- 3. REPORTS
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    issue_type TEXT NOT NULL,
    place_title TEXT,
    description TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION
);

CREATE INDEX IF NOT EXISTS idx_reports_user_id ON public.reports(user_id);

ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "reports_select_own" ON public.reports
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "reports_insert_own" ON public.reports
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "reports_update_own" ON public.reports
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "reports_delete_own" ON public.reports
    FOR DELETE USING (auth.uid() = user_id);

-- =============================================================================
-- 4. SAVED_PLACES
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.saved_places (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    display_name TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_saved_places_user_id ON public.saved_places(user_id);

ALTER TABLE public.saved_places ENABLE ROW LEVEL SECURITY;

CREATE POLICY "saved_places_select_own" ON public.saved_places
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "saved_places_insert_own" ON public.saved_places
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "saved_places_update_own" ON public.saved_places
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "saved_places_delete_own" ON public.saved_places
    FOR DELETE USING (auth.uid() = user_id);
