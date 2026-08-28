import json
from pathlib import Path

d = json.loads(Path(r"C:\Projects\MyBike\assets\data\india_bike_maintenance.json").read_text(encoding="utf-8"))
for b in d["brands"]:
    print(f"{b['id']}: {len(b['models'])} models, ev={b.get('isElectric', False)}, color={b['color']}")
