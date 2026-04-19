import { createHash } from 'node:crypto';
import { readdir, readFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { closePool, withTransaction } from './postgres.js';

const currentDir = dirname(fileURLToPath(import.meta.url));
const migrationsDir = join(currentDir, 'migrations');

interface AppliedMigrationRow {
  filename: string;
  checksum: string;
}

const migrationsTableName = 'clashmate.clashmate_schema_migrations';

async function ensureSchemaMigrationsTable() {
  await withTransaction(async (client) => {
    await client.query(`
      CREATE TABLE IF NOT EXISTS ${migrationsTableName} (
        filename text PRIMARY KEY,
        checksum text NOT NULL,
        executed_at timestamptz NOT NULL DEFAULT now()
      );
    `);
  });
}

async function getMigrationFiles(): Promise<string[]> {
  const files = await readdir(migrationsDir);

  return files.filter((file) => file.endsWith('.sql')).sort();
}

function checksumFor(input: string): string {
  return createHash('sha256').update(input).digest('hex');
}

async function getAppliedMigrations() {
  return withTransaction(async (client) => {
    const result = await client.query<AppliedMigrationRow>(
      `SELECT filename, checksum FROM ${migrationsTableName} ORDER BY filename ASC`
    );

    return new Map(
      result.rows.map((row: AppliedMigrationRow) => [
        row.filename,
        row.checksum,
      ] as const)
    );
  });
}

async function run() {
  await ensureSchemaMigrationsTable();
  const files = await getMigrationFiles();
  const applied = await getAppliedMigrations();

  for (const file of files) {
    const fullPath = join(migrationsDir, file);
    const sql = await readFile(fullPath, 'utf8');
    const checksum = checksumFor(sql);
    const appliedChecksum = applied.get(file);

    if (appliedChecksum) {
      if (appliedChecksum !== checksum) {
        throw new Error(`Migration checksum mismatch for ${file}`);
      }

      console.log(`skip ${file}`);
      continue;
    }

    console.log(`apply ${file}`);

    await withTransaction(async (client) => {
      await client.query(sql);
      await client.query(
        `
          INSERT INTO ${migrationsTableName} (filename, checksum)
          VALUES ($1, $2)
        `,
        [file, checksum]
      );
    });
  }

  console.log('migrations complete');
}

run()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await closePool();
  });
