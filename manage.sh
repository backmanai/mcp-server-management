#!/bin/bash

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVERS_DIR="$REPO_DIR/servers"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

# Detect server type based on files present
detect_server_type() {
    local server_path="$1"
    if [ -f "$server_path/package.json" ]; then
        echo "nodejs"
    elif [ -f "$server_path/requirements.txt" ] || [ -f "$server_path/pyproject.toml" ]; then
        echo "python"
    else
        echo "unknown"
    fi
}

# Setup dependencies for a server
setup_server() {
    local server_name="$1"
    local server_path="$SERVERS_DIR/$server_name"
    
    if [ ! -d "$server_path" ]; then
        log_error "Server $server_name not found. Run 'git submodule update --init' first."
        return 1
    fi
    
    local server_type=$(detect_server_type "$server_path")
    
    log_info "Setting up $server_name ($server_type)..."
    cd "$server_path"
    
    case "$server_type" in
        nodejs)
            npm install
            # Check if there's a build script
            if npm run | grep -q "build"; then
                npm run build
                log_success "Built $server_name"
            fi
            log_success "Node.js dependencies installed for $server_name"
            ;;
        python)
            if [ ! -d ".venv" ]; then
                log_info "Creating virtual environment for $server_name..."
                python3 -m venv .venv
            fi
            
            source .venv/bin/activate
            
            if [ -f "requirements.txt" ]; then
                pip install -r requirements.txt
                log_success "Python requirements installed for $server_name"
            fi
            
            if [ -f "pyproject.toml" ]; then
                pip install -e .
                log_success "Python package installed for $server_name"
            fi
            ;;
        *)
            log_warning "Unknown server type for $server_name"
            ;;
    esac
}

check_pm2() {
    if ! command -v pm2 &> /dev/null; then
        log_error "PM2 is not installed. Please install it first:"
        echo "  npm install -g pm2"
        exit 1
    fi
}

