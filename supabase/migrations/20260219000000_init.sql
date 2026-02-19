-- ============================================================
-- LogicXO — Full Database Schema
-- ============================================================

-- 1. PROFILES TABLE
-- Auto-created for each new auth user via trigger
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Player',
  wins int not null default 0,
  losses int not null default 0,
  draws int not null default 0,
  score int not null default 0,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Profiles are viewable by everyone"
  on public.profiles for select
  using (true);

create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = id);

-- Trigger: auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'display_name', 'Player')
  );
  return new;
end;
$$;

create or replace trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- 2. QUEUE TABLE
-- Matchmaking queue; one row per searching user
create table if not exists public.queue (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(user_id)
);

alter table public.queue enable row level security;

create policy "Users can insert own queue entry"
  on public.queue for insert
  with check (auth.uid() = user_id);

create policy "Users can view own queue entry"
  on public.queue for select
  using (auth.uid() = user_id);

create policy "Users can delete own queue entry"
  on public.queue for delete
  using (auth.uid() = user_id);


-- 3. GAMES TABLE
-- Stores all game state; only modified by RPCs
create table if not exists public.games (
  id uuid primary key default gen_random_uuid(),
  player_x uuid not null references auth.users(id),
  player_o uuid not null references auth.users(id),
  turn uuid not null references auth.users(id),
  board jsonb not null default '[null,null,null,null,null,null,null,null,null]'::jsonb,
  x_moves jsonb not null default '[]'::jsonb,
  o_moves jsonb not null default '[]'::jsonb,
  status text not null default 'playing' check (status in ('playing','won','draw')),
  winner uuid references auth.users(id),
  created_at timestamptz not null default now()
);

alter table public.games enable row level security;

create policy "Players can view their own games"
  on public.games for select
  using (auth.uid() = player_x or auth.uid() = player_o);

-- Enable realtime for games table
alter publication supabase_realtime add table public.games;
alter publication supabase_realtime add table public.queue;


-- 4. MATCH_PLAYERS RPC
-- Pairs the two oldest queue entries into a new game.
-- Uses FOR UPDATE SKIP LOCKED for concurrency safety.
create or replace function public.match_players()
returns uuid
language plpgsql
security definer set search_path = ''
as $$
declare
  p1_id uuid;
  p2_id uuid;
  new_game_id uuid;
begin
  -- Lock exactly two oldest queue entries
  select q.user_id into p1_id
  from public.queue q
  order by q.created_at asc
  limit 1
  for update skip locked;

  if p1_id is null then
    return null;
  end if;

  select q.user_id into p2_id
  from public.queue q
  where q.user_id != p1_id
  order by q.created_at asc
  limit 1
  for update skip locked;

  if p2_id is null then
    return null;
  end if;

  -- Create game (random X/O assignment: p1 = X, p2 = O)
  insert into public.games (player_x, player_o, turn)
  values (p1_id, p2_id, p1_id)
  returning id into new_game_id;

  -- Remove matched players from queue
  delete from public.queue where user_id in (p1_id, p2_id);

  return new_game_id;
end;
$$;


-- 5. MAKE_MOVE RPC
-- Server-authoritative move logic: validates turn, cell, 3-piece limit,
-- win detection, and score updates.
create or replace function public.make_move(game_id uuid, cell_index int)
returns void
language plpgsql
security definer set search_path = ''
as $$
declare
  g record;
  caller uuid := auth.uid();
  piece text;
  moves jsonb;
  opponent uuid;
  new_board jsonb;
  new_moves jsonb;
  oldest_cell int;
  win_found boolean := false;
  board_full boolean;
  i int;
  -- Win pattern checking
  patterns int[][] := array[
    array[0,1,2], array[3,4,5], array[6,7,8],
    array[0,3,6], array[1,4,7], array[2,5,8],
    array[0,4,8], array[2,4,6]
  ];
begin
  -- Lock the game row
  select * into g from public.games where id = game_id for update;

  if g is null then
    raise exception 'Game not found';
  end if;

  if g.status != 'playing' then
    raise exception 'Game is already over';
  end if;

  if g.turn != caller then
    raise exception 'Not your turn';
  end if;

  -- Determine piece and moves array
  if caller = g.player_x then
    piece := 'X';
    moves := g.x_moves;
    opponent := g.player_o;
  elsif caller = g.player_o then
    piece := 'O';
    moves := g.o_moves;
    opponent := g.player_x;
  else
    raise exception 'You are not a player in this game';
  end if;

  -- Validate cell
  if cell_index < 0 or cell_index > 8 then
    raise exception 'Invalid cell index';
  end if;

  if g.board -> cell_index != 'null'::jsonb then
    raise exception 'Cell is occupied';
  end if;

  new_board := g.board;
  new_moves := moves;

  -- 3-piece limit: remove oldest if at 3
  if jsonb_array_length(new_moves) >= 3 then
    oldest_cell := (new_moves -> 0)::int;
    new_board := jsonb_set(new_board, array[oldest_cell::text], 'null'::jsonb);
    new_moves := new_moves - 0;  -- remove first element
  end if;

  -- Place the piece
  new_board := jsonb_set(new_board, array[cell_index::text], to_jsonb(piece));
  new_moves := new_moves || to_jsonb(cell_index);

  -- Check for win
  for i in 1..8 loop
    if (new_board -> (patterns[i][1])::text) = to_jsonb(piece)
       and (new_board -> (patterns[i][2])::text) = to_jsonb(piece)
       and (new_board -> (patterns[i][3])::text) = to_jsonb(piece)
    then
      win_found := true;
      exit;
    end if;
  end loop;

  -- Update the game
  if caller = g.player_x then
    update public.games
    set board = new_board,
        x_moves = new_moves,
        turn = case when win_found then g.turn else opponent end,
        status = case when win_found then 'won' else 'playing' end,
        winner = case when win_found then caller else null end
    where id = game_id;
  else
    update public.games
    set board = new_board,
        o_moves = new_moves,
        turn = case when win_found then g.turn else opponent end,
        status = case when win_found then 'won' else 'playing' end,
        winner = case when win_found then caller else null end
    where id = game_id;
  end if;

  -- Update scores if game ended
  if win_found then
    update public.profiles
    set wins = wins + 1, score = (wins + 1) * 3 + draws
    where id = caller;

    update public.profiles
    set losses = losses + 1
    where id = opponent;
  end if;
end;
$$;
