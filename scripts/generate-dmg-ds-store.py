#!/usr/bin/env python3
"""Create the Finder metadata used by the openNeko DMG installer window."""

from __future__ import annotations

import argparse
import os
import struct
import sys

VENDOR_DIR = os.path.join(os.path.dirname(__file__), "vendor")
sys.path.insert(0, VENDOR_DIR)

from ds_store import DSStore  # noqa: E402
from mac_alias import Alias  # noqa: E402


def parse_position(value: str) -> tuple[int, int]:
    parts = value.split(",", 1)
    if len(parts) != 2:
        raise argparse.ArgumentTypeError("position must be formatted as x,y")
    try:
        return int(parts[0]), int(parts[1])
    except ValueError as error:
        raise argparse.ArgumentTypeError("position coordinates must be integers") from error


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--volume", required=True, help="mounted DMG volume path")
    parser.add_argument("--background", required=True, help="background image name inside .background")
    parser.add_argument("--window-width", type=int, required=True)
    parser.add_argument("--window-height", type=int, required=True)
    parser.add_argument("--window-left", type=int, default=120)
    parser.add_argument("--window-top", type=int, default=120)
    parser.add_argument("--icon-size", type=int, required=True)
    parser.add_argument("--app-name", required=True)
    parser.add_argument("--app-position", type=parse_position, required=True)
    parser.add_argument("--applications-position", type=parse_position, required=True)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    volume = os.path.abspath(args.volume)
    ds_store_path = os.path.join(volume, ".DS_Store")
    background_path = os.path.join(volume, ".background", args.background)

    if not os.path.isdir(volume):
        raise FileNotFoundError(f"mounted DMG volume not found: {volume}")
    if not os.path.isfile(background_path):
        raise FileNotFoundError(f"DMG background not found: {background_path}")

    window_right = args.window_left + args.window_width
    window_bottom = args.window_top + args.window_height
    bounds_string = f"{{{{{args.window_left}, {args.window_top}}}, {{{args.window_width}, {args.window_height}}}}}"

    bwsp = {
        "ShowStatusBar": False,
        "WindowBounds": bounds_string,
        "ContainerShowSidebar": False,
        "PreviewPaneVisibility": False,
        "SidebarWidth": 0,
        "ShowTabView": False,
        "ShowToolbar": False,
        "ShowPathbar": False,
        "ShowSidebar": False,
    }

    icvp = {
        "viewOptionsVersion": 1,
        "backgroundType": 2,
        "backgroundImageAlias": Alias.for_file(background_path).to_bytes(),
        "gridOffsetX": 0.0,
        "gridOffsetY": 0.0,
        "gridSpacing": 100.0,
        "arrangeBy": "none",
        "showIconPreview": True,
        "showItemInfo": False,
        "labelOnBottom": True,
        "textSize": 13.0,
        "iconSize": float(args.icon_size),
        "scrollPositionX": 0.0,
        "scrollPositionY": 0.0,
    }
    background_alias = Alias.for_file(background_path).to_bytes()
    old_icon_flags = bytes([0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 0, 1])

    with DSStore.open(ds_store_path, "w+") as store:
        store["."]["vSrn"] = ("long", 1)
        store["."]["vstl"] = (b"type", "icnv")
        store["."]["bwsp"] = bwsp
        store["."]["icvp"] = icvp
        store["."]["icvl"] = (b"type", "icnv")
        store["."]["fwi0"] = (
            "blob",
            struct.pack(
                ">hhhh4sI",
                args.window_top,
                args.window_left,
                window_bottom,
                window_right,
                b"icnv",
                0x00010000,
            ),
        )
        store["."]["fwvh"] = ("shor", args.window_height)
        store["."]["fwsw"] = ("long", 0)
        store["."]["ICVO"] = ("bool", True)
        store["."]["icvt"] = ("shor", 13)
        store["."]["icvo"] = (
            "blob",
            struct.pack(">4sH4s4s12s", b"icv4", args.icon_size, b"none", b"botm", old_icon_flags),
        )
        store["."]["pict"] = ("blob", background_alias)
        store["."]["BKGD"] = ("blob", struct.pack(">4sII", b"PctB", len(background_alias), 0))
        store[args.app_name]["Iloc"] = args.app_position
        store["Applications"]["Iloc"] = args.applications_position

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
