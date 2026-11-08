#!/usr/bin/env python3
"""Türkiye il/ilçe listesini Resources/locations.json dosyasına yazar.

Sunucu hız sınırı uyguladığı için istekler aralıklı gönderilir; 429 yanıtında
Retry-After kadar beklenir. Yarıda kalırsa ilerleme dosyasından devam eder.
"""
import json, pathlib, re, time, urllib.error, urllib.request

BASE = "https://ezanvakti.emushaf.net"
ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "Resources" / "locations.json"
PROGRESS = ROOT / ".build" / "locations-progress.json"
# Wikidata ve OpenStreetMap'ten derlenmiş ilçe koordinatları: {ilçe kodu: [enlem, boylam]}
COORDS = json.loads((ROOT / "scripts" / "district-coordinates.json").read_text())
DELAY = 3.0
MAX_WAITS = 5

# Kaynaktaki yazım hataları: Türkçe karakter eksikleri ve ayrı yazılmış resmî adlar.
CORRECTIONS = {
    "19 MAYIS": "ONDOKUZMAYIS",
    "ARNAVUTKOY": "ARNAVUTKÖY",
    "BALISEYH": "BALIŞEYH",
    "BÜYÜK ORHAN": "BÜYÜKORHAN",
    "CELEBI": "ÇELEBİ",
    "CERKEŞ": "ÇERKEŞ",
    "CEŞME": "ÇEŞME",
    "CICEKDAGI": "ÇİÇEKDAĞI",
    "CUBUK": "ÇUBUK",
    "ÇELTİKCİ": "ÇELTİKÇİ",
    "DARGECİT": "DARGEÇİT",
    "DELICE": "DELİCE",
    "DEMIRKOY": "DEMİRKÖY",
    "DOĞUBEYAZIT": "DOĞUBAYAZIT",
    "ESME": "EŞME",
    "KARAISALI": "KARAİSALI",
    "KARAKECILI": "KARAKEÇİLİ",
    "KİGI": "KİĞI",
    "LULEBURGAZ": "LÜLEBURGAZ",
    "M.EREĞLİSİ": "MARMARAEREĞLİSİ",
    "MUSTAFA KEMALPAŞA": "MUSTAFAKEMALPAŞA",
    "PEHLIVANKOY": "PEHLİVANKÖY",
    "PINARHISAR": "PINARHİSAR",
    "SEFERIHİSAR": "SEFERİHİSAR",
    "SUHUT": "ŞUHUT",
    "SÜTCÜLER": "SÜTÇÜLER",
    "ŞARKİ KARAAĞAÇ": "ŞARKİKARAAĞAÇ",
    "VIZE": "VİZE",
    "YENİSAR BADEMLİ": "YENİŞARBADEMLİ",
}

def clean_name(raw):
    # "KEMER (B)" gibi kaynak kodları il menüsünde gereksizdir.
    name = re.sub(r"\s*\(\w\)$", "", raw)
    return CORRECTIONS.get(name, name)

def get(path):
    for attempt in range(MAX_WAITS):
        req = urllib.request.Request(BASE + path, headers={"User-Agent": "EzanVakti/1.0"})
        try:
            with urllib.request.urlopen(req, timeout=20) as r:
                return json.load(r)
        except urllib.error.HTTPError as e:
            if e.code != 429:
                raise
            wait = int(e.headers.get("Retry-After") or 60 * (attempt + 1))
            print(f"429: {wait} sn bekleniyor ({path})", flush=True)
            time.sleep(wait)
    raise SystemExit(f"Hız sınırı aşılamadı: {path}")

PROGRESS.parent.mkdir(exist_ok=True)
done = json.loads(PROGRESS.read_text(encoding="utf-8")) if PROGRESS.exists() else {}

cities = get("/sehirler/2")
time.sleep(DELAY)
for s in cities:
    if s["SehirID"] in done:
        continue
    done[s["SehirID"]] = [
        {"name": d["IlceAdi"], "id": d["IlceID"]} for d in get(f"/ilceler/{s['SehirID']}")
    ]
    PROGRESS.write_text(json.dumps(done, ensure_ascii=False), encoding="utf-8")
    print(f"{len(done)}/{len(cities)} {s['SehirAdi']}", flush=True)
    time.sleep(DELAY)

provinces = [
    {
        "name": s["SehirAdi"],
        "districts": [
            {"name": clean_name(d["name"]), "id": d["id"], "lat": COORDS[d["id"]][0], "lon": COORDS[d["id"]][1]}
            for d in done[s["SehirID"]]
        ],
    }
    for s in cities
]
assert len(provinces) == 81, len(provinces)
assert all(p["districts"] for p in provinces)
for p in provinces:
    names = [d["name"] for d in p["districts"]]
    assert len(names) == len(set(names)), p["name"]
OUT.write_text(json.dumps(provinces, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
print(len(provinces), "il,", sum(len(p["districts"]) for p in provinces), "ilçe")
