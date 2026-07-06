# Shipping VoxType 🚀

Step-by-step guide to publish VoxType: code on GitHub, DMG on GitHub Releases, website on GitHub Pages.

## 0. Prerequisites

- A GitHub account (github.com — free)
- `git` installed (comes with Xcode Command Line Tools)
- The app builds and runs on your Mac (`./build_app.sh`)

## 1. Create the GitHub repository

1. Go to https://github.com/new
2. Name: `VoxType` · Public · **don't** add a README (we have one)
3. Create the repository.

## 2. Push the code

From the VoxType folder on your Mac:

```bash
cd ~/VoxType        # wherever your copy lives

# One-time: replace psyk3-cyber placeholders with your GitHub username
sed -i '' 's/psyk3-cyber/your-github-username/g' docs/index.html README.md

git init
git add .
git commit -m "VoxType 1.0.0 — voice typing for macOS"
git branch -M main
git remote add origin https://github.com/your-github-username/VoxType.git
git push -u origin main
```

> The included `.gitignore` keeps `build/` and `.build/` out of the repo.

## 3. Build the DMG

```bash
./build_app.sh    # builds build/VoxType.app (universal if possible) with icon
./make_dmg.sh     # creates build/VoxType-1.0.0.dmg
```

## 4. Publish a Release with the DMG

1. On your repo page: **Releases → Create a new release**
2. Tag: `v1.0.0` · Title: `VoxType 1.0.0`
3. Drag `build/VoxType-1.0.0.dmg` into the assets box.
4. Paste release notes, e.g.:

   ```
   First public release 🎉
   - Push-to-talk (hold fn), hands-free (double-tap fn), Command Mode (fn+Ctrl)
   - Auto-polish: fillers removed, capitalization, "press enter" voice command
   - Custom dictionary, snippets, 14 languages, local history
   - Optional AI Auto-Edits with your own OpenAI key
   - macOS 13+, Apple Silicon & Intel

   ⚠️ Not notarized: right-click VoxType.app → Open → Open on first launch,
   or run: xattr -dr com.apple.quarantine /Applications/VoxType.app
   ```

5. **Publish release.** The site's download button already points to
   `releases/latest/download/VoxType-1.0.0.dmg`, so it works immediately.
   (If you bump the version later, update that filename in `docs/index.html`.)

## 5. Turn on the website (GitHub Pages)

1. Repo → **Settings → Pages**
2. Source: **Deploy from a branch** · Branch: `main` · Folder: **/docs**
3. Save. In ~1 minute your site is live at:
   `https://your-github-username.github.io/VoxType/`

## 6. Tell people about the Gatekeeper warning

Because the app is ad-hoc signed (not notarized), macOS shows a warning on
first launch. Users must **right-click → Open → Open** once, or run:

```bash
xattr -dr com.apple.quarantine /Applications/VoxType.app
```

This is already explained on the website and in the README.

## 7. Optional: proper notarization (removes the warning)

If VoxType takes off, enroll in the Apple Developer Program ($99/yr), then:

```bash
# Sign with your Developer ID certificate
codesign --force --deep --options runtime \
  --sign "Developer ID Application: Your Name (TEAMID)" build/VoxType.app

./make_dmg.sh

# Notarize (one-time: xcrun notarytool store-credentials)
xcrun notarytool submit build/VoxType-1.0.0.dmg \
  --keychain-profile "voxtype" --wait
xcrun stapler staple build/VoxType-1.0.0.dmg
```

Then re-upload the stapled DMG to the release. No more warnings.

## 8. Shipping updates

1. Bump `CFBundleShortVersionString` in `Info.plist`
2. `./build_app.sh && ./make_dmg.sh`
3. New release with tag `v1.x.x` + new DMG
4. Update the DMG filename in `docs/index.html`'s download button
5. `git commit && git push` (Pages redeploys automatically)

## Checklist

- [ ] Repo created and code pushed
- [ ] `psyk3-cyber` replaced in `docs/index.html` and `README.md`
- [ ] DMG built and attached to a published release
- [ ] GitHub Pages enabled (main branch, /docs folder)
- [ ] Site loads and the download button works
- [ ] Tested the DMG on a fresh Mac (or at least a fresh user account)
