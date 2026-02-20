-- Test Matchmaking Flow
BEGIN;

-- 1. Create two test users in auth.users
INSERT INTO auth.users (id, instance_id, role, aud, email) 
VALUES 
  ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'test1@example.com'),
  ('22222222-2222-2222-2222-222222222222', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'test2@example.com')
ON CONFLICT (id) DO NOTHING;

-- Trigger should have created profiles

-- 2. Join Queue
INSERT INTO public.queue (user_id) VALUES ('11111111-1111-1111-1111-111111111111') ON CONFLICT DO NOTHING;
INSERT INTO public.queue (user_id) VALUES ('22222222-2222-2222-2222-222222222222') ON CONFLICT DO NOTHING;

-- 3. Run match_players directly (since we can't easily mock auth.uid() in DDL, let's just see if it runs)
-- But wait, match_players doesn't use auth.uid(), it uses the queue. So we can run it.
SELECT match_players();

-- Let's check the games table
SELECT id, status, player_x_ready, player_o_ready FROM public.games ORDER BY created_at DESC LIMIT 1;

ROLLBACK;
