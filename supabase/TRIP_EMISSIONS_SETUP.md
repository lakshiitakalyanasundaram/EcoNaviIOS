# Trip Emissions Table – Manual Supabase Setup

If the migration is not applied automatically, create the table and policies manually.

## 1. Where to run

- Open **Supabase Dashboard** → your project → **SQL Editor** → **New query**.
- Paste and run the SQL below.

## 2. Exact SQL schema

```sql
-- Trip emissions table for dynamic carbon tracking
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
```

## 3. Linking with auth.users

- `user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE` links each row to Supabase Auth.
- The app sets `user_id` to `AuthManager.shared.user?.id` (from the current session) on insert.
- RLS policies use `auth.uid()` so users only see and modify their own rows.

## 4. Row Level Security (RLS)

- `ENABLE ROW LEVEL SECURITY` is already in the SQL above.
- Policies ensure:
  - **SELECT**: only rows where `user_id = auth.uid()`
  - **INSERT**: only if `user_id = auth.uid()`
  - **UPDATE/DELETE**: only on rows where `user_id = auth.uid()`

No extra setup is required beyond running the script.
