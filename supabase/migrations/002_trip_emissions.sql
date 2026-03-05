-- EcoNavi trip emissions table for dynamic carbon tracking
-- Run in Supabase Dashboard → SQL Editor → New query (or use Supabase CLI migrations).

-- =============================================================================
-- TRIP_EMISSIONS
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.trip_emissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    distance DOUBLE PRECISION NOT NULL,
    time_taken DOUBLE PRECISION NOT NULL,
    carbon_emission DOUBLE PRECISION NOT NULL,
    transport_mode TEXT
);

CREATE INDEX IF NOT EXISTS idx_trip_emissions_user_id ON public.trip_emissions(user_id);
CREATE INDEX IF NOT EXISTS idx_trip_emissions_created_at ON public.trip_emissions(created_at DESC);

ALTER TABLE public.trip_emissions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "trip_emissions_select_own" ON public.trip_emissions
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "trip_emissions_insert_own" ON public.trip_emissions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "trip_emissions_update_own" ON public.trip_emissions
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "trip_emissions_delete_own" ON public.trip_emissions
    FOR DELETE USING (auth.uid() = user_id);
