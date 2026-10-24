# Dockmoid 2.4.0 release checklist

Prepared 15 October 2026. This repository is release preparation; it does not imply a GitHub Release or
KDE Store submission has already been published. See docs/STORE_LISTING.md for the paste-ready listing
and docs/RELEASE_NOTES.md for release notes.

## Completed local preparation

- [x] Version 2.4.0 in package metadata, AppStream release and release documentation.
- [x] Current user guide, feature/compatibility limitations, contribution and security guidance.
- [x] README with adaptive shieldcn badges and locally bundled heading/license artwork.
- [x] Bundled artwork preserved with applicable license notices and historical attribution.
- [x] Existing package ID retained; runtime/source archive builders exclude workspace, credentials and caches.
- [x] Isolated regressions for parsing, engine capabilities, command correlation, cleanup defaults, Compose behavior and installer rollback.
- [x] QML checked with native Qt/Plasma imports; production-view narrow/wide runtime checks.
- [x] Screenshots in docs/assets regenerated from the UI harness for the current UI; regenerate
      them if the UI changes again before release.
- [x] Native tray opening checked in a running Plasma session.

## Build and validate the exact release candidate

```sh
tests/run.sh
./package-release.sh /tmp/dockmoid-release
cd /tmp/dockmoid-release
sha256sum -c SHA256SUMS
unzip -t dockmoid-2.4.0.plasmoid
unzip -t dockmoid-2.4.0-source.zip
```

The .plasmoid archive contains runtime contents, metadata and legal notices. The source archive also
contains docs, tests, translation tooling and release scripts. The legacy packaging/release.py
builds a runtime package from packaging/manifest.json; package-release.sh is the documented release-pair
builder. Python helper files must be included by both.

Install into an isolated Plasma 6 account or isolated XDG_DATA_HOME and verify metadata/package loading.
Record exact Qt/Plasma versions. Lint/fixture success does not prove every native interaction on every
supported engine. Test mutation workflows only on disposable services with disposable data.

## Publish separately

- [ ] Create the GitHub Release for v2.4.0 after reviewing the committed tree and checks.
- [ ] Attach .plasmoid, source ZIP and SHA256SUMS from that tree, with docs/RELEASE_NOTES.md.
- [ ] Submit the package and demo screenshots using docs/STORE_LISTING.md in the KDE Store form.
- [ ] Check the live Store download installs, then add its assigned URL to README.md.

Do not include engine credentials, inspect dumps, environment exports, personal screenshots or scratch
files in either upload. State-changing repair/cleanup/deploy tests against personal services are not a
prerequisite and have not been run. No measured before/after memory-saving claim is made.
