# Contributing

Use an isolated checkout for development. Preserve the installed working copy and its artwork; do not
copy older project files over a live widget. Keep the package ID stable to preserve user settings.

## Checks

Runtime: Plasma 6, its QML modules, Docker/Podman CLI; Python 3 for helpers and Docker Compose for local
Compose workflows. Development: Node.js 22+, Python 3, Qt 6 qmllint with Plasma/Kirigami/KCM imports,
AppStream CLI and zip. Python GUI fixtures additionally need PySide6 and a graphical/offscreen Qt backend.

```sh
tests/run.sh
# Optional GUI smoke suite: PySide6 and Plasma QML imports required
python3 tests/ui_runtime.py
# Only when native QML imports are unavailable; CI runs full lint separately:
DOCKMOID_SKIP_QML_LINT=1 tests/run.sh
./package-release.sh /tmp/dockmoid-release
```

The test suite uses fixtures/stubs for state-changing commands and transactional installer rollback.
It must not modify real containers. Validate real narrow/wide layouts separately; a passing lint check
is not proof of rendering or native tray activation. Test logs, inspect, settings and all four detail
levels when changing shared components. Document untested engine/version behavior accurately.

Translations use `translate/extract.sh` and `translate/build.sh`; gettext is needed for those tools.
Do not commit host configuration, credentials, generated artifacts, runtime logs or personal screenshots.
Changes to dependencies, bundled artwork or licensing must update the applicable notices.

See RELEASE_CHECKLIST.md for the reproducible public package workflow.
