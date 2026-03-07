# AI-Parrot MCP Server

This repository hosts Model Context Protocol (MCP) server configurations using `ai-parrot`. It allows you to expose various `ai-parrot` tools (or custom functions) as MCP-compliant servers that can be consumed by AI agents and clients (like Claude Desktop, Antigravity, etc.).

## Quick Start

### Installation:

```bash
# Install uv
curl -LsSf https://astral.sh/uv/install.sh | sh

# Create virtual environment
uv venv --python 3.11 .venv

# Activate virtual environment
source .venv/bin/activate

# Install dependencies
uv sync

# or manually install ai-parrot:
uv install ai-parrot[mcp,llms]
```

### Create the environment file:

```bash
mkdir env
kardex create
```
This creates the entire NavConfig project structure at `parrot-mcp-server` (environment: dev)

### Creating a New Configuration

1. create a directory `mcp_servers`
2. Create a new file in `mcp_servers/` (e.g., `server.yaml`).
3. Add the `MCPServer` block.
4. List the tools you want to expose.

**Example: Google Search Server**
```yaml
MCPServer:
  name: GoogleMCP
  port: 8082
  transport: http
  tools:
    - GoogleSearch:
        api_key: GOOGLE_API_KEY
        cse_id: GOOGLE_CSE_ID
```


### Run the MCP server:

```bash
parrot mcp --config mcp_servers/server.yaml
```

## Configuration

Servers are configured using YAML files located in the `mcp_servers/` directory.

### Structure

A configuration file defines a single `MCPServer` block:

```yaml
MCPServer:
  name: MyServer               # Friendly name
  host: 0.0.0.0                # Host to bind to
  port: 8081                   # Port to listen on
  transport: http              # 'http' or 'stdio'
  auth_method: api_key         # 'none' or 'api_key'
  api_key: MY_ENV_API_KEY      # API Key (can be environment variable)
  tools:
    - ToolName:                # Class name of the tool/toolkit
        arg1: value            # Arguments passed to __init__
        arg2: ENV_VAR_NAME     # Environment variable substitution
```

#### Key Attributes

- **`transport`**:
    - `http`: Starts a web server (useful for remote access).
    - `stdio`: Uses standard input/output (useful for local integration with Claude Desktop).
    - `sse`: Starts a web server with Server-Sent Events (useful for remote access).
    - `ws`: Starts a web server with WebSocket (useful for remote access).
    - `quic`: Starts a web server with QUIC (useful for remote access).
    - `grpc`: Starts a web server with gRPC (useful for remote access).
    - `unix`: Starts a web server with Unix domain sockets (useful for local integration with Claude Desktop).
- **`auth_method`**:
    - `none`: No authentication required.
    - `api_key`: Requires `X-API-Key` header.
- **`api_key`**:
    - Sets the required API key when `auth_method` is `api_key`.
    - **Environment Substitution**: If the value checks an environment variable (e.g., `MCP_SERVER_API_KEY`), it will be used.
- **`tools`**:
    - A list of tools to load. Each entry is a dictionary where the key is the Tool/Toolkit class name (from `ai-parrot`) and the value is a dictionary of arguments.

### Environment Variable Substitution

You can use environment variables for **any** string value in the configuration (Server args or Tool args).
- If a value matches an existing environment variable name, it is replaced by that variable's value.
- Example: `"server_url": "JIRA_URL"` -> resolves to `os.getenv("JIRA_URL")`.

Read the AI-Parrot documentation for more information.

## Available Tools

Any tool available in `ai-parrot` can be loaded. Common tools include:

- **`JiraToolkit`**: Operations for Jira (Get, Search, Transition issues).
- **`GoogleSearch`**: Perform Google searches.
- **`OpenWeather`**: Get weather data.
- **`ArangoDBSearch`**: Search ArangoDB.
- **`PostgreSQLToolkit`** / **`DatabaseQuery`**: SQL database interactions.
- **`GitToolkit`**: Git repository operations.
- **`AWSCloudWatch`**: AWS CloudWatch logs and metrics.
- **`MsTeams`**: Microsoft Teams interaction.
- **`Office365`**: Outlook and Calendar (via `O365Toolkit`).

And many more, check the `ai-parrot` documentation for a complete list.

*Note: Ensure you satisfy the Python dependencies for specific tools (e.g., `jira` package for `JiraToolkit`).*

## Docker Support

You can run servers using the provided Docker image:

```bash
docker build -f docs/Dockerfile -t mcp-server .
docker run -p 8081:8081 --env-file .env.api mcp-server
```

The Dockerfile is configured to load `server.yaml`, which usually symlinks to your desired config in `mcp_servers/`.
