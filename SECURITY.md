# Security and privacy

Dockmoid executes configured commands as the logged-in user. Docker socket access may grant broad host
control. Customized command presets, Compose files and registry content are trust boundaries; review
what you run. Read-only mode disables Dockmoid mutation controls but is not an operating-system sandbox.

No telemetry service is configured. Engine commands contact the selected engine; registry searches,
image pulls and optional update checks contact external registries. Browser links and metadata links
open external destinations, and metadata links have not necessarily been independently verified.

Report a suspected security issue through GitHub private vulnerability reporting if that repository
feature is available. Otherwise contact the maintainer address in metadata.json before sharing exploit
or credential details publicly. Never put tokens, passwords, environment dumps, private diagnostics or
unredacted inspect output in a public issue. Ordinary reproducible UI bugs can use GitHub Issues.

This is a locally maintained project without a guaranteed response window. Update to the latest source
or release before reporting; only the current release is maintained.
