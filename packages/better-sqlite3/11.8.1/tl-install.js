'use strict';
// TL install shim — copies prebuilt addon from @calunga/better-sqlite3-linux-x64 (Pulp).
// No prebuild-install or node-gyp on consumer machines.
const fs = require('fs');
const path = require('path');

const platformPkg = '@calunga/better-sqlite3-linux-x64';
let src;
try {
  src = require.resolve(`${platformPkg}/better_sqlite3.node`);
} catch (err) {
  console.error(
    `[better-sqlite3] Missing TL platform package ${platformPkg}. ` +
      'Install from the Trusted Libraries npm registry.'
  );
  process.exit(1);
}

const destDir = path.join(__dirname, 'build', 'Release');
const dest = path.join(destDir, 'better_sqlite3.node');
fs.mkdirSync(destDir, { recursive: true });
fs.copyFileSync(src, dest);
