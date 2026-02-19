-- EcoNavi: Apple Maps-style saved places and collections
-- Run after 001_user_data_tables.sql.

-- =============================================================================
-- 1. COLLECTIONS
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.collections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_collections_user_id ON public.collections(user_id);

ALTER TABLE public.collections ENABLE ROW LEVEL SECURITY;

CREATE POLICY "collections_select_own" ON public.collections
    FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "collections_insert_own" ON public.collections
    FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "collections_update_own" ON public.collections
    FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "collections_delete_own" ON public.collections
    FOR DELETE USING (auth.uid() = user_id);

-- =============================================================================
-- 2. ALTER SAVED_PLACES (add name, address, category, collection_id)
-- =============================================================================
ALTER TABLE public.saved_places ADD COLUMN IF NOT EXISTS name TEXT;
ALTER TABLE public.saved_places ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE public.saved_places ADD COLUMN IF NOT EXISTS category TEXT NOT NULL DEFAULT 'favorites';
ALTER TABLE public.saved_places ADD COLUMN IF NOT EXISTS collection_id UUID REFERENCES public.collections(id) ON DELETE SET NULL;

-- Backfill name from display_name (required before SET NOT NULL)
UPDATE public.saved_places SET name = COALESCE(display_name, 'Saved Place') WHERE name IS NULL;
-- Only set NOT NULL if column exists (avoid errors on re-run)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'saved_places' AND column_name = 'name') THEN
        ALTER TABLE public.saved_places ALTER COLUMN name SET NOT NULL;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_saved_places_category ON public.saved_places(user_id, category);
CREATE INDEX IF NOT EXISTS idx_saved_places_collection_id ON public.saved_places(collection_id);
