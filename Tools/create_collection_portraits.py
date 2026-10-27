#!/usr/bin/env python3
"""Create private Collection_* imagesets from the existing AR card reference art.

Run at the root of the DeckSpawn repository:
    python3 Tools/create_collection_portraits.py

The generated *.imageset directories are ignored by .gitignore.
It copies images instead of moving them, preserving the AR reference group.
"""

import json
import shutil
from pathlib import Path

BASE = Path(__file__).resolve().parent.parent
ASSET_CATALOG = BASE / "Resources" / "Assets.xcassets"
AR_GROUP = ASSET_CATALOG / "AR Resources.arresourcegroup"
CARDS = (
    "spiderman_cardgame",
    "stormtrooper_cardgame",
    "goku_cardgame",
    "mrsincredible_cardgame",
)


def main() -> None:
    if not AR_GROUP.is_dir():
        print(f"AR Resource Group não encontrado: {AR_GROUP}")
        return

    references = {path.stem.lower(): path for path in AR_GROUP.rglob("*.arreferenceimage")}
    for card_name in CARDS:
        reference = references.get(card_name.lower())
        if reference is None:
            print(f"[IGNORADO] Referência não localizada: {card_name}")
            continue

        try:
            metadata = json.loads((reference / "Contents.json").read_text(encoding="utf-8"))
            image_file = next(
                item.get("filename")
                for item in metadata.get("images", [])
                if item.get("filename")
            )
        except (OSError, ValueError, StopIteration) as error:
            print(f"[IGNORADO] Arquivo de imagem não identificado ({card_name}): {error}")
            continue

        source = reference / image_file
        if not source.is_file():
            print(f"[IGNORADO] Arquivo não encontrado: {source}")
            continue

        output = ASSET_CATALOG / f"Collection_{card_name}.imageset"
        output.mkdir(exist_ok=True)
        dest_name = f"portrait{source.suffix.lower()}"
        shutil.copy2(source, output / dest_name)
        info = {
            "images": [{"filename": dest_name, "idiom": "universal"}],
            "info": {"author": "xcode", "version": 1},
        }
        (output / "Contents.json").write_text(
            json.dumps(info, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
        print(f"[OK] {output.name} (não será enviado ao GitHub)")


if __name__ == "__main__":
    main()
