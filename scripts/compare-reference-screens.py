"""Compare exported native screenshots without stretching reference collages.

Usage: python compare-reference-screens.py REFERENCE.png ACTUAL.png ACTUAL.json OUTPUT
No synthetic render or new golden snapshot is produced. Metadata from the native
checkpoint is required; the report does not claim a numerical similarity score.
"""
import argparse
import json
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw


def normalized(image, width):
    height = round(image.height * width / image.width)
    return image.convert("RGB").resize((width, height), Image.Resampling.LANCZOS)


def compare(reference, actual, metadata, output):
    reference, actual, metadata, output = map(Path, (reference, actual, metadata, output))
    config = json.loads(metadata.read_text(encoding="utf-8"))
    if not config.get("source", "").startswith("Production SwiftUI views"):
        raise ValueError("Native screenshot metadata is required, not mockup metadata.")
    width, height = int(config["widthPoints"]), int(config["heightPoints"])
    if not 300 <= width <= 500 or not 500 <= height <= 1100:
        raise ValueError("Unexpected native iPhone dimensions.")
    with Image.open(reference) as source, Image.open(actual) as rendered:
        if abs(rendered.width / rendered.height - width / height) > 0.003:
            raise ValueError("Native PNG and reported point dimensions do not agree.")
        left, right = normalized(source, width), normalized(rendered, width)
        source_size, actual_size = source.size, rendered.size
    # Same content width, independent proportional heights: never squash one
    # image into the other's rectangle to manufacture a better match.
    canvas_height = max(left.height, right.height)
    left_canvas = Image.new("RGB", (width, canvas_height), "#E4E9E8")
    right_canvas = left_canvas.copy()
    left_canvas.paste(left, (0, 0)); right_canvas.paste(right, (0, 0))
    output.mkdir(parents=True, exist_ok=False)
    sheet = Image.new("RGB", (width * 2 + 24, canvas_height + 32), "white")
    draw = ImageDraw.Draw(sheet)
    draw.text((8, 8), "REFERENCE (collage)", fill="black")
    draw.text((width + 32, 8), "ACTUAL (native simulator)", fill="black")
    sheet.paste(left_canvas, (0, 32)); sheet.paste(right_canvas, (width + 24, 32))
    sheet.save(output / "side-by-side.png")
    Image.blend(left_canvas, right_canvas, 0.5).save(output / "overlay.png")
    ImageChops.difference(left_canvas, right_canvas).save(output / "difference.png")
    report = {"reference": str(reference.resolve()), "actual": str(actual.resolve()),
              "metadata": config, "originalSizes": [source_size, actual_size],
              "normalizedSizes": [left.size, right.size], "resampling": "uniform width; aspect preserved",
              "visualAcceptance": "NOT REVIEWED", "pixelSimilarity": "NOT SCORED",
              "note": "Collage proportions, native safe areas and missing original assets require explicit human review. Gray padding is not app UI."}
    (output / "comparison.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("reference", "actual", "metadata", "output"):
        parser.add_argument(name)
    compare(**vars(parser.parse_args()))
