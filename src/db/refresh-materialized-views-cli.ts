import {
  closeRefreshMaterializedViewsPool,
  runRefreshMaterializedViews,
} from './refresh-materialized-views.js';

runRefreshMaterializedViews()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await closeRefreshMaterializedViewsPool();
  });
