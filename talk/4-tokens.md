# Lesson 3: Token efficiency

System prompt is sent every turn. Compress it.

```
Before (~500 tokens): "You are an autonomous bug-fixing agent. When you receive..."
After  (~250 tokens): "Autonomous bugfix agent. User msg has REPO, GITHUB_TOKEN..."
```

Also strip duplicate instructions from the user message - don't repeat what the system prompt already says.
