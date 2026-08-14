# GitHub Pages Docs + Tag Release Workflow

**Goal:** Add a full documentation site deployed to GitHub Pages, plus a release workflow that builds and uploads a signed release APK when tags are pushed.

**Resolved decisions:**
- Docs: Full site covering Getting Started, Architecture, Contributing, Build & Release, Troubleshooting, Changelog.
- Pages deploy: GitHub Actions (`actions/configure-pages` + `actions/upload-pages-artifact` + `actions/deploy-pages`).
- Release artifacts: APK only.
- Signing: Keystore stored as GitHub Secret (`ANDROID_KEYSTORE_BASE64`) with supporting secrets for alias/passwords.

---

## Task 1: Create documentation content

**Files to create:**
- `docs/index.md` — Landing page with project overview and quick links.
- `docs/getting-started.md` — Setup instructions (clone, env, run, verify).
- `docs/architecture.md` — Layer overview (core, features, data/presentation), state management, routing, networking.
- `docs/contributing.md` — Branch naming, commit conventions, pre-commit checklist, PR process.
- `docs/build-and-release.md` — Build commands, signing setup, release checklist, how to create a tag.
- `docs/troubleshooting.md` — Common issues (pub get, emulator, OAuth, build failures).
- `docs/changelog.md` — Versioned changelog (seed with v1.3.0 notes from README).

**Style:** Markdown with front-matter (`title`, `nav_order`) compatible with MkDocs Material.

---

## Task 2: Add MkDocs site configuration

**Files to create:**
- `mkdocs.yml` — Site config using Material theme, nav structure matching `docs/` files, `site_url` placeholder.
- `docs/requirements.txt` — Python deps (`mkdocs`, `mkdocs-material`).

**Validation:** `mkdocs build` should produce a static site without errors.

---

## Task 3: Create GitHub Pages workflow

**File to create:** `.github/workflows/pages.yml`

**Behavior:**
- Trigger: push to `main`.
- Steps:
  1. Checkout code.
  2. Set up Python 3.x.
  3. Install MkDocs deps (`pip install -r docs/requirements.txt`).
  4. Build site (`mkdocs build`).
  5. Configure Pages (`actions/configure-pages@v4`).
  6. Upload artifact (`actions/upload-pages-artifact@v3` with `path: site`).
  7. Deploy (`actions/deploy-pages@v4`).

**Repo setting required:** Pages source must be set to **GitHub Actions** in repo settings.

---

## Task 4: Create release workflow

**File to create:** `.github/workflows/release.yml`

**Behavior:**
- Trigger: push of a tag matching `v*` (e.g., `v1.3.0`).
- Permissions: `contents: write` (to upload release assets).
- Steps:
  1. Checkout code.
  2. Set up Java 17 (Android Gradle requires it).
  3. Set up Flutter (`subosito/flutter-action@v2` or equivalent).
  4. Decode keystore from secret `ANDROID_KEYSTORE_BASE64` to `android/app/upload-keystore.jks`.
  5. Create `android/key.properties` from secrets:
     - `ANDROID_KEYSTORE_PATH=android/app/upload-keystore.jks`
     - `ANDROID_KEY_ALIAS`
     - `ANDROID_KEY_PASSWORD`
     - `ANDROID_STORE_PASSWORD`
  6. Modify `android/app/build.gradle.kts` at build time to use `upload-keystore.jks` for release signing (inject via environment or patch file before build). **Preferred:** patch `build.gradle.kts` in the workflow to read `key.properties` for release signing.
  7. Run `flutter pub get`.
  8. Run `flutter build apk --release`.
  9. Upload APK artifact to GitHub Releases (`softprops/action-gh-release@v1` or `actions/upload-release-asset@v2`).
  10. Upload APK as workflow artifact for manual download.

**Signing secrets required in GitHub repo settings:**
- `ANDROID_KEYSTORE_BASE64` — base64-encoded JKS keystore.
- `ANDROID_KEY_ALIAS` — key alias string.
- `ANDROID_KEY_PASSWORD` — key password.
- `ANDROID_STORE_PASSWORD` — keystore password.

**Build command:** `flutter build apk --release` outputs to `build/app/outputs/flutter-apk/app-release.apk`.

---

## Task 5: Update build.gradle.kts for release signing

**File to modify:** `android/app/build.gradle.kts`

**Change:** Replace the debug signing config in `release` build type with logic that loads `key.properties` if present, otherwise keeps debug signing. This allows local `flutter run --release` to still work while CI uses the real keystore.

```kotlin
release {
    signingConfig = if (file("key.properties").exists()) {
        val props = java.util.Properties()
        file("key.properties").inputStream().use { props.load(it) }
        signingConfigs.register("release").apply {
            storeFile = file(Props["storeFile"] as String)
            storePassword = props["storePassword"] as String
            keyAlias = props["keyAlias"] as String
            keyPassword = props["keyPassword"] as String
        }
    } else {
        signingConfigs.getByName("debug")
    }
}
```

---

## Task 6: Validation

1. **Docs build:** Run `mkdocs build` locally (or in a test workflow run) and confirm `site/` directory is generated.
2. **Release dry-run:** Verify `flutter build apk --release` works locally after signing config changes.
3. **Static analysis:** `dart format .` and `flutter analyze` pass.
4. **Tests:** `flutter test` passes.

---

## Execution order

1. Task 1 (docs content) → Task 2 (mkdocs config) → Task 3 (pages workflow) → Task 5 (signing config) → Task 4 (release workflow) → Task 6 (validation).

---

## Risks / notes

- **Keystore generation:** User must generate a release keystore locally and base64-encode it before adding the GitHub Secret.
- **Pages source:** User must manually set Pages source to **GitHub Actions** in repo Settings → Pages.
- **Tag naming:** Workflow triggers on `v*` tags. Advise user to use `git tag v1.3.1 && git push origin v1.3.1`.
- **Flutter version:** CI uses a Flutter action with a pinned version; ensure it matches the project's SDK constraint (`^3.13.0-282.1.beta`).
