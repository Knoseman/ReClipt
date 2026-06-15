# Installing ReClipt From GitHub Releases

ReClipt is currently distributed as a self-signed macOS app through GitHub
Releases. macOS will not treat it like a notarized App Store or Developer ID
app, but it can still be installed and used.

## Download

1. Open the latest GitHub Release:
   `https://github.com/Knoseman/ReClipt/releases/latest`
2. Download both files:
   - `ReClipt-macOS.zip`
   - `ReClipt-macOS.zip.sha256`

## Verify the Download

From Terminal:

```sh
cd ~/Downloads
shasum -a 256 -c ReClipt-macOS.zip.sha256
```

Expected result:

```text
ReClipt-macOS.zip: OK
```

If the checksum fails, delete the zip and download it again.

## Install

1. Unzip `ReClipt-macOS.zip`.
2. Drag `ReClipt.app` into `/Applications`.
3. Control-click or right-click `/Applications/ReClipt.app`.
4. Choose `Open`.
5. Confirm that you want to open it.

If macOS still blocks the app, remove the quarantine flag:

```sh
xattr -dr com.apple.quarantine /Applications/ReClipt.app
```

Then open ReClipt again.

## First Launch

ReClipt is a menu bar app. It should not appear in the Dock. Use the menu bar
icon or configured shortcuts to open ReClipt.

On first launch, macOS may ask for Accessibility permission. ReClipt needs that permission to paste clips and snippets into other apps.

To enable it manually:

1. Open `System Settings`.
2. Go to `Privacy & Security`.
3. Open `Accessibility`.
4. Enable `ReClipt`.
5. Quit and reopen ReClipt.

## Troubleshooting

If paste does not work, confirm that the copy of ReClipt in `/Applications` is enabled under Accessibility. If an older ReClipt entry exists there, remove it, add the current app again, then quit and reopen ReClipt.

If nothing appears in the Dock, that is expected. Use the menu bar icon or configured shortcuts.

If the app says it is damaged or cannot be opened, remove the quarantine flag with the `xattr` command above.

If copied Finder files appear in history, ReClipt should show useful file names.
If you only see generic file labels after updating, quit and reopen the
installed `/Applications/ReClipt.app`.
