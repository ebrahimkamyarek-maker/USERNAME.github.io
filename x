name: Make assetlinks
on:
  workflow_dispatch:
permissions:
  contents: write
jobs:
  links:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build assetlinks.json
        run: |
          set -e
          BT=$(ls -d "$ANDROID_HOME"/build-tools/* | sort -V | tail -n 1)
          APK=$(find . -maxdepth 1 -name '*.apk' | head -n 1)
          if [ -z "$APK" ]; then echo "No APK in repo root"; exit 1; fi
          if [ ! -f release.keystore ]; then echo "release.keystore not found"; exit 1; fi
          KS_PASS=$(grep -m1 'KS_PASS:' .github/workflows/sign.yml | awk '{print $2}')
          PKG=$("$BT/aapt2" dump badging "$APK" | sed -n "s/^package: name='\([^']*\)'.*/\1/p")
          FP=$(keytool -list -v -keystore release.keystore -alias hydraulic -storepass "$KS_PASS" | grep -m1 'SHA256:' | awk '{print $2}')
          if [ -z "$PKG" ] || [ -z "$FP" ]; then echo "Could not read package name or fingerprint"; exit 1; fi
          printf '[{\n  "relation": ["delegate_permission/common.handle_all_urls"],\n  "target": {\n    "namespace": "android_app",\n    "package_name": "%s",\n    "sha256_cert_fingerprints": ["%s"]\n  }\n}]\n' "$PKG" "$FP" > assetlinks.json
          cat assetlinks.json
      - name: Save file
        run: |
          git config user.name github-actions
          git config user.email actions@github.com
          git add assetlinks.json
          git diff --cached --quiet || (git commit -m "Add assetlinks" && git push)
