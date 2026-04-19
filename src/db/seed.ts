import { closePool, withTransaction } from './postgres.js';
import {
  guildCategoryFixtures,
  guildClanFixtures,
  guildFixtures,
  linkFixtures,
  playerFixtures,
  userProfileFixtures,
} from './dev-fixtures.js';
import { approvedCommandManifest } from './command-manifest.js';
import { refreshMaterializedViews } from './refresh-materialized-views.js';

async function seedGuilds() {
  await withTransaction(async (client) => {
    for (const guild of guildFixtures) {
      await client.query(
        `
          INSERT INTO guilds (guild_id, name, bot_kind)
          VALUES ($1, $2, $3)
          ON CONFLICT (guild_id) DO UPDATE
          SET name = EXCLUDED.name,
              bot_kind = EXCLUDED.bot_kind,
              updated_at = now()
        `,
        [guild.guildId, guild.name, guild.botKind]
      );

      await client.query(
        `
          INSERT INTO guild_settings (guild_id, timezone, locale)
          VALUES ($1, 'UTC', 'en')
          ON CONFLICT (guild_id) DO NOTHING
        `,
        [guild.guildId]
      );
    }

    for (const category of guildCategoryFixtures) {
      await client.query(
        `
          INSERT INTO guild_categories (guild_id, name, position)
          VALUES ($1, $2, $3)
          ON CONFLICT DO NOTHING
        `,
        [category.guildId, category.name, category.position]
      );
    }

    await client.query(
      `
        INSERT INTO guild_feature_flags (guild_id, flag_key, enabled, config)
        VALUES ($1, 'links_web', true, '{"gatedPaths":["/clans","/links","/rosters"]}'::jsonb)
        ON CONFLICT (guild_id, flag_key) DO UPDATE
        SET enabled = EXCLUDED.enabled,
            config = EXCLUDED.config,
            updated_at = now()
      `,
      ['111111111111111111']
    );

    for (const clan of guildClanFixtures) {
      const categoryIdResult = await client.query<{ category_id: string }>(
        `
          SELECT category_id
          FROM guild_categories
          WHERE guild_id = $1 AND name = $2
        `,
        [clan.guildId, clan.categoryName]
      );

      const categoryId = categoryIdResult.rows[0]?.category_id ?? null;

      await client.query(
        `
          INSERT INTO guild_clans (
            guild_id,
            coc_clan_tag,
            category_id,
            display_name,
            position
          )
          VALUES ($1, $2, $3, $4, $5)
          ON CONFLICT (guild_id, coc_clan_tag) DO UPDATE
          SET category_id = EXCLUDED.category_id,
              display_name = EXCLUDED.display_name,
              position = EXCLUDED.position
        `,
        [
          clan.guildId,
          clan.clanTag,
          categoryId,
          clan.displayName,
          clan.position,
        ]
      );
    }
  });
}

