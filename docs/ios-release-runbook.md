# iOS release runbook

Эта процедура не разрешает новую native/cloud сборку, TestFlight upload или submit.
Нужна явная актуальная команда владельца на соответствующий пакет. Старые разрешения
из history не действуют постоянно; подтверждённый пакет повторно не согласовывать.
Backend runtime и client build — разные стадии: [backend reference](backend-reference.md).

## До сборки

1. Прочитать AGENTS.md и Git status. Сохранить чужие изменения; release source должен
   соответствовать проверенному commit. Не включать посторонний draft автоматически.
2. Запустить полный `python3 scripts/checks.py` из корня poll-main. При изменении общего
   game/API contract проверить также backend suite. Fake tests не заменяют device QA.
3. Версию брать из `app/pubspec.yaml`, зависимости — из `app/pubspec.lock` и
   `app/ios/Podfile.lock`. Проверить Flutter pin в `app/ios/ci_scripts/ci_post_clone.sh`;
   не обновлять SDK/Pods как побочный эффект сборки. Проверить соответствие Pods Manifest.
4. Для разрешённого нового upload сверить доступные builds в App Store Connect;
   source version не доказывает доступность build. Номер не выбирать по старой истории.
5. Проверить release config, API URL и наличие Superwall key без вывода значения.
   Локальный ключ может быть skip-worktree: placeholder в Git не доказывает отсутствие
   ключа на машине. Не перезаписывать локальный ключ при checkout/merge.
6. Credentials загружать только внутри авторизованного процесса. `.env`, JWT, `.p8`
   и cookie не печатать, не коммитить и не копировать в runbook.

## Сборка и доставка согласованного пакета

1. Открывать `app/ios/Runner.xcworkspace`, scheme `Runner`, не `.xcodeproj`.
2. Выбрать согласованный native или Xcode Cloud путь. Source push сам по себе
   не означает upload и не разрешает незапланированную cloud сборку.
3. При native пути: dependency preparation, Archive, затем export IPA. Проверить
   bundle/version/build, entitlements и подпись экспортированного IPA перед upload.
   При сбое Flutter export диагностировать Archive и Xcode export options;
   ручной `xcodebuild -exportArchive` допускается только внутри разрешённого пакета.
   Не пересоздавать сертификаты/profiles и не менять signing team вслепую.
4. Upload и processing — отдельные стадии. После processing read-back проверить
   build и его доступность нужным TestFlight testers. Submit — отдельное разрешение.
5. Device checklist: Firebase SMS, Contacts permission/local labels, session switches,
   round submit/retry/balance, campus gate, APNs и Sandbox purchase/restore/expiry.
   Невыполненные пункты явно отметить; provider acceptance не доказывает доставку.
6. Server compatibility flags менять только отдельным согласованным rollout после
   подтверждения совместимости установленного клиента. Статус — в backend runtime-status.

При разрешённом push сохранять `[ci skip]`, если cloud build не согласован отдельно;
force-push запрещён. В отчёте отдельно: source готов / committed / pushed / deployed /
build available / device tested. История прошлых процедур — в
[архиве](history/agents-before-cleanup-2026-11-24.md), это не актуальные разрешения.
