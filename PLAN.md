# Flyprox — оставшиеся задачи

Обновлено: 2026-11-24. Здесь только незавершённая работа; завершённые этапы и история сборок убраны.
Ниже нет команды на сборку, включение функций или деплой.

## Отложено

- [ ] Приглашения и wait passes: возобновить rollout отдельной задачей; код подготовлен, production rollout на паузе. Контракт и процедура: [invitations-release.md](docs/invitations-release.md).
- [ ] Отдельно определить и реализовать два shuffle/два skip за раунд и квоты раскрытия входящих голосов. Текущий Full Reveal показывает собственные ответы; контракт новых раскрытий пока не определён. Контекст: [notifications-and-activity.md](docs/notifications-and-activity.md).
- [ ] Meilisearch: отложенный переход; условия поиска закреплены в [AGENTS.md](AGENTS.md).

## Проверки и выпуск

У этих пунктов нет подтверждения завершения в проверенной документации; они не означают, что код ещё нужно написать.

- Приёмка на реальных iPhone: SMS, Contacts, два аккаунта/голос/push, purchase/restore и удаление аккаунта — [device checklist](app/test/device/README.md); native Mail — [onboarding-schools.md](docs/onboarding-schools.md).
- Перед публичным релизом: актуальные Privacy/App Privacy, screenshots и Review Notes — [privacy checklist](docs/app-privacy-checklist-1.0.2.md) и [review notes](docs/app-review-notes-1.0.2.md). Проверить ограничение Firebase iOS API key по Bundle ID; старый план не подтверждает выполнение.
- Определить порядок регулярного разбора пользовательских жалоб — [social-release.md](docs/social-release.md).

## Где смотреть состояние

- [Production status](../../projects/flyprox_backend/docs/runtime-status.md) — единственный датированный снимок production, включая активные и выключенные функции.
- [AGENTS.md](AGENTS.md) — действующие правила и команды проверок.
- [Архив прежнего плана](docs/history/plan-before-cleanup-2026-11-24.md) — история выполненных работ, сборок и исходные подробности отложенных предложений; не текущая очередь.
