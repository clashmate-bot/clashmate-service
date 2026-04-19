CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS citext;

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TABLE IF NOT EXISTS guilds (
  guild_id text PRIMARY KEY,
  name text NOT NULL,
  icon_url text,
  bot_kind text NOT NULL DEFAULT 'public' CHECK (bot_kind IN ('public', 'custom')),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS guild_categories (
  category_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  guild_id text NOT NULL REFERENCES guilds (guild_id) ON DELETE CASCADE,
  name text NOT NULL,
  position integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS guild_clans (
  guild_clan_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  guild_id text NOT NULL REFERENCES guilds (guild_id) ON DELETE CASCADE,
  coc_clan_tag text NOT NULL CHECK (coc_clan_tag ~ '^#[A-Z0-9]+$'),
  category_id uuid REFERENCES guild_categories (category_id) ON DELETE SET NULL,
  display_name text,
  position integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (guild_id, coc_clan_tag)
);

CREATE TABLE IF NOT EXISTS guild_settings (
  guild_id text PRIMARY KEY REFERENCES guilds (guild_id) ON DELETE CASCADE,
  timezone text NOT NULL DEFAULT 'UTC',
  locale text NOT NULL DEFAULT 'en',
  default_link_path text NOT NULL DEFAULT '/links',
  settings jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS guild_feature_flags (
  guild_id text NOT NULL REFERENCES guilds (guild_id) ON DELETE CASCADE,
  flag_key text NOT NULL,
  enabled boolean NOT NULL DEFAULT false,
  config jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (guild_id, flag_key)
);

CREATE TABLE IF NOT EXISTS auth_api_clients (
  client_id text PRIMARY KEY,
  client_name text NOT NULL,
  client_type text NOT NULL CHECK (client_type IN ('bot', 'client', 'internal')),
  hashed_secret text NOT NULL,
  scopes text[] NOT NULL DEFAULT ARRAY[]::text[],
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS auth_handoff_tokens (
  handoff_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  jti uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  token_hash text NOT NULL UNIQUE,
  user_id text NOT NULL,
  guild_id text NOT NULL REFERENCES guilds (guild_id) ON DELETE CASCADE,
  allowed_path text NOT NULL CHECK (allowed_path IN ('/clans', '/links', '/rosters')),
  scopes text[] NOT NULL DEFAULT ARRAY[]::text[],
  issued_by text NOT NULL,
  expires_at timestamptz NOT NULL,
  consumed_at timestamptz,
  consumed_by_ip inet,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS auth_sessions (
  session_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  token_hash text NOT NULL UNIQUE,
  user_id text NOT NULL,
  guild_id text REFERENCES guilds (guild_id) ON DELETE CASCADE,
  source text NOT NULL CHECK (source IN ('client', 'bot', 'internal')),
  scopes text[] NOT NULL DEFAULT ARRAY[]::text[],
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz,
  last_seen_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS user_profiles (
  user_id text PRIMARY KEY,
  display_name text,
  timezone text NOT NULL DEFAULT 'UTC',
  locale text NOT NULL DEFAULT 'en',
  profile jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS link_player_links (
  link_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_tag text NOT NULL CHECK (player_tag ~ '^#[A-Z0-9]+$'),
  player_name text NOT NULL,
  user_id text NOT NULL,
  guild_id text REFERENCES guilds (guild_id) ON DELETE SET NULL,
  linked_by_user_id text NOT NULL,
  source text NOT NULL DEFAULT 'bot',
  is_verified boolean NOT NULL DEFAULT false,
  link_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE IF NOT EXISTS link_audit_logs (
  audit_id bigserial PRIMARY KEY,
  link_id uuid REFERENCES link_player_links (link_id) ON DELETE SET NULL,
  player_tag text NOT NULL,
  user_id text NOT NULL,
  guild_id text,
  action text NOT NULL CHECK (
    action IN ('link', 'unlink', 'verify', 'reorder', 'profile-update')
  ),
  actor_user_id text NOT NULL,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS coc_players_cache (
  player_tag text PRIMARY KEY CHECK (player_tag ~ '^#[A-Z0-9]+$'),
  name text NOT NULL,
  clan_tag text CHECK (clan_tag IS NULL OR clan_tag ~ '^#[A-Z0-9]+$'),
  town_hall_level integer,
  exp_level integer,
  trophies integer,
  best_trophies integer,
  war_stars integer,
  donations integer,
  received integer,
  labels jsonb NOT NULL DEFAULT '[]'::jsonb,
  raw_payload jsonb NOT NULL,
  fetched_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  stale_at timestamptz
);

CREATE TABLE IF NOT EXISTS coc_clans_cache (
  clan_tag text PRIMARY KEY CHECK (clan_tag ~ '^#[A-Z0-9]+$'),
  name text NOT NULL,
  badge_url text,
  type text,
  description text,
  location_name text,
  member_count integer,
  war_league text,
  capital_league text,
  war_wins integer,
  war_win_streak integer,
  raw_payload jsonb NOT NULL,
  fetched_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  stale_at timestamptz
);

CREATE TABLE IF NOT EXISTS coc_wars_cache (
  war_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  clan_tag text NOT NULL CHECK (clan_tag ~ '^#[A-Z0-9]+$'),
  opponent_tag text CHECK (opponent_tag IS NULL OR opponent_tag ~ '^#[A-Z0-9]+$'),
  war_state text NOT NULL,
  preparation_start_time timestamptz,
  start_time timestamptz,
  end_time timestamptz,
  raw_payload jsonb NOT NULL,
  fetched_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  UNIQUE (clan_tag, start_time)
);

CREATE TABLE IF NOT EXISTS coc_raid_weekends_cache (
  raid_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  clan_tag text NOT NULL CHECK (clan_tag ~ '^#[A-Z0-9]+$'),
  start_time timestamptz NOT NULL,
  end_time timestamptz NOT NULL,
  raw_payload jsonb NOT NULL,
  fetched_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  UNIQUE (clan_tag, start_time)
);

CREATE TABLE IF NOT EXISTS coc_cwl_groups_cache (
  group_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  clan_tag text NOT NULL CHECK (clan_tag ~ '^#[A-Z0-9]+$'),
  season text NOT NULL,
  raw_payload jsonb NOT NULL,
  fetched_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  UNIQUE (clan_tag, season)
);

CREATE TABLE IF NOT EXISTS history_player_events (
  event_id bigserial PRIMARY KEY,
  player_tag text NOT NULL CHECK (player_tag ~ '^#[A-Z0-9]+$'),
  guild_id text REFERENCES guilds (guild_id) ON DELETE SET NULL,
  event_type text NOT NULL,
  event_time timestamptz NOT NULL,
  season text,
  clan_tag text CHECK (clan_tag IS NULL OR clan_tag ~ '^#[A-Z0-9]+$'),
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS history_player_trophy_snapshots (
  snapshot_id bigserial PRIMARY KEY,
  player_tag text NOT NULL CHECK (player_tag ~ '^#[A-Z0-9]+$'),
  recorded_at timestamptz NOT NULL,
  season text NOT NULL,
  home_trophies integer,
  builder_trophies integer,
  legend_day jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (player_tag, recorded_at)
);

CREATE TABLE IF NOT EXISTS history_donation_snapshots (
  snapshot_id bigserial PRIMARY KEY,
  player_tag text NOT NULL CHECK (player_tag ~ '^#[A-Z0-9]+$'),
  clan_tag text CHECK (clan_tag IS NULL OR clan_tag ~ '^#[A-Z0-9]+$'),
  season text NOT NULL,
  donations integer NOT NULL DEFAULT 0,
  received integer NOT NULL DEFAULT 0,
  recorded_at timestamptz NOT NULL,
  UNIQUE (player_tag, recorded_at)
);

CREATE TABLE IF NOT EXISTS history_war_attacks (
  attack_id bigserial PRIMARY KEY,
  war_key text NOT NULL,
  war_start_time timestamptz NOT NULL,
  clan_tag text NOT NULL CHECK (clan_tag ~ '^#[A-Z0-9]+$'),
  attacker_tag text NOT NULL CHECK (attacker_tag ~ '^#[A-Z0-9]+$'),
  defender_tag text NOT NULL CHECK (defender_tag ~ '^#[A-Z0-9]+$'),
  attack_order integer NOT NULL,
  stars integer NOT NULL,
  destruction numeric(5, 2) NOT NULL,
  map_position integer,
  is_fresh boolean,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (war_key, attacker_tag, attack_order)
);

CREATE TABLE IF NOT EXISTS history_capital_contribution_events (
  event_id bigserial PRIMARY KEY,
  player_tag text NOT NULL CHECK (player_tag ~ '^#[A-Z0-9]+$'),
  clan_tag text NOT NULL CHECK (clan_tag ~ '^#[A-Z0-9]+$'),
  season text NOT NULL,
  amount integer NOT NULL,
  recorded_at timestamptz NOT NULL,
  source text NOT NULL DEFAULT 'poller'
);

CREATE TABLE IF NOT EXISTS history_capital_raid_attacks (
  raid_attack_id bigserial PRIMARY KEY,
  raid_weekend_start timestamptz NOT NULL,
  clan_tag text NOT NULL CHECK (clan_tag ~ '^#[A-Z0-9]+$'),
  player_tag text NOT NULL CHECK (player_tag ~ '^#[A-Z0-9]+$'),
  attacks integer NOT NULL DEFAULT 0,
  capital_resources_looted integer NOT NULL DEFAULT 0,
  medals integer,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (raid_weekend_start, clan_tag, player_tag)
);

CREATE TABLE IF NOT EXISTS history_clan_games_scores (
  score_id bigserial PRIMARY KEY,
  player_tag text NOT NULL CHECK (player_tag ~ '^#[A-Z0-9]+$'),
  clan_tag text CHECK (clan_tag IS NULL OR clan_tag ~ '^#[A-Z0-9]+$'),
  season text NOT NULL,
  points integer NOT NULL,
  recorded_at timestamptz NOT NULL,
  UNIQUE (player_tag, season, recorded_at)
);

CREATE TABLE IF NOT EXISTS analytics_daily_player_summary (
  summary_date date NOT NULL,
  player_tag text NOT NULL CHECK (player_tag ~ '^#[A-Z0-9]+$'),
  clan_tag text CHECK (clan_tag IS NULL OR clan_tag ~ '^#[A-Z0-9]+$'),
  donations integer NOT NULL DEFAULT 0,
  received integer NOT NULL DEFAULT 0,
  attacks integer NOT NULL DEFAULT 0,
  stars integer NOT NULL DEFAULT 0,
  capital_contribution integer NOT NULL DEFAULT 0,
  clan_games_points integer NOT NULL DEFAULT 0,
  trophies integer,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (summary_date, player_tag)
);

CREATE TABLE IF NOT EXISTS analytics_daily_clan_summary (
  summary_date date NOT NULL,
  clan_tag text NOT NULL CHECK (clan_tag ~ '^#[A-Z0-9]+$'),
  member_count integer,
  donations integer NOT NULL DEFAULT 0,
  attacks integer NOT NULL DEFAULT 0,
  stars integer NOT NULL DEFAULT 0,
  capital_loot integer NOT NULL DEFAULT 0,
  clan_games_points integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (summary_date, clan_tag)
);

CREATE TABLE IF NOT EXISTS poller_jobs (
  job_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  queue_name text NOT NULL,
  job_type text NOT NULL,
  dedupe_key text,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  priority integer NOT NULL DEFAULT 100,
  attempts integer NOT NULL DEFAULT 0,
  max_attempts integer NOT NULL DEFAULT 10,
  available_at timestamptz NOT NULL DEFAULT now(),
  locked_by text,
  locked_until timestamptz,
  last_error text,
  status text NOT NULL DEFAULT 'pending' CHECK (
    status IN ('pending', 'running', 'succeeded', 'failed', 'dead')
  ),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS poller_cursors (
  cursor_key text PRIMARY KEY,
  cursor_value jsonb NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS poller_key_state (
  key_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider text NOT NULL DEFAULT 'coc',
  fingerprint text NOT NULL UNIQUE,
  status text NOT NULL DEFAULT 'active' CHECK (
    status IN ('active', 'cooldown', 'disabled', 'failed')
  ),
  cooldown_until timestamptz,
  last_success_at timestamptz,
  last_failure_at timestamptz,
  failure_count integer NOT NULL DEFAULT 0,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS command_catalog (
  command_name text PRIMARY KEY,
  category text NOT NULL,
  owner_runtime text NOT NULL,
  is_approved boolean NOT NULL DEFAULT true,
  is_enabled boolean NOT NULL DEFAULT true,
  introduced_in_phase integer,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS command_usage_daily (
  usage_date date NOT NULL,
  command_name text NOT NULL REFERENCES command_catalog (command_name) ON DELETE CASCADE,
  guild_id text NOT NULL DEFAULT 'global',
  user_count integer NOT NULL DEFAULT 0,
  invocation_count integer NOT NULL DEFAULT 0,
  error_count integer NOT NULL DEFAULT 0,
  PRIMARY KEY (usage_date, command_name, guild_id)
);

CREATE INDEX IF NOT EXISTS idx_guilds_active
  ON guilds (is_active);

CREATE UNIQUE INDEX IF NOT EXISTS ux_guild_categories_guild_name
  ON guild_categories (guild_id, lower(name));

CREATE INDEX IF NOT EXISTS idx_guild_categories_guild_position
  ON guild_categories (guild_id, position);

CREATE INDEX IF NOT EXISTS idx_guild_clans_guild_position
  ON guild_clans (guild_id, position)
  WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_guild_feature_flags_enabled
  ON guild_feature_flags (flag_key, enabled)
  WHERE enabled = true;

CREATE INDEX IF NOT EXISTS idx_auth_handoff_tokens_active
  ON auth_handoff_tokens (guild_id, user_id, expires_at)
  WHERE consumed_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_auth_sessions_active
  ON auth_sessions (user_id, guild_id, expires_at)
  WHERE revoked_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_user_profiles_timezone
  ON user_profiles (timezone);

CREATE INDEX IF NOT EXISTS idx_user_profiles_display_name_trgm
  ON user_profiles USING gin (lower(display_name) gin_trgm_ops);

CREATE UNIQUE INDEX IF NOT EXISTS ux_link_player_links_active_player
  ON link_player_links (player_tag)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_link_player_links_user
  ON link_player_links (user_id, guild_id, link_order)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_link_player_links_name_trgm
  ON link_player_links USING gin (lower(player_name) gin_trgm_ops)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_link_audit_logs_lookup
  ON link_audit_logs (player_tag, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_coc_players_cache_clan_tag
  ON coc_players_cache (clan_tag);

CREATE INDEX IF NOT EXISTS idx_coc_players_cache_expires_at
  ON coc_players_cache (expires_at);

CREATE INDEX IF NOT EXISTS idx_coc_players_cache_name_trgm
  ON coc_players_cache USING gin (lower(name) gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_coc_clans_cache_expires_at
  ON coc_clans_cache (expires_at);

CREATE INDEX IF NOT EXISTS idx_coc_clans_cache_name_trgm
  ON coc_clans_cache USING gin (lower(name) gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_coc_wars_cache_lookup
  ON coc_wars_cache (clan_tag, start_time DESC);

CREATE INDEX IF NOT EXISTS idx_coc_raid_weekends_cache_lookup
  ON coc_raid_weekends_cache (clan_tag, start_time DESC);

CREATE INDEX IF NOT EXISTS idx_coc_cwl_groups_cache_lookup
  ON coc_cwl_groups_cache (clan_tag, season DESC);

CREATE INDEX IF NOT EXISTS idx_history_player_events_lookup
  ON history_player_events (player_tag, event_type, event_time DESC);

CREATE INDEX IF NOT EXISTS idx_history_player_events_clan_time
  ON history_player_events (clan_tag, event_time DESC);

CREATE INDEX IF NOT EXISTS idx_history_trophy_snapshots_player_season
  ON history_player_trophy_snapshots (player_tag, season, recorded_at DESC);

CREATE INDEX IF NOT EXISTS idx_history_donation_snapshots_player_season
  ON history_donation_snapshots (player_tag, season, recorded_at DESC);

CREATE INDEX IF NOT EXISTS idx_history_war_attacks_lookup
  ON history_war_attacks (attacker_tag, war_start_time DESC);

CREATE INDEX IF NOT EXISTS idx_history_capital_contribution_lookup
  ON history_capital_contribution_events (player_tag, season, recorded_at DESC);

CREATE INDEX IF NOT EXISTS idx_history_capital_raid_lookup
  ON history_capital_raid_attacks (player_tag, raid_weekend_start DESC);

CREATE INDEX IF NOT EXISTS idx_history_clan_games_lookup
  ON history_clan_games_scores (player_tag, season, recorded_at DESC);

CREATE INDEX IF NOT EXISTS idx_analytics_daily_player_summary_lookup
  ON analytics_daily_player_summary (player_tag, summary_date DESC);

CREATE INDEX IF NOT EXISTS idx_analytics_daily_clan_summary_lookup
  ON analytics_daily_clan_summary (clan_tag, summary_date DESC);

CREATE UNIQUE INDEX IF NOT EXISTS ux_poller_jobs_dedupe_active
  ON poller_jobs (queue_name, dedupe_key)
  WHERE dedupe_key IS NOT NULL AND status IN ('pending', 'running');

CREATE INDEX IF NOT EXISTS idx_poller_jobs_dequeue
  ON poller_jobs (queue_name, status, priority DESC, available_at ASC)
  WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_poller_jobs_locked_until
  ON poller_jobs (locked_until)
  WHERE status = 'running';

CREATE INDEX IF NOT EXISTS idx_poller_key_state_status
  ON poller_key_state (status, cooldown_until);

CREATE INDEX IF NOT EXISTS idx_command_catalog_category
  ON command_catalog (category, is_enabled);

CREATE INDEX IF NOT EXISTS idx_command_usage_daily_lookup
  ON command_usage_daily (command_name, usage_date DESC);

CREATE OR REPLACE VIEW poller_v_ready_jobs AS
SELECT
  job_id,
  queue_name,
  job_type,
  payload,
  priority,
  available_at
FROM poller_jobs
WHERE status = 'pending'
  AND available_at <= now()
  AND (locked_until IS NULL OR locked_until <= now())
ORDER BY priority DESC, available_at ASC;

CREATE OR REPLACE VIEW coc_v_fresh_players AS
SELECT *
FROM coc_players_cache
WHERE expires_at > now();

CREATE OR REPLACE VIEW link_v_active_links AS
SELECT *
FROM link_player_links
WHERE deleted_at IS NULL;

CREATE MATERIALIZED VIEW IF NOT EXISTS analytics_mv_player_search AS
SELECT
  p.player_tag,
  p.name,
  p.clan_tag,
  l.guild_id,
  l.user_id,
  COALESCE(u.display_name, l.user_id) AS display_name,
  setweight(to_tsvector('simple', COALESCE(p.name, '')), 'A') ||
  setweight(
    to_tsvector('simple', replace(COALESCE(p.player_tag, ''), '#', ' ')),
    'A'
  ) ||
  setweight(to_tsvector('simple', COALESCE(u.display_name, '')), 'B')
    AS search_document
FROM coc_players_cache p
LEFT JOIN link_player_links l
  ON l.player_tag = p.player_tag
 AND l.deleted_at IS NULL
LEFT JOIN user_profiles u
  ON u.user_id = l.user_id;

CREATE MATERIALIZED VIEW IF NOT EXISTS analytics_mv_clan_search AS
SELECT
  c.clan_tag,
  c.name,
  c.member_count,
  c.war_league,
  setweight(to_tsvector('simple', COALESCE(c.name, '')), 'A') ||
  setweight(
    to_tsvector('simple', replace(COALESCE(c.clan_tag, ''), '#', ' ')),
    'A'
  ) AS search_document
FROM coc_clans_cache c;

CREATE UNIQUE INDEX IF NOT EXISTS ux_analytics_mv_player_search_tag
  ON analytics_mv_player_search (player_tag);

CREATE INDEX IF NOT EXISTS idx_analytics_mv_player_search_document
  ON analytics_mv_player_search USING gin (search_document);

CREATE INDEX IF NOT EXISTS idx_analytics_mv_player_search_name_trgm
  ON analytics_mv_player_search USING gin (lower(name) gin_trgm_ops);

CREATE UNIQUE INDEX IF NOT EXISTS ux_analytics_mv_clan_search_tag
  ON analytics_mv_clan_search (clan_tag);

CREATE INDEX IF NOT EXISTS idx_analytics_mv_clan_search_document
  ON analytics_mv_clan_search USING gin (search_document);

CREATE INDEX IF NOT EXISTS idx_analytics_mv_clan_search_name_trgm
  ON analytics_mv_clan_search USING gin (lower(name) gin_trgm_ops);

DROP TRIGGER IF EXISTS trg_guilds_set_updated_at ON guilds;
CREATE TRIGGER trg_guilds_set_updated_at
BEFORE UPDATE ON guilds
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_guild_categories_set_updated_at ON guild_categories;
CREATE TRIGGER trg_guild_categories_set_updated_at
BEFORE UPDATE ON guild_categories
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_guild_clans_set_updated_at ON guild_clans;
CREATE TRIGGER trg_guild_clans_set_updated_at
BEFORE UPDATE ON guild_clans
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_guild_settings_set_updated_at ON guild_settings;
CREATE TRIGGER trg_guild_settings_set_updated_at
BEFORE UPDATE ON guild_settings
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_guild_feature_flags_set_updated_at ON guild_feature_flags;
CREATE TRIGGER trg_guild_feature_flags_set_updated_at
BEFORE UPDATE ON guild_feature_flags
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_auth_api_clients_set_updated_at ON auth_api_clients;
CREATE TRIGGER trg_auth_api_clients_set_updated_at
BEFORE UPDATE ON auth_api_clients
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_auth_sessions_set_updated_at ON auth_sessions;
CREATE TRIGGER trg_auth_sessions_set_updated_at
BEFORE UPDATE ON auth_sessions
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_user_profiles_set_updated_at ON user_profiles;
CREATE TRIGGER trg_user_profiles_set_updated_at
BEFORE UPDATE ON user_profiles
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_link_player_links_set_updated_at ON link_player_links;
CREATE TRIGGER trg_link_player_links_set_updated_at
BEFORE UPDATE ON link_player_links
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_poller_jobs_set_updated_at ON poller_jobs;
CREATE TRIGGER trg_poller_jobs_set_updated_at
BEFORE UPDATE ON poller_jobs
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_poller_key_state_set_updated_at ON poller_key_state;
CREATE TRIGGER trg_poller_key_state_set_updated_at
BEFORE UPDATE ON poller_key_state
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();
