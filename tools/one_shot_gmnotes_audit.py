import json, re, pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
json_path = ROOT / "JSON" / "Mage Knight Highly Scripted.json"
src_root = ROOT / "src"
out_path = ROOT / "tools" / "gmnotes_audit.json"

LANG_RE = re.compile(r"\{([a-z]{2}(?:-[a-z]{2})?)\}", re.I)

def english(value):
    if not isinstance(value, str):
        return ""
    if "{en}" not in value:
        return value
    m = re.search(r"\{en\}(.*?)(?=\{[a-z]{2}(?:-[a-z]{2})?\}|$)", value, re.I | re.S)
    return m.group(1) if m else value

with json_path.open("r", encoding="utf-8") as f:
    root = json.load(f)

# Collect direct string literals compared with getName()/getDescription().
source = "\n".join(p.read_text(encoding="utf-8") for p in src_root.rglob("*.lua"))
name_literals = sorted(set(re.findall(r'getName\s*\(\s*\)\s*[~=]=\s*"([^"]+)"', source) +
                           re.findall(r'"([^"]+)"\s*[~=]=\s*[^\n]*getName\s*\(\s*\)', source)))
desc_literals = sorted(set(re.findall(r'getDescription\s*\(\s*\)\s*[~=]=\s*"([^"]+)"', source) +
                           re.findall(r'"([^"]+)"\s*[~=]=\s*[^\n]*getDescription\s*\(\s*\)', source)))

objects=[]

def walk(x, path=""):
    if isinstance(x, dict):
        if "GUID" in x:
            nick=x.get("Nickname","")
            desc=x.get("Description","")
            gm=x.get("GMNotes","")
            tooltip=x.get("Tooltip", True)
            en_nick=english(nick)
            en_desc=english(desc)
            translated_nick=isinstance(nick,str) and "{en}" in nick
            translated_desc=isinstance(desc,str) and "{en}" in desc
            name_hit=en_nick in name_literals
            desc_hit=en_desc in desc_literals
            dynamic_name_hit=(en_nick=="Shield" or en_nick=="Mana Dice" or en_nick.endswith(" Mana") or en_nick.endswith(" Potion") or en_nick.endswith(" Shard") or en_nick in {"GraveYard","Secret Tomb","Secret Dungeon"})
            dynamic_desc_hit=en_desc in {"Red","Blue","Green","White","Neutral","Quest"}
            if tooltip is False or name_hit or desc_hit or dynamic_name_hit or dynamic_desc_hit:
                objects.append({
                    "guid":x.get("GUID"),
                    "path":path,
                    "tooltip":tooltip,
                    "nickname":nick,
                    "english_nickname":en_nick,
                    "description":desc,
                    "english_description":en_desc,
                    "gmnotes":gm,
                    "translated_nickname":translated_nick,
                    "translated_description":translated_desc,
                    "name_literal_hit":name_hit,
                    "description_literal_hit":desc_hit,
                    "dynamic_name_hit":dynamic_name_hit,
                    "dynamic_description_hit":dynamic_desc_hit,
                })
        for k,v in x.items():
            walk(v, f"{path}.{k}" if path else k)
    elif isinstance(x, list):
        for i,v in enumerate(x):
            walk(v, f"{path}[{i}]")

walk(root)

summary={
    "total_objects_considered":len(objects),
    "tooltip_false":sum(1 for o in objects if o["tooltip"] is False),
    "translated_nickname":sum(1 for o in objects if o["translated_nickname"]),
    "translated_description":sum(1 for o in objects if o["translated_description"]),
    "script_name_candidates":sum(1 for o in objects if o["name_literal_hit"] or o["dynamic_name_hit"]),
    "script_description_candidates":sum(1 for o in objects if o["description_literal_hit"] or o["dynamic_description_hit"]),
    "candidate_with_blank_gmnotes":sum(1 for o in objects if (o["name_literal_hit"] or o["dynamic_name_hit"] or o["description_literal_hit"] or o["dynamic_description_hit"]) and not o["gmnotes"]),
}


from collections import defaultdict
name_groups=defaultdict(lambda: {"count":0,"tooltip_false":0,"translated":0,"blank_gmnotes":0,"gmnotes":set(),"guids":[]})
desc_groups=defaultdict(lambda: {"count":0,"tooltip_false":0,"translated":0,"blank_gmnotes":0,"gmnotes":set(),"guids":[]})
for o in objects:
    if o["name_literal_hit"] or o["dynamic_name_hit"]:
        g=name_groups[o["english_nickname"]]
        g["count"]+=1
        g["tooltip_false"]+=1 if o["tooltip"] is False else 0
        g["translated"]+=1 if o["translated_nickname"] else 0
        g["blank_gmnotes"]+=1 if not o["gmnotes"] else 0
        if o["gmnotes"]: g["gmnotes"].add(o["gmnotes"])
        if len(g["guids"])<20: g["guids"].append(o["guid"])
    if o["description_literal_hit"] or o["dynamic_description_hit"]:
        g=desc_groups[o["english_description"]]
        g["count"]+=1
        g["tooltip_false"]+=1 if o["tooltip"] is False else 0
        g["translated"]+=1 if o["translated_description"] else 0
        g["blank_gmnotes"]+=1 if not o["gmnotes"] else 0
        if o["gmnotes"]: g["gmnotes"].add(o["gmnotes"])
        if len(g["guids"])<20: g["guids"].append(o["guid"])
def clean_groups(groups):
    return {k:{**v,"gmnotes":sorted(v["gmnotes"])} for k,v in sorted(groups.items())}

out={"summary":summary,"name_literals":name_literals,"description_literals":desc_literals,"name_groups":clean_groups(name_groups),"description_groups":clean_groups(desc_groups),"objects":objects}
out_path.write_text(json.dumps(out,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print(json.dumps(summary,indent=2))
