"""Crop the user-selected collages into review references, never app backgrounds."""
import argparse
import json
from pathlib import Path

from PIL import Image


def prepare(onboarding: Path, application: Path, output: Path) -> None:
    output.mkdir(parents=True, exist_ok=True)
    records = []
    # Bounds exclude the device frames and captions. Scale from the supplied
    # collage coordinates, retaining each screen's aspect ratio.
    definitions = [
        (onboarding, (1448, 1086), [28, 269, 510, 749, 990, 1230], [20, 400, 772], 187, 334,
         [f"R{i:02}" for i in range(1, 19)]),
        (application, (1168, 1346), [14, 314, 609, 900], [17, 726], 270, 640,
         ["A01", "A02", "A06", "A19", "A22", "A08", "A24", "A25"]),
    ]
    for source, original, xs, ys, width, height, ids in definitions:
        with Image.open(source) as collage:
            scale_x, scale_y = collage.width / original[0], collage.height / original[1]
            for screen_id, (x, y) in zip(ids, ((x, y) for y in ys for x in xs)):
                bounds = tuple(round(value) for value in
                               (x * scale_x, y * scale_y, min(x + width, original[0]) * scale_x,
                                min(y + height, original[1] - 36) * scale_y))
                cropped = collage.crop(bounds).convert("RGB")
                cropped.save(output / f"{screen_id}.png")
                records.append({"screen": screen_id, "source": source.name, "crop": bounds,
                                "size": cropped.size, "kind": "reference_not_implementation"})
    (output / "manifest.json").write_text(json.dumps(records, indent=2), encoding="utf-8")
    print(f"Prepared {len(records)} reference screens in {output}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("onboarding", type=Path)
    parser.add_argument("application", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    prepare(args.onboarding, args.application, args.output)
