# Backend: источники истины

Backend — отдельный репозиторий `flyprox_backend`. В текущем workspace он находится
в `/Users/amanyessen/projects/flyprox_backend`; Flutter checkout —
`/Users/amanyessen/NEW/poll-main`. В другом workspace использовать корень того же
backend repository, а не создавать копию его схемы в клиенте.

- [Действующие backend правила](/Users/amanyessen/projects/flyprox_backend/AGENTS.md).
- [Единственный production-статус](/Users/amanyessen/projects/flyprox_backend/docs/runtime-status.md):
  дата проверки, фактический running commit, ExecStart, flags и evidence.
- [Машинный контракт БД](/Users/amanyessen/projects/flyprox_backend/src/database-schema.js).
- [Генерируемый справочник таблиц](/Users/amanyessen/projects/flyprox_backend/docs/database-schema.md).
- [Миграции](/Users/amanyessen/projects/flyprox_backend/schema/migrations/README.md).
- [Контракт раунда](/Users/amanyessen/projects/flyprox_backend/docs/round-submission.md).
- [Contacts, subscription и retention](/Users/amanyessen/projects/flyprox_backend/docs/contacts-subscriptions-retention.md).
- [Процедура backend deploy](/Users/amanyessen/projects/flyprox_backend/docs/deployment.md).

Эти абсолютные ссылки служат навигацией в локальном workspace. Перенос workspace
требует поправить ссылки, а не дублировать содержимое. Dated release notes/PLAN.md
хранят историю; текущие live значения обновляются только в backend runtime-status.
Backend/API/table change обновляет контракт, миграцию при изменении БД, generated docs
и тесты в backend commit; клиентские изменения — в соответствующем client commit.
Связанные commits указывать вместе, поскольку у двух репозиториев нет общего commit.
