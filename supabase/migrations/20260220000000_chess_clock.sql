-- ============================================================
-- Chess-Clock Timer Feature Migration
-- ============================================================

-- 1a. Alter queue table — add time control selection
ALTER TABLE public.queue
  ADD COLUMN time_control_seconds INT NOT NULL DEFAULT 60
  CHECK (time_control_seconds IN (30, 60, 120));

-- 1b. Alter games table — add timer columns
ALTER TABLE public.games
  ADD COLUMN time_control_seconds INT NOT NULL DEFAULT 60,
  ADD COLUMN x_time_remaining_ms INT NOT NULL DEFAULT 60000,
  ADD COLUMN o_time_remaining_ms INT NOT NULL DEFAULT 60000,
  ADD COLUMN x_deadline TIMESTAMPTZ,
  ADD COLUMN o_deadline TIMESTAMPTZ,
  ADD COLUMN finish_reason TEXT CHECK (finish_reason IN ('moves', 'timeout'));


-- 1c. Replace match_players() — filter by same time_control_seconds
CREATE OR REPLACE FUNCTION public.match_players()
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  p1_id uuid;
  p2_id uuid;
  p1_tc int;
  new_game_id uuid;
BEGIN
  -- Lock the oldest queue entry
  SELECT q.user_id, q.time_control_seconds INTO p1_id, p1_tc
  FROM public.queue q
  ORDER BY q.created_at ASC
  LIMIT 1
  FOR UPDATE SKIP LOCKED;

  IF p1_id IS NULL THEN
    RETURN NULL;
  END IF;

  -- Find second entry with the SAME time control
  SELECT q.user_id INTO p2_id
  FROM public.queue q
  WHERE q.user_id != p1_id
    AND q.time_control_seconds = p1_tc
  ORDER BY q.created_at ASC
  LIMIT 1
  FOR UPDATE SKIP LOCKED;

  IF p2_id IS NULL THEN
    RETURN NULL;
  END IF;

  -- Create game with timer fields
  INSERT INTO public.games (
    player_x, player_o, turn,
    time_control_seconds,
    x_time_remaining_ms, o_time_remaining_ms,
    x_deadline, o_deadline
  ) VALUES (
    p1_id, p2_id, p1_id,
    p1_tc,
    p1_tc * 1000, p1_tc * 1000,
    now() + (p1_tc * interval '1 second'), NULL
  )
  RETURNING id INTO new_game_id;

  -- Remove matched players from queue
  DELETE FROM public.queue WHERE user_id IN (p1_id, p2_id);

  RETURN new_game_id;
END;
$$;


-- 1d. Replace make_move() — with timeout check and timer updates
CREATE OR REPLACE FUNCTION public.make_move(game_id uuid, cell_index int)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  g record;
  caller uuid := auth.uid();
  piece text;
  moves jsonb;
  opponent uuid;
  new_board jsonb;
  new_moves jsonb;
  oldest_cell int;
  win_found boolean := false;
  i int;
  -- Timer variables
  active_deadline timestamptz;
  active_remaining_ms int;
  elapsed_ms int;
  new_remaining_ms int;
  opponent_remaining_ms int;
  -- Win pattern checking
  patterns int[][] := array[
    array[0,1,2], array[3,4,5], array[6,7,8],
    array[0,3,6], array[1,4,7], array[2,5,8],
    array[0,4,8], array[2,4,6]
  ];
