import json, re, pathlib
ROOT=pathlib.Path(__file__).resolve().parents[1]
path=ROOT/"JSON"/"Mage Knight Highly Scripted.json"
summary_path=ROOT/"tools"/"gmnotes_fix_summary.json"

def english(value):
    if not isinstance(value,str): return ""
    if "{en}" not in value: return value
    m=re.search(r"\{en\}(.*?)(?=\{[a-z]{2}(?:-[a-z]{2})?\}|$)",value,re.I|re.S)
    return m.group(1) if m else value

MANA_NAMES={
    "Red Mana":"Red","Blue Mana":"Blue","Green Mana":"Green",
    "White Mana":"White","Gold Mana":"Gold","Black Mana":"Black",
}
IDENTITY_NAMES={
    "Blue Defender Bonus Reminder","Green Defender Bonus Reminder",
    "Red Defender Bonus Reminder","White Defender Bonus Reminder",
    "Blue Potion","Green Potion","Red Potion","White Potion",
    "Blue Shard","Green Shard","Red Shard","White Shard",
    "GraveYard","Hidden Valley","Mana Dice","MapTile","Necropolis",
    "Secret Dungeon","Secret Tomb","Volkare","Volkare's Camp",
}

with path.open("r",encoding="utf-8") as f:
    root=json.load(f)

changes=[]
def walk(x,where=""):
    if isinstance(x,dict):
        if "GUID" in x:
            gm=x.get("GMNotes","")
            if not gm:
                nick=english(x.get("Nickname",""))
                desc=english(x.get("Description",""))
                new=None
                reason=None
                if nick in MANA_NAMES:
                    new=MANA_NAMES[nick]; reason="mana color"
                elif nick=="Shield" and desc:
                    new="Shield|"+desc; reason="shield identity/owner"
                elif desc=="Quest":
                    new="Quest"; reason="quest identity"
                elif nick in IDENTITY_NAMES:
                    new=nick; reason="script nickname identity"
                if new:
                    x["GMNotes"]=new
                    changes.append({"guid":x.get("GUID"),"gmnotes":new,"reason":reason,"tooltip":x.get("Tooltip",True),"english_nickname":nick,"english_description":desc,"path":where})
        for k,v in x.items():
            walk(v,f"{where}.{k}" if where else k)
    elif isinstance(x,list):
        for i,v in enumerate(x): walk(v,f"{where}[{i}]")
walk(root)

with path.open("w",encoding="utf-8",newline="") as f:
    json.dump(root,f,ensure_ascii=False,separators=(",",":"))
summary={
    "changed":len(changes),
    "by_reason":{},
    "changes":changes,
}
for c in changes:
    summary["by_reason"][c["reason"]]=summary["by_reason"].get(c["reason"],0)+1
summary_path.write_text(json.dumps(summary,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print(json.dumps({"changed":summary["changed"],"by_reason":summary["by_reason"]},indent=2))
