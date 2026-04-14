# Demo cheat sheet

### Setup
- [emmettsgame.com](https://www.emmettsgame.com/) - the game
- PostHog: Hog function destination, inputs (repo, agent ID, vault ID)
- Claude Console: agent definition, environment, vault

### Trigger
- Cause the error in the game
- PostHog error tracking: `$exception` with stack trace
- Hog function logs: "Won lock", session created

### Watch it work
- Claude Console sessions: Running -> Idle, open transcript
- GitHub: merged PR, minimal diff
- PostHog: issue status **resolved**
