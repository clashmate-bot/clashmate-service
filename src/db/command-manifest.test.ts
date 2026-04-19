import test from 'node:test';
import assert from 'node:assert/strict';

import {
  approvedCommandCategoryCounts,
  approvedCommandCount,
  approvedCommandManifest,
} from './command-manifest.js';

test('approved command manifest stays aligned with Phase 1 scope', () => {
  assert.equal(approvedCommandCount, 126);
  assert.equal(approvedCommandManifest.length, 126);
  assert.equal(Object.keys(approvedCommandCategoryCounts).length, 18);

  const uniqueCommands = new Set(
    approvedCommandManifest.map((command) => command.commandName)
  );

  assert.equal(uniqueCommands.size, 126);
  assert.equal(approvedCommandCategoryCounts.link, 7);
  assert.equal(approvedCommandCategoryCounts.search, 22);
  assert.equal(approvedCommandCategoryCounts.summary, 16);
  assert.equal(approvedCommandCategoryCounts.history, 12);
});