async function seedUsersAndLinks() {
  await withTransaction(async (client) => {
    for (const profile of userProfileFixtures) {
      await client.query(
        `
          INSERT INTO user_profiles (
            user_id,
            display_name,
            timezone,
            locale,
            profile
          )
          VALUES ($1, $2, $3, $4, '{}'::jsonb)
          ON CONFLICT (user_id) DO UPDATE
          SET display_name = EXCLUDED.display_name,
              timezone = EXCLUDED.timezone,
              locale = EXCLUDED.locale,
              updated_at = now()
        `,
        [
          profile.userId,
          profile.displayName,
          profile.timezone,
          profile.locale,
        ]
      );
    }

    for (const player of playerFixtures) {
      await client.query(
        `
          INSERT INTO coc_players_cache (
            player_tag,
            name,
            clan_tag,
            town_hall_level,
            trophies,
            raw_payload,
            expires_at
          )
          VALUES ($1, $2, $3, $4, $5, $6::jsonb, now() + interval '1 day')
          ON CONFLICT (player_tag) DO UPDATE
          SET name = EXCLUDED.name,
              clan_tag = EXCLUDED.clan_tag,
              town_hall_level = EXCLUDED.town_hall_level,
              trophies = EXCLUDED.trophies,
              raw_payload = EXCLUDED.raw_payload,
              fetched_at = now(),
              expires_at = EXCLUDED.expires_at
        `,
        [
          player.playerTag,
          player.name,
          player.clanTag,
          player.townHallLevel,
          player.trophies,
          JSON.stringify({
            tag: player.playerTag,
            name: player.name,
            clanTag: player.clanTag,
            townHallLevel: player.townHallLevel,
            trophies: player.trophies,
          }),
        ]
      );
    }

    await client.query(
      `
        INSERT INTO coc_clans_cache (
          clan_tag,
          name,
          member_count,
          war_league,
          raw_payload,
          expires_at
        )
        VALUES
          (
            '#2PP',
            'ClashMate Alpha',
            50,
            'Champion League III',
            '{"tag":"#2PP","name":"ClashMate Alpha"}'::jsonb,
            now() + interval '1 day'
          ),
          (
            '#2QQ',
            'ClashMate Bravo',
            42,
            'Master League I',
            '{"tag":"#2QQ","name":"ClashMate Bravo"}'::jsonb,
            now() + interval '1 day'
          )
        ON CONFLICT (clan_tag) DO UPDATE
        SET name = EXCLUDED.name,
            member_count = EXCLUDED.member_count,
            war_league = EXCLUDED.war_league,
            raw_payload = EXCLUDED.raw_payload,
            fetched_at = now(),
            expires_at = EXCLUDED.expires_at
      `
    );

    for (const link of linkFixtures) {
      await client.query(
        `
          INSERT INTO link_player_links (
            player_tag,
            player_name,
            user_id,
            guild_id,
            linked_by_user_id,
            source,
            is_verified,
            link_order
          )
          VALUES ($1, $2, $3, $4, $5, 'seed', $6, $7)
          ON CONFLICT DO NOTHING
        `,
        [
          link.playerTag,
          link.playerName,
          link.userId,
          link.guildId,
          link.linkedByUserId,
          link.isVerified,
          link.linkOrder,
        ]
      );

      await client.query(
        `
          INSERT INTO link_audit_logs (
            link_id,
            player_tag,
            user_id,
            guild_id,
            action,
            actor_user_id,
            payload
          )
          SELECT
            link_id,
            player_tag,
            user_id,
            guild_id,
            'link',
            linked_by_user_id,
            jsonb_build_object('source', source, 'verified', is_verified)
          FROM link_player_links
          WHERE player_tag = $1
            AND NOT EXISTS (
              SELECT 1
              FROM link_audit_logs
              WHERE player_tag = $1
                AND action = 'link'
                AND actor_user_id = $2
            )
        `,
        [link.playerTag, link.linkedByUserId]
      );
    }
  });
}

async function seedAuthAndCommands() {
  await withTransaction(async (client) => {
    await client.query(
      `
        INSERT INTO auth_api_clients (
          client_id,
          client_name,
          client_type,
          hashed_secret,
          scopes
        )
        VALUES (
          'clashmate-bot-dev',
          'ClashMate Bot Dev',
          'bot',
          'dev-secret-hash-not-real',
          ARRAY['links:read', 'links:write', 'handoff:create']::text[]
        )
        ON CONFLICT (client_id) DO UPDATE
        SET client_name = EXCLUDED.client_name,
            client_type = EXCLUDED.client_type,
            hashed_secret = EXCLUDED.hashed_secret,
            scopes = EXCLUDED.scopes,
            updated_at = now()
      `
    );

    for (const command of approvedCommandManifest) {
      await client.query(
        `
          INSERT INTO command_catalog (
            command_name,
            category,
            owner_runtime,
            is_approved,
            is_enabled,
            introduced_in_phase,
            metadata
          )
          VALUES ($1, $2, $3, true, true, $4, $5::jsonb)
          ON CONFLICT (command_name) DO UPDATE
          SET category = EXCLUDED.category,
              owner_runtime = EXCLUDED.owner_runtime,
              introduced_in_phase = EXCLUDED.introduced_in_phase,
              metadata = EXCLUDED.metadata
        `,
        [
          command.commandName,
          command.category,
          command.ownerRuntime,
          command.introducedInPhase,
          JSON.stringify({ priority: command.priority }),
        ]
      );
    }
  });
}

async function run() {
  await seedGuilds();
  await seedUsersAndLinks();
  await seedAuthAndCommands();

  await withTransaction(async (client) => {
    await refreshMaterializedViews(client);
  });

  console.log('database seed complete');
}

run()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await closePool();
  });
