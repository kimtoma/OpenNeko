# Packaging script vendor files

This directory vendors small MIT-licensed Python modules used only by
`scripts/package-macos.sh` to write Finder `.DS_Store` metadata for the DMG
installer window without depending on Finder automation or network installs.

- `ds_store` 1.3.3
- `mac_alias` 2.2.3

Keep the matching license files in this directory when updating these modules.
