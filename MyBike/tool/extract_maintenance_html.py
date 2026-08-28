"""Extract and merge maintenance data from the HTML database into JSON."""
from __future__ import annotations

import json
import pathlib
import re

HTML_SRC = pathlib.Path(
    r"c:\Users\ASUS\Downloads\india_other_complete_bike_maintenance_db.html"
)
PART1 = pathlib.Path(r"C:\Projects\MyBike\assets\data\india_bike_maintenance.json")
OUT = PART1

# Light green accent for all electric brands / EV models (matches HTML evbadge theme).
EV_BRAND_COLOR = "#81c784"


def strip_js_comments(text: str) -> str:
    # Remove // line comments (the HTML brands array uses section headers).
    return re.sub(r"//[^\n]*", "", text)


def js_object_to_json(text: str) -> str:
    text = strip_js_comments(text)
    text = re.sub(
        r"([{,]\s*)([A-Za-z_][A-Za-z0-9_]*)(\s*:)",
        r'\1"\2"\3',
        text,
    )
    text = re.sub(r",(\s*[\]}])", r"\1", text)
    return text


def extract_const_array(src: str, var_name: str) -> list:
    marker = f"const {var_name}=["
    start = src.index(marker) + len(marker) - 1
    depth = 0
    end = start
    for i, ch in enumerate(src[start:], start):
        if ch == "[":
            depth += 1
        elif ch == "]":
            depth -= 1
            if depth == 0:
                end = i + 1
                break
    block = src[start:end]
    return json.loads(js_object_to_json(block))


def extract_const_object(src: str, var_name: str) -> dict:
    marker = f"const {var_name}="
    start = src.index(marker) + len(marker)
    depth = 0
    end = start
    for i, ch in enumerate(src[start:], start):
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                end = i + 1
                break
    block = src[start:end]
    return json.loads(js_object_to_json(block))


def normalize_name(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", " ", name.lower()).strip()


def infer_chain(model: dict) -> bool:
    tasks = model.get("maintenance", [])
    if any(t.get("type") == "chain" for t in tasks):
        return True
    if model.get("cc", 0) == 0:
        return False
    bike_type = (model.get("type") or "").lower()
    if "scooter" in bike_type and "motorcycle" not in bike_type:
        return False
    return True


def to_schedule_model(raw: dict) -> dict:
    return {
        "name": raw["name"],
        "cc": raw["cc"],
        "type": raw["type"],
        "cooling": raw["cooling"],
        "chain": infer_chain(raw),
        "maintenance": raw["maintenance"],
        "notes": raw["notes"],
    }


def to_schedule_brand(raw: dict) -> dict:
    is_ev = bool(raw.get("ev", False))
    color = EV_BRAND_COLOR if is_ev else raw["color"]
    return {
        "id": raw["id"],
        "name": raw["name"],
        "origin": "India",
        "color": color,
        "isElectric": is_ev,
        "models": [to_schedule_model(m) for m in raw["models"]],
    }


def merge_models(existing: list[dict], incoming: list[dict]) -> list[dict]:
    by_key = {normalize_name(m["name"]): m for m in existing}
    for model in incoming:
        key = normalize_name(model["name"])
        if key not in by_key:
            by_key[key] = model
            continue
        # Keep richer schedule (more tasks).
        if len(model["maintenance"]) > len(by_key[key]["maintenance"]):
            by_key[key] = model
    return list(by_key.values())


def merge_brands(part1: dict, html_brands: list[dict]) -> list[dict]:
    part1_by_id = {b["id"]: b for b in part1["brands"]}
    html_by_id = {b["id"]: to_schedule_brand(b) for b in html_brands}

    merged_ids: list[str] = []
    for brand in part1["brands"]:
        merged_ids.append(brand["id"])
    for brand_id in html_by_id:
        if brand_id not in merged_ids:
            merged_ids.append(brand_id)

    result: list[dict] = []
    for brand_id in merged_ids:
        part = part1_by_id.get(brand_id)
        html = html_by_id.get(brand_id)
        if part and html:
            merged = {
                **html,
                "name": part.get("name") or html["name"],
                "color": html["color"] if html.get("isElectric") else part.get("color", html["color"]),
                "models": merge_models(part["models"], html["models"]),
            }
            result.append(merged)
        elif part:
            entry = dict(part)
            entry.setdefault("isElectric", False)
            result.append(entry)
        elif html:
            result.append(html)
    return result


def convert_priority_badge(pb: dict) -> dict:
    out = {}
    for level, style in pb.items():
        out[level] = {
            "bg": style["bg"],
            "color": style.get("c", style.get("color")),
            "label": style["l"] if "l" in style else style["label"],
        }
    return out


def main() -> None:
    html = HTML_SRC.read_text(encoding="utf-8")
    part1 = json.loads(PART1.read_text(encoding="utf-8"))

    html_brands = extract_const_array(html, "brands")
    type_colors = extract_const_object(html, "TC")
    priority_badge = convert_priority_badge(extract_const_object(html, "PB"))

    payload = {
        "brands": merge_brands(part1, html_brands),
        "typeColors": type_colors,
        "priorityBadge": priority_badge,
    }

    OUT.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )
    models = sum(len(b["models"]) for b in payload["brands"])
    ev = sum(1 for b in payload["brands"] if b.get("isElectric"))
    print(f"Wrote {OUT.name}: {len(payload['brands'])} brands ({ev} EV), {models} schedules")


if __name__ == "__main__":
    main()
