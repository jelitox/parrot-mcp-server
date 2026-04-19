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
uv pip install ai-parrot[mcp,llms]
```

### Create the environment file

```bash
mkdir -p env
cat > env/.env <<'EOF'
# Example for mcp_servers/server.yaml
MCP_AWS_SERVER_API_KEY=change-me
EOF
```

Load that file into your shell before starting the server, or pass it to Docker with `--env-file env/.env`.

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

## Adding Custom Tools

You can easily extend `parrot-mcp-server` by adding your own custom tools in the `plugins/tools/` directory. The MCP server loader automatically scans this directory to expose them as MCP endpoints.

There are three main ways to build custom tools:

### 1. Extending `AbstractTool`
Useful for simple, single-purpose tools that implement a specific `_execute` action.

```python
# plugins/tools/my_tools.py
import asyncio
from parrot.tools.abstract import AbstractTool

class MyCustomTool(AbstractTool):
    name = "MyCustomTool"
    description = "A custom tool that echoes text."
    
    async def _execute(self, text: str) -> str:
        return f"Echo: {text}"
```

In `server.yaml`:
```yaml
MCPServer:
  tools:
    - MyCustomTool:
```

### 2. Extending `AbstractToolkit`
Toolkits are designed to group multiple related tools into a single class. **Any public asynchronous method (not starting with `_`) inside an `AbstractToolkit` subclass is automatically exposed as its own standalone MCP tool.**

This is ideal for wrapping an entire API or SDK where multiple functions share the same initialization parameters (like API keys or connections).

```python
# plugins/tools/my_toolkit.py
from parrot.tools.toolkit import AbstractToolkit

class MyApiToolkit(AbstractToolkit):
    def __init__(self, api_key: str):
        self.api_key = api_key
        
    async def get_user_info(self, user_id: int) -> str:
        """Fetch user information."""
        return f"User {user_id} info using key {self.api_key}"
        
    async def get_billing_status(self, user_id: int) -> str:
        """Fetch billing details."""
        return f"Billing status for {user_id}"
```

In `server.yaml`, provide the initialization arguments (they support automatic Env-Var replacement):
```yaml
MCPServer:
  tools:
    - MyApiToolkit:
        api_key: MY_SECRET_API_KEY
```
*Result: The MCP server will expose two tools named `get_user_info` and `get_billing_status`.*

### 3. Using the `@tool` Decorator
For quick scripting, you can decorate a standard Python function. 

```python
# plugins/tools/simple_tools.py
from parrot.tools.decorators import tool

@tool(
    name="SystemPing",
    description="Returns a simple ping response"
)
async def ping_tool() -> str:
    return "pong"
```

In `server.yaml`:
```yaml
MCPServer:
  tools:
    - ping_tool:
```


## 🤝 Community & Support

*   **Issues**: [GitHub Tracker](https://github.com/phenobarbital/parrot-mcp-server/issues)
*   **Discussion**: [GitHub Discussions](https://github.com/phenobarbital/parrot-mcp-server/discussions)
*   **Contribution**: Pull requests are welcome! Please read `CONTRIBUTING.md`.

---
*Built with ❤️ by the AI-Parrot Team*
