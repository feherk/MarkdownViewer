#!/usr/bin/env python3
"""Generate .DS_Store on a mounted DMG volume with background image alias."""
import sys
from ds_store import DSStore, DSStoreEntry
from mac_alias import Alias

if len(sys.argv) < 2:
    print("Usage: gen-ds-store.py /Volumes/VolumeName")
    sys.exit(1)

vol = sys.argv[1]
bg_path = vol + "/.background/bg.png"

# Create alias for background image (must exist on the mounted volume)
alias = Alias.for_file(bg_path)
alias_bytes = alias.to_bytes()

# Build icvp plist with background image
icvp = {
    "backgroundType": 2,
    "backgroundColorRed": 1.0,
    "backgroundColorGreen": 1.0,
    "backgroundColorBlue": 1.0,
    "backgroundImageAlias": alias_bytes,
    "gridOffsetX": 0.0,
    "gridOffsetY": 0.0,
    "gridSpacing": 100.0,
    "iconSize": 100.0,
    "textSize": 13.0,
    "showIconPreview": True,
    "showItemInfo": False,
    "labelOnBottom": True,
    "arrangeBy": "none",
    "viewOptionsVersion": 1,
}

# Write DS_Store
ds_path = vol + "/.DS_Store"
with DSStore.open(ds_path, "w+") as d:
    d["."]["icvp"] = icvp
    d["MarkdownViewer.app"]["Iloc"] = (150, 185)
    d["Applications"]["Iloc"] = (450, 185)
    d.insert(DSStoreEntry(".", "vSrn", "long", 1))

print(f"Generated {ds_path}")
