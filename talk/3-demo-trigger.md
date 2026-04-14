# Demo: trigger the bug

### Cause an error
- Do something in the game that triggers the exception

### PostHog error tracking
- Show the `$exception` event with stack trace
- Show the error tracking issue

### Hog function logs
- See the invocation fire
- "Won lock for TypeError: ..." (CAS dedup worked)
- Session created
