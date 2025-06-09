const path = require('path');
const serversDir = path.join(__dirname, 'servers');

module.exports = {
  apps: [
    // Add your MCP servers here
    // Examples:
    //
    // NPM package server:
    // {
    //   name: 'server-name',
    //   script: 'npx',
    //   args: ['-y', '@package/server-name', 'arg1', 'arg2'],
    //   env: {
    //     API_KEY: process.env.API_KEY
    //   },
    //   autorestart: true
    // }
    //
    // Local Node.js server:
    // {
    //   name: 'local-server',
    //   script: 'dist/index.js',
    //   cwd: path.join(serversDir, 'local-server'),
    //   args: '--stdio',
    //   env: {
    //     NODE_ENV: 'production'
    //   },
    //   autorestart: true
    // }
    //
    // Local Python server:
    // {
    //   name: 'python-server',
    //   script: 'src/server.py',
    //   cwd: path.join(serversDir, 'python-server'),
    //   interpreter: path.join(serversDir, 'python-server/.venv/bin/python'),
    //   args: '--stdio',
    //   env: {
    //     PYTHONPATH: path.join(serversDir, 'python-server/src')
    //   },
    //   autorestart: true
    // }
  ]
};
