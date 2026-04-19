import type { PoolClient } from 'pg';

import { closePool, withTransaction } from './postgres.js';

export const materializedViews = [
  'analytics_mv_player_search',
  'analytics_mv_clan_search',
] as const;

export async function refreshMaterializedViews(
  client: PoolClient
): Promise<void> {
  for (const viewName of materializedViews) {
    await client.query(`REFRESH MATERIALIZED VIEW ${viewName}`);
  }
}

export async function runRefreshMaterializedViews(): Promise<void> {
  await withTransaction(async (client) => {
    await refreshMaterializedViews(client);
  });

  console.log('analytics materialized views refreshed');
}

export async function closeRefreshMaterializedViewsPool(): Promise<void> {
  await closePool();
}
