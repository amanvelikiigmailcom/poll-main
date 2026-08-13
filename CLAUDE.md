# Repository rules

- **Full project map for agents:** see [`AGENTS.md`](./AGENTS.md) (read that first; do not scan the whole tree).
- After making changes in this repository, you must **commit and push** them. Work that is only committed locally and never pushed is not considered done.
- **Always run / publish locally via Google Chrome** (`cd app && flutter run -d chrome`). Never use Xcode, iOS Simulator, or `macos` unless the user explicitly asks.
- Never commit secrets, tokens, or credentials (e.g. in `.env` files) into this repository. Use a local, git-ignored `.env` for any local secrets instead.
