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
# Every page, with screenshots: DOCKMOID_UI_PAGES=1 DOCKMOID_UI_CAPTURE_DIR=/tmp/shots python3 tests/ui_runtime.py
# The README screenshots (copy them into docs/assets): DOCKMOID_UI_SHOWCASE=/tmp/showcase python3 tests/ui_runtime.py
# Large inspect/log output stays fast and correct (synthetic data)
python3 tests/ui_heavy_output.py
# Only when native QML imports are unavailable; run full lint before a release:
DOCKMOID_SKIP_QML_LINT=1 tests/run.sh
./package-release.sh /tmp/dockmoid-release
```

The test suite uses fixtures/stubs for state-changing commands and transactional installer rollback.
It must not modify real containers. Validate real narrow/wide layouts separately; a passing lint check
is not proof of rendering or native tray activation. Test logs, inspect, settings and all four detail
levels when changing shared components. Document untested engine/version behavior accurately.

Where the rules live: container actions in `contents/lib/actions.js`, status and health wording keys
in `contents/lib/status.js`, the inspector layout in `contents/lib/inspectorLayout.js`, and the page
list for navigation and Go to in `contents/lib/pages.js`; each has Node tests. The backend
(`contents/ui/backend/DockerBackend.qml`) owns engine reads; image update checks, deployment, Doctor
and multi-select live in their own controllers beside it. Prefer adding a rule to one of these
modules, with a test, over adding logic to a view.

Translations use `translate/extract.sh` and `translate/build.sh`; gettext is needed for those tools.
Do not commit host configuration, credentials, generated artifacts, runtime logs or personal screenshots.
Changes to dependencies, bundled artwork or licensing must update the applicable notices.

See RELEASE_CHECKLIST.md for the reproducible public package workflow.
