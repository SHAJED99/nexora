# Release signing — what the human provides, and how to verify it

> **Status of this document.** The build wiring described here is in place
> (`android/app/build.gradle.kts`, `E00-B01`). The keystore it reads **does not
> exist and was not created by any agent.** Generating a release signing key is
> a `secrets_or_env_change` human gate (`harness.yaml`, AGENTS.md rule 3), and
> a signing key invented by tooling is worthless — it is the one artifact that
> cannot be regenerated later without orphaning every install.

## Why this exists

Before `E00-B01`, `android/app/build.gradle.kts` carried Flutter's scaffold
default:

```kotlin
release {
    // TODO: Add your own signing config for the release build.
    signingConfig = signingConfigs.getByName("debug")
}
```

That is not a style problem. Verified on `fa85bd7`, 2026-09-24:

```
$ flutter build apk --release
√ Built build\app\outputs\flutter-apk\app-release.apk (62.5MB)

$ apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
Signer #1 certificate DN: C=US, O=Android, CN=Android Debug
```

An APK signed with the Android debug key **cannot be uploaded to Google Play**,
and cannot be updated by a differently-signed build later — users would have to
uninstall and lose all local data, which for this app means their device
identity, their Signal sessions and their entire message history
(ADR-0001, ADR-0005). The signing key is therefore a one-way decision, which is
exactly why it is the human's.

## What the build does now

`android/app/build.gradle.kts` reads `android/key.properties` if it exists:

| `key.properties` present | Release signing | Distributable |
|---|---|---|
| no | debug key (fallback) | **no** — development only |
| yes | the named keystore | yes, once the cert is verified |

The fallback is deliberate: CI has no keystore and needs none, so
`flutter build apk --debug`, `flutter build apk --release` and
`flutter run --release` all keep working on a fresh clone with no setup.

`android/key.properties` and `**/*.jks` / `**/*.keystore` are already
git-ignored (`android/.gitignore:12-14`, `.gitignore:57`). Nothing in this
procedure is ever committed.

## Steps (human)

### 1. Generate the keystore

Run this yourself, off the repository tree. Choose the password; do not reuse
one. Keep the answers to the prompts — they become the certificate subject and
cannot be changed afterwards.

```bash
keytool -genkey -v \
  -keystore ~/nexora-upload-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias nexora-upload
```

`-validity 10000` (≈27 years) is the Android/Flutter documented
*recommendation*. Play's actual stated requirement is narrower — the key must
stay valid until at least **22 October 2033** — and 10000 days satisfies it
comfortably. Either way a key that expires strands the app.

### 2. Back it up, in two places, before step 3

Losing this file is unrecoverable. If Play App Signing is enabled you can reset
an *upload* key through Play Console support; if it is not, a lost key ends the
app's update path permanently. Decide which of those you are in before you
ship — that decision is also yours, and it belongs in an ADR if it is not
already covered.

### 3. Write `android/key.properties`

Create the file at `android/key.properties` (not in `android/app/`):

```properties
storePassword=<the store password from step 1>
keyPassword=<the key password from step 1>
keyAlias=nexora-upload
storeFile=<absolute path to nexora-upload-key.jks>
```

`storeFile` is resolved relative to `android/` if it is a relative path, so an
absolute path outside the repo is the safer choice.

### 4. Verify — do not skip this

Building is not evidence that the build was signed correctly.

```bash
flutter build apk --release
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

The certificate DN must be **yours**. If it still reads
`C=US, O=Android, CN=Android Debug`, `key.properties` was not picked up —
check the path and that the file is at `android/key.properties`.

There is deliberately no "did it sign?" shortcut in the build script. The
build succeeds on both paths, so only the artifact can answer the question,
and `apksigner` is what reads the artifact.

`apksigner` ships with the Android SDK build-tools, e.g.
`$ANDROID_HOME/build-tools/<version>/apksigner`.

### 5. For Play, build the bundle rather than the APK

```bash
flutter build appbundle --release
```

Play requires an `.aab`. The APK path above stays useful for sideloading and
for the walking-skeleton smoke check on real hardware.

**Verified working on `82b803d`, 2026-09-24** — this path had never been
exercised before, so it is recorded rather than assumed:

```
Running Gradle task 'bundleRelease'...                             67.5s
√ Built buildpp\outputsundleeleasepp-release.aab (60.8MB)   [exit 0]
```

The bundle builds clean. Like the APK, it is signed with whatever the release
`signingConfig` resolves to — so today, with no `key.properties`, it carries
the debug certificate and **cannot be uploaded**. Step 4's `apksigner` check
applies to the `.aab` too; run it before any upload attempt.

## What is NOT covered here

- **Play Console setup, the store listing, the privacy policy and the
  data-safety declaration.** None exist. For an app that requests Bluetooth
  scanning, background location and runs its own E2E crypto, the data-safety
  form is not a formality and its review latency is outside anyone's control.
- **CI release signing.** The CI workflow builds `--debug` only and has no
  secret store wired. Signing in CI would mean putting the keystore into
  repository secrets — another `secrets_or_env_change` decision, and one worth
  making deliberately rather than by drift.
- **Key rotation and Play App Signing enrolment.** See step 2.
