<#
.SYNOPSIS
    Wrapper that launches the GitHub MCP server via Docker, auto-resolving
    the GITHUB_TOKEN from the gh CLI keyring.
.DESCRIPTION
    Conductor MCP server env: fields don't support shell expansion, so this
    wrapper resolves the token at launch time and passes it to Docker.
    Stdin/stdout are transparently proxied to the container.
#>
$ErrorActionPreference = 'Stop'

$token = gh auth token 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to get GitHub token from gh CLI. Run 'gh auth login' first."
    exit 1
}

# Launch Docker with stdin connected (-i) and auto-remove (--rm)
# The container runs the GitHub MCP server in stdio mode
docker run -i --rm `
    -e "GITHUB_TOKEN=$token" `
    ghcr.io/github/github-mcp-server:latest stdio
