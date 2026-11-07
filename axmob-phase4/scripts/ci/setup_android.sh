#!/usr/bin/env bash
# Prépare le build Gradle Android : SDK (versions de la doc Godot), template Gradle, réglages éditeur,
# keystore de debug. Prérequis : JDK 17, ANDROID_HOME défini (setup-android), templates installés.
set -euo pipefail
V="${GODOT_VERSION:-4.7.2}"
: "${ANDROID_HOME:?ANDROID_HOME doit pointer vers le SDK Android}"
JAVA_HOME_PATH="${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")}"

# Versions requises (doc Godot « Exporting for Android »), à revérifier à chaque montée de version Godot.
yes | sdkmanager --licenses >/dev/null || true
sdkmanager "platform-tools" "build-tools;35.0.1" "platforms;android-35" \
  "cmdline-tools;latest" "cmake;3.10.2.4988404" "ndk;28.1.13356709" >/dev/null

# Template Gradle (équivalent de Projet > Installer le modèle de build Android)
TPL="${HOME}/.local/share/godot/export_templates/${V}.stable/android_source.zip"
mkdir -p android/build
unzip -q -o "$TPL" -d android/build
printf '%s' "${V}.stable" > android/.build_version
touch android/build/.gdignore

# Réglages éditeur (les deux noms de fichier pour couvrir -4 / -4.x)
for f in "${HOME}/.config/godot/editor_settings-4.tres" "${HOME}/.config/godot/editor_settings-${V%.*}.tres"; do
  mkdir -p "$(dirname "$f")"
  cat > "$f" <<EOT
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/java_sdk_path = "${JAVA_HOME_PATH}"
export/android/android_sdk_path = "${ANDROID_HOME}"
EOT
done

# Keystore de debug (variables documentées par Godot)
KS="${HOME}/debug.keystore"
if [ ! -f "$KS" ]; then
  keytool -genkeypair -v -keystore "$KS" -alias androiddebugkey -storepass android -keypass android \
    -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US" >/dev/null 2>&1
fi
{
  echo "GODOT_ANDROID_KEYSTORE_DEBUG_PATH=${KS}"
  echo "GODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey"
  echo "GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=android"
} >> "${GITHUB_ENV:-/dev/null}"