case "$1" in
    init)
        log_info "Initializing MCP server management system..."
        cd "$REPO_DIR"
        
        # Check if PM2 is installed
        check_pm2
        
        # Initialize submodules if any exist
        if [ -f ".gitmodules" ]; then
            log_info "Initializing git submodules..."
            git submodule update --init --recursive
        else
            log_info "No submodules found"
        fi
        
        # Setup all servers
        if [ "$(ls -A $SERVERS_DIR 2>/dev/null | grep -v .gitkeep)" ]; then
            log_info "Setting up servers..."
            for dir in "$SERVERS_DIR"/*/; do
                if [ -d "$dir" ]; then
                    setup_server "$(basename "$dir")"
                fi
            done
        else
            log_info "No servers found to set up"
        fi
        
        log_success "Initialization complete!"
        ;;
    add)
        if [ -z "$2" ] || [ -z "$3" ]; then
            log_error "Usage: $0 add <server-name> <git-url>"
            exit 1
        fi
        log_info "Adding $2 as submodule from $3..."
        cd "$REPO_DIR"
        git submodule add "$3" "servers/$2"
        setup_server "$2"
        log_success "Server $2 added! Don't forget to add it to ecosystem.config.js and commit changes."
        ;;
    update)
        cd "$REPO_DIR"
        if [ -z "$2" ]; then
            if [ -f ".gitmodules" ]; then
                log_info "Updating all submodules..."
                git submodule update --remote
                for dir in "$SERVERS_DIR"/*/; do
                    if [ -d "$dir" ]; then
                        setup_server "$(basename "$dir")"
                    fi
                done
            else
                log_info "No submodules to update"
            fi
        else
            log_info "Updating $2..."
            git submodule update --remote "servers/$2"
            setup_server "$2"
        fi
        log_success "Update complete!"
        ;;
    start)
        check_pm2
        if [ -z "$2" ]; then
            log_info "Starting all MCP servers..."
            cd "$REPO_DIR" && pm2 start ecosystem.config.js
        else
            log_info "Starting $2..."
            pm2 start "$2"
        fi
        ;;
    stop)
        check_pm2
        if [ -z "$2" ]; then
            log_info "Stopping all MCP servers..."
            pm2 stop ecosystem.config.js
        else
            log_info "Stopping $2..."
            pm2 stop "$2"
        fi
        ;;
    restart)
        check_pm2
        if [ -z "$2" ]; then
            log_info "Restarting all MCP servers..."
            pm2 restart ecosystem.config.js
        else
            log_info "Restarting $2..."
            pm2 restart "$2"
        fi
        ;;
    list)
        check_pm2
        pm2 list
        ;;
    logs)
        check_pm2
        if [ -z "$2" ]; then
            pm2 logs
        else
            pm2 logs "$2"
        fi
        ;;
    status)
        check_pm2
        log_info "MCP Server Status:"
        pm2 list
        ;;
    info)
        if [ "$(ls -A $SERVERS_DIR 2>/dev/null | grep -v .gitkeep)" ]; then
            log_info "MCP Servers:"
            for dir in "$SERVERS_DIR"/*/; do
                if [ -d "$dir" ]; then
                    server_name=$(basename "$dir")
                    server_type=$(detect_server_type "$dir")
                    echo "  $server_name: $server_type"
                fi
            done
        else
            log_info "No servers found. Use '$0 add <name> <url>' to add servers."
        fi
        ;;
    generate-config)
        if [ -z "$2" ]; then
            log_error "Usage: $0 generate-config <claude|vscode|cursor>"
            exit 1
        fi
        
        cd "$REPO_DIR"
        
        case "$2" in
            claude)
                log_info "Generating Claude Desktop configuration..."
                node -e "
                const config = require('./ecosystem.config.js');
                const mcpServers = {};
                
                config.apps.forEach(app => {
                    if (app.internal_only) return;
                    
                    if (app.script === 'npx') {
                        mcpServers[app.name] = {
                            command: 'npx',
                            args: app.args,
                            env: app.env || {}
                        };
                    } else {
                        mcpServers[app.name] = {
                            command: 'node',
                            args: [require('path').join('$REPO_DIR', 'servers', app.name, app.script)],
                            env: app.env || {}
                        };
                    }
                });
                
                console.log(JSON.stringify({ mcpServers }, null, 2));
                " > claude_desktop_config.json
                log_success "Claude Desktop config generated: claude_desktop_config.json"
                log_info "Copy this to:"
                log_info "  macOS: ~/Library/Application Support/Claude/claude_desktop_config.json"
                log_info "  Windows: %APPDATA%/Claude/claude_desktop_config.json"
                ;;
            vscode)
                log_info "Generating VS Code configuration..."
                node -e "
                const config = require('./ecosystem.config.js');
                const mcpServers = {};
                
                config.apps.forEach(app => {
                    if (app.internal_only) return;
                    
                    if (app.script === 'npx') {
                        mcpServers[app.name] = {
                            command: 'npx',
                            args: app.args
                        };
                    } else {
                        mcpServers[app.name] = {
                            command: 'node',
                            args: [require('path').join('$REPO_DIR', 'servers', app.name, app.script)]
                        };
                    }
                });
                
                console.log(JSON.stringify({ 'mcp.servers': mcpServers }, null, 2));
                " > vscode_settings.json
                log_success "VS Code config generated: vscode_settings.json"
                ;;
            cursor)
                log_info "Generating Cursor configuration..."
                node -e "
                const config = require('./ecosystem.config.js');
                const mcpServers = {};
                
                config.apps.forEach(app => {
                    if (app.internal_only) return;
                    
                    if (app.script === 'npx') {
                        mcpServers[app.name] = {
                            command: 'npx',
                            args: app.args
                        };
                    } else {
                        mcpServers[app.name] = {
                            command: 'node',
                            args: [require('path').join('$REPO_DIR', 'servers', app.name, app.script)]
                        };
                    }
                });
                
                console.log(JSON.stringify({ mcpServers }, null, 2));
                " > cursor_settings.json
                log_success "Cursor config generated: cursor_settings.json"
                ;;
            *)
                log_error "Unsupported client. Use: claude, vscode, or cursor"
                exit 1
                ;;
        esac
        ;;
    *)
        echo "🔧 MCP Server Management"
        echo ""
        echo "Usage: $0 {init|add|update|start|stop|restart|list|logs|status|info|generate-config} [args...]"
        echo ""
        echo "Commands:"
        echo "  init                    - Initialize all submodules and setup dependencies"
        echo "  add <name> <url>        - Add new server as git submodule"
        echo "  update [name]           - Update all or specific submodule"
        echo "  start [name]            - Start all servers or specific server"
        echo "  stop [name]             - Stop all servers or specific server"
        echo "  restart [name]          - Restart all servers or specific server"
        echo "  list                    - List all running servers"
        echo "  logs [name]             - Show logs for all or specific server"
        echo "  status                  - Show detailed status of all servers"
        echo "  info                    - Show server information"
        echo "  generate-config <type>  - Generate client configuration (claude|vscode|cursor)"
        echo ""
        echo "Getting Started:"
        echo "  $0 add my-server https://github.com/user/mcp-server"
        echo "  # Edit ecosystem.config.js to configure the server"
        echo "  $0 start"
        echo "  $0 generate-config claude"
        ;;
esac
