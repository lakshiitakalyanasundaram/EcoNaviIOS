-- EcoNavi: Monthly carbon budget badges
-- Create after trip_emissions exists.

CREATE TABLE IF NOT EXISTS public.user_badges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    badge_name TEXT NOT NULL,
    month INT NOT NULL,
    year INT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(user_id, month, year)
);

CREATE INDEX IF NOT EXISTS idx_user_badges_user_id ON public.user_badges(user_id);
CREATE INDEX IF NOT EXISTS idx_user_badges_year_month ON public.user_badges(user_id, year, month);

ALTER TABLE public.user_badges ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_badges_select_own" ON public.user_badges
    FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "user_badges_insert_own" ON public.user_badges
    FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "user_badges_update_own" ON public.user_badges
    FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "user_badges_delete_own" ON public.user_badges
    FOR DELETE USING (auth.uid() = user_id);