BEGIN
  -- Lock the game row
  SELECT * INTO g FROM public.games WHERE id = game_id FOR UPDATE;

  IF g IS NULL THEN
    RAISE EXCEPTION 'Game not found';
  END IF;

  IF g.status != 'playing' THEN
    RAISE EXCEPTION 'Game is already over';
  END IF;

  -- Determine active player's deadline and remaining time
  IF g.turn = g.player_x THEN
    active_deadline := g.x_deadline;
    active_remaining_ms := g.x_time_remaining_ms;
  ELSE
    active_deadline := g.o_deadline;
    active_remaining_ms := g.o_time_remaining_ms;
  END IF;

  -- Check if active player has timed out
  IF active_deadline IS NOT NULL AND now() > active_deadline THEN
    -- Active player loses by timeout
    IF g.turn = g.player_x THEN
      UPDATE public.games
      SET status = 'won',
          winner = g.player_o,
          finish_reason = 'timeout',
          x_time_remaining_ms = 0,
          x_deadline = NULL,
          o_deadline = NULL
      WHERE id = game_id;

      UPDATE public.profiles
      SET wins = wins + 1, score = (wins + 1) * 3 + draws
      WHERE id = g.player_o;

      UPDATE public.profiles
      SET losses = losses + 1
      WHERE id = g.player_x;
    ELSE
      UPDATE public.games
      SET status = 'won',
          winner = g.player_x,
          finish_reason = 'timeout',
          o_time_remaining_ms = 0,
          x_deadline = NULL,
          o_deadline = NULL
      WHERE id = game_id;

      UPDATE public.profiles
      SET wins = wins + 1, score = (wins + 1) * 3 + draws
      WHERE id = g.player_x;

      UPDATE public.profiles
      SET losses = losses + 1
      WHERE id = g.player_o;
    END IF;

    RAISE EXCEPTION 'Time expired';
  END IF;

  IF g.turn != caller THEN
    RAISE EXCEPTION 'Not your turn';
  END IF;

  -- Determine piece and moves array
  IF caller = g.player_x THEN
    piece := 'X';
    moves := g.x_moves;
    opponent := g.player_o;
    opponent_remaining_ms := g.o_time_remaining_ms;
  ELSIF caller = g.player_o THEN
    piece := 'O';
    moves := g.o_moves;
    opponent := g.player_x;
    opponent_remaining_ms := g.x_time_remaining_ms;
  ELSE
    RAISE EXCEPTION 'You are not a player in this game';
  END IF;

  -- Compute elapsed time and deduct from mover's budget
  IF active_deadline IS NOT NULL THEN
    -- elapsed = deadline - remaining was the turn start; elapsed = now - turn_start
    elapsed_ms := EXTRACT(EPOCH FROM (now() - (active_deadline - (active_remaining_ms * interval '1 millisecond')))) * 1000;
    new_remaining_ms := GREATEST(active_remaining_ms - elapsed_ms, 0);
  ELSE
    new_remaining_ms := active_remaining_ms;
  END IF;

  -- Validate cell
  IF cell_index < 0 OR cell_index > 8 THEN
    RAISE EXCEPTION 'Invalid cell index';
  END IF;

  IF g.board -> cell_index != 'null'::jsonb THEN
    RAISE EXCEPTION 'Cell is occupied';
  END IF;

  new_board := g.board;
  new_moves := moves;

  -- 3-piece limit: remove oldest if at 3
  IF jsonb_array_length(new_moves) >= 3 THEN
    oldest_cell := (new_moves -> 0)::int;
    new_board := jsonb_set(new_board, array[oldest_cell::text], 'null'::jsonb);
    new_moves := new_moves - 0;  -- remove first element
  END IF;

  -- Place the piece
  new_board := jsonb_set(new_board, array[cell_index::text], to_jsonb(piece));
  new_moves := new_moves || to_jsonb(cell_index);

  -- Check for win
  FOR i IN 1..8 LOOP
    IF (new_board -> (patterns[i][1])::text) = to_jsonb(piece)
       AND (new_board -> (patterns[i][2])::text) = to_jsonb(piece)
       AND (new_board -> (patterns[i][3])::text) = to_jsonb(piece)
    THEN
      win_found := true;
      EXIT;
    END IF;
  END LOOP;

  -- Update the game with timer fields
  IF caller = g.player_x THEN
    UPDATE public.games
    SET board = new_board,
        x_moves = new_moves,
        turn = CASE WHEN win_found THEN g.turn ELSE opponent END,
        status = CASE WHEN win_found THEN 'won' ELSE 'playing' END,
        winner = CASE WHEN win_found THEN caller ELSE NULL END,
        finish_reason = CASE WHEN win_found THEN 'moves' ELSE NULL END,
        x_time_remaining_ms = new_remaining_ms,
        x_deadline = CASE WHEN win_found THEN NULL ELSE NULL END,
        o_deadline = CASE WHEN win_found THEN NULL
                     ELSE now() + (opponent_remaining_ms * interval '1 millisecond') END
    WHERE id = game_id;
  ELSE
    UPDATE public.games
    SET board = new_board,
        o_moves = new_moves,
        turn = CASE WHEN win_found THEN g.turn ELSE opponent END,
        status = CASE WHEN win_found THEN 'won' ELSE 'playing' END,
        winner = CASE WHEN win_found THEN caller ELSE NULL END,
        finish_reason = CASE WHEN win_found THEN 'moves' ELSE NULL END,
        o_time_remaining_ms = new_remaining_ms,
        o_deadline = CASE WHEN win_found THEN NULL ELSE NULL END,
        x_deadline = CASE WHEN win_found THEN NULL
                     ELSE now() + (opponent_remaining_ms * interval '1 millisecond') END
    WHERE id = game_id;
  END IF;

  -- Update scores if game ended
  IF win_found THEN
    UPDATE public.profiles
    SET wins = wins + 1, score = (wins + 1) * 3 + draws
    WHERE id = caller;

    UPDATE public.profiles
    SET losses = losses + 1
    WHERE id = opponent;
  END IF;
END;
$$;


-- 1e. New expire_game() RPC
CREATE OR REPLACE FUNCTION public.expire_game(p_game_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  g record;
  caller uuid := auth.uid();
  active_deadline timestamptz;
  timed_out_player uuid;
  winning_player uuid;
BEGIN
  -- Lock the game row
  SELECT * INTO g FROM public.games WHERE id = p_game_id FOR UPDATE;

  IF g IS NULL THEN
    RAISE EXCEPTION 'Game not found';
  END IF;

  -- Must still be playing
  IF g.status != 'playing' THEN
    RETURN; -- no-op, game already over
  END IF;

  -- Caller must be a participant
  IF caller != g.player_x AND caller != g.player_o THEN
    RAISE EXCEPTION 'You are not a player in this game';
  END IF;

  -- Get active player's deadline
  IF g.turn = g.player_x THEN
    active_deadline := g.x_deadline;
    timed_out_player := g.player_x;
    winning_player := g.player_o;
  ELSE
    active_deadline := g.o_deadline;
    timed_out_player := g.player_o;
    winning_player := g.player_x;
  END IF;

  -- Deadline must have actually passed
  IF active_deadline IS NULL OR now() <= active_deadline THEN
    RETURN; -- no-op, clock hasn't expired
  END IF;

  -- End the game as timeout
  UPDATE public.games
  SET status = 'won',
      winner = winning_player,
      finish_reason = 'timeout',
      x_deadline = NULL,
      o_deadline = NULL,
      x_time_remaining_ms = CASE WHEN timed_out_player = g.player_x THEN 0 ELSE g.x_time_remaining_ms END,
      o_time_remaining_ms = CASE WHEN timed_out_player = g.player_o THEN 0 ELSE g.o_time_remaining_ms END
  WHERE id = p_game_id;

  -- Update profiles
  UPDATE public.profiles
  SET wins = wins + 1, score = (wins + 1) * 3 + draws
  WHERE id = winning_player;

  UPDATE public.profiles
  SET losses = losses + 1
  WHERE id = timed_out_player;
END;
$$;
