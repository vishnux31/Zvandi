"""Extract maintenance database from the React JSX source into JSON."""
import json
import pathlib
import re

SRC = pathlib.Path(r"c:\Users\ASUS\Downloads\india_bike_maintenance_db.jsx")
OUT = pathlib.Path(r"C:\Projects\MyBike\assets\data\india_bike_maintenance.json")


def js_object_to_json(text: str) -> str:
    """Quote bare JS object keys so the block can be parsed as JSON."""
    text = re.sub(
        r'([{,]\s*)([A-Za-z_][A-Za-z0-9_]*)(\s*:)',
        r'\1"\2"\3',
        text,
    )
    # JS allows trailing commas; JSON does not.
    text = re.sub(r',(\s*[\]}])', r'\1', text)
    return text


def extract_object(src: str, var_name: str) -> dict:
    marker = f"const {var_name} = "
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


def main() -> None:
    src = SRC.read_text(encoding="utf-8")
    payload = extract_object(src, "data")
    payload["typeColors"] = extract_object(src, "typeColors")
    payload["priorityBadge"] = extract_object(src, "priorityBadge")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")
    models = sum(len(b["models"]) for b in payload["brands"])
    print(f"Wrote {OUT.name}: {len(payload['brands'])} brands, {models} schedules")


if __name__ == "__main__":
    main()
