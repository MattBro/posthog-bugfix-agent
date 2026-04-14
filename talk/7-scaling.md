# Lesson 5: Scaling to large codebases

Current setup clones per-session - fine for small repos, expensive for large ones. Two paths:

- **`init_script`**: Pre-clone the repo when the container starts. Agent wakes up with code on disk.
- **MCP-only**: Use GitHub MCP tools to read only the files needed. No clone at all.
