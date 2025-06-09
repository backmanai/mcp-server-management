# MCP Server Management System

A unified system for managing multiple Model Context Protocol (MCP) servers using PM2 and Git submodules.

## Prerequisites

- **Node.js** (v18 or higher)
- **Python** (v3.8 or higher)
- **PM2** (`npm install -g pm2`)
- **Git**

## Quick Setup

```bash
# Initialize the system
./manage.sh init

# Set up environment variables
cp .env.example .env
# Edit .env with your API keys

# Add shell integration (optional)
echo 'alias mcp="~/mcp-servers/manage.sh"' >> ~/.zshrc
source ~/.zshrc
