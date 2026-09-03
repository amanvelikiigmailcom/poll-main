# Repository rules

- **AGENTS.md — главный файл проекта.** `CLAUDE.md` всегда смотрит на `AGENTS.md` — при каждом старте сессии сначала читай `AGENTS.md`, он источник истины по архитектуре, правилам и текущему состоянию. `CLAUDE.md` — лишь краткий чеклист.
- **Full project map for agents:** see [`AGENTS.md`](./AGENTS.md) (read that first; do not scan the whole tree).
- **Последние изменения и статус аудита:** см. [`Саморимд.md`](./Саморимд.md) — там зафиксирован Playwright-аудит кнопок/переходов от 2026-09-03 и варианты A/B/C для битых маршрутов. Сверяйся с ним перед изменениями роутера.
- After making changes in this repository, you must **commit and push** them. Work that is only committed locally and never pushed is not considered done.
- **Always run / publish locally via Google Chrome** (`cd app && flutter run -d chrome` или `flutter build web` → `build/web` → SPA на `http://localhost:8082`). Never use Xcode, iOS Simulator, or `macos` unless the user explicitly asks.
- Never commit secrets, tokens, or credentials (e.g. in `.env` files) into this repository. Use a local, git-ignored `.env` for any local secrets instead.
