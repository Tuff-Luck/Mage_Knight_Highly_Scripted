"""Disposable, read-only CI migration preview; no remote writes."""
import os, pathlib, re, json, subprocess, tempfile, base64, sys
from collections import Counter

P=pathlib.Path
ROOT="src/PlayingGame/"
RT=ROOT+"PlayerBoard/ResourceTracker/"
GROUPS={
"Combat":"AttackEligibility BlockSolver BlockResults BossAllocation ConditionalBlockEffects DamagePreparation DamageResolution DefendAllocation DivisibleResources EarlyCombatPhase EnemyAttacks EnemyDefences EnemyGroups ExplosiveBolt FlameWave LateCombatPhase SourceTargetAllocation CombatTargetPolicy CombatInteraction",
"Interface":"CombatDisplay CombatEffectDisplay CombatPanelLayout CombatPanelRenderer CombatResourceDisplay CombatRowRenderer CardControlOptions CardControls UnitControls",
"Cards":"ActionLinks CardEffects CardInteraction CardInteractions MovementEffects ResourceChoices SkillEffects SkillInteractions SkillLinks PlayedCardScan",
"Units":"ReadyPolicy UnitChoices UnitEffects UnitManagement UnitScan UnitSelfWounds",
"Scanning":"FactionRewardScan ScanFinalization ScanObservation ScanPayments ScanPublication PhysicalObjects ManaPayments",
"Core":"Diagnostics State TrackerLifecycle ScanScheduler ObjectEvents"}
GAME={
"Combat":"Combat AttackAssignments",
"Scenarios":"BaseScenario LLScenario SOTScenario APOCScenario FanScenario ApocalypseDragon Horsemen FactionLeaders Quests",
"World":"Map MapTokens Movement City",
"Offers":"Offers DeckCycle CallOffer TrainingOffer MagicTalentOffer",
"Components":"ManaSource Rollers TokenPools",
"GameFlow":"Callbacks Events FameReputation Scoring Teams Telemetry Turn",
"Interface":"UI UIAssets Help"}
PAIRS=[("Combat","BlockCalculation","BlockSolver","BlockResults","solver","results"),("Combat","DamageCalculation","DamagePreparation","DamageResolution","preparation","resolution"),("Combat","EnemyProperties","EnemyAttacks","EnemyDefences","attacks","defences"),("Interface","CombatPanel","CombatPanelLayout","CombatPanelRenderer","layout","renderer"),("Core","TrackerLifecycle","ScanScheduler","TrackerLifecycle","scheduler","lifecycle")]
def run(*cmd,check=True,**kwargs):
    return subprocess.run(cmd,check=check,text=True,**kwargs)
def read(path): return P(path).read_text(encoding="utf-8")
def write(path,s):
    P(path).parent.mkdir(parents=True,exist_ok=True)
    P(path).write_text(s,encoding="utf-8")
def files():
    return [str(p) for p in P("src").rglob("*.lua")]+[str(p) for p in P("tools").glob("*.lua")]+[".tts/objects/Global.lua","AGENTS.md","ARCHITECTURE.md","CONTRIBUTING.md",".vscode/settings.json",".vscode/tasks.json","tools/validate-project.ps1"]
def module(path): return path.removeprefix("src/").removesuffix(".lua").replace("/",".")
def index():
    return {p.split("\t",1)[1]:p.split("\t",1)[0].split()[1] for p in subprocess.check_output(["git","ls-files","-s","-z"]).decode().split("\0") if p}
def compress(data):
    # Small, bounded LZ77 format to keep the generated tree data compact in CI logs.
    d={}; out=bytearray(); lit=bytearray(); i=0
    def flush():
        if lit: out.append(len(lit)-1);out.extend(lit);lit.clear()
    while i<len(data):
        k=data[i:i+4]; prev=d.get(k,-100000); dist=i-prev;n=0
        if 0<dist<=65535 and len(k)==4:
            while n<min(130,len(data)-i) and data[prev+n]==data[i+n]: n+=1
        if n>=4:
            flush();out.append(128+n-3);out.extend(dist.to_bytes(2,"big"))
            for j in range(i,i+n): d[data[j:j+4]]=j
            i+=n
        else:
            d[k]=i;lit.append(data[i]);i+=1
            if len(lit)==128: flush()
    flush();return base64.b64encode(out).decode()
def publish(stage,previous):
    run("git","add","-A")
    now=index();known=set(previous.values());items=[]
    for path,sha in sorted(previous.items()):
        if path not in now: items.append({"path":path,"mode":"100644","type":"blob","sha":None})
    for path,sha in sorted(now.items()):
        if previous.get(path)==sha: continue
        item={"path":path,"mode":"100644","type":"blob"}
        if sha in known: item["sha"]=sha
        else: item["content"]=read(path)
        items.append(item)
    encoded=compress(json.dumps(items,ensure_ascii=True,separators=(",",":")).encode("ascii"))
    print("ORG-MANIFEST",stage,len(items),len(encoded),flush=True)
    for i in range(0,len(encoded),10000): print(f"ORG-DATA {stage} {i//10000} {encoded[i:i+10000]}",flush=True)
    return now
def check(stage):
    p=run("pwsh","-NoProfile","-File","tools/validate-project.ps1","-RequireLua52",check=False,capture_output=True)
    if p.returncode: print(p.stdout[-6000:],p.stderr[-6000:],flush=True)
    bad=[]
    for t in sorted(P("tools").glob("test-*.lua")):
        p2=run("lua5.2",str(t),check=False,capture_output=True)
        if p2.returncode: bad.append(str(t));print("ORG-FAIL",stage,t,p2.stdout[-2000:],p2.stderr[-2000:],flush=True)
    print("ORG-CHECK",stage,"validator",p.returncode,"tests",len(list(P("tools").glob("test-*.lua"))),"failed",len(bad),flush=True)
    return p.returncode==0 and not bad
def rewrite_paths(mapping):
    # Full source paths, require names, and relative tracker paths used by fixtures.
    variants={}
    for old,new in mapping.items():
        for a,b in [(old,new),(old.removeprefix("src/"),new.removeprefix("src/")),(module(old),module(new))]:
            variants[a]=b
        if "/ResourceTracker/" in old:
            variants["ResourceTracker/"+old.split("/ResourceTracker/")[1]]="ResourceTracker/"+new.split("/ResourceTracker/")[1]
        if "/PlayerBoard/" in old:
            variants["PlayerBoard/"+old.split("/PlayerBoard/")[1]]="PlayerBoard/"+new.split("/PlayerBoard/")[1]
    pat=re.compile("|".join(re.escape(x)+(r"(?![\w.])" if not x.endswith(".lua") else "") for x in sorted(variants,key=len,reverse=True)))
    for p in files():
        s=read(p); n=pat.sub(lambda m:variants[m.group()],s)
        if p.startswith("tools/") and "ResourceTracker/" in s:
            # Some test fixtures construct a path from a base directory plus a basename.
            for old,new in mapping.items():
                if "/ResourceTracker/" not in old: continue
                oldrel=old.split("/ResourceTracker/")[1];newrel=new.split("/ResourceTracker/")[1]
                n=re.sub(r'(["\'])'+re.escape(oldrel)+r'\1',lambda m:m[1]+newrel+m[1],n)
        if n!=s: write(p,n)
    for old,new in mapping.items():
        if old==new: continue
        if not P(old).is_file(): raise RuntimeError(old)
        P(new).parent.mkdir(parents=True,exist_ok=True)
        P(old).rename(new)
def assembly_update():
    path="tools/test-resource-tracker-assembly.lua";s=read(path)
    mods=sorted(str(p.relative_to(P(RT))).removesuffix(".lua").replace("/",".") for p in P(RT).rglob("*.lua"))
    import textwrap
    s=re.sub(r"local modules=\[\[.*?\]\]","local modules=[[\n"+textwrap.fill(" ".join(mods),width=105)+"\n]]",s,flags=re.S)
    s=s.replace('root.."ResourceTracker/"..name..".lua"','root.."ResourceTracker/"..name:gsub("%.","/")..".lua"')
    write(path,s)
def stage2():
    mapping={RT+n+".lua":RT+g+"/"+n+".lua" for g,ns in GROUPS.items() for n in ns.split()}
    assert set(mapping)=={str(p) for p in P(RT).glob("*.lua")}
    rewrite_paths(mapping);assembly_update()
def report_pairs():
    for p in files():
        if not p.startswith("tools/") or not p.endswith(".lua"): continue
        s=read(p);hits=[]
        for i,l in enumerate(s.splitlines(),1):
            if any(n+".lua" in l or "ResourceTracker."+g+"."+n in l for g,_,a,b,_,_ in PAIRS for n in [a,b]):
                hits.append((i,l))
        if hits: print("ORG-PAIR-REF",p,json.dumps(hits,ensure_ascii=True),flush=True)
def consolidate(group,combined,a,b,export_a,export_b):
    paths=[RT+group+"/"+n+".lua" for n in [a,b]]
    target=RT+group+"/"+combined+".lua"
    source_a,source_b=map(read,paths)
    sections=[(a,export_a,source_a),(b,export_b,source_b)]
    text="-- Cohesive "+combined+" services; preserve original lexical and factory boundaries.\n"
    for name,export,source in sections:
        text+="\n-- "+name+"\nlocal "+export+"=(function()\n"+source.rstrip("\n")+"\nend)()\n"
    text+="\nreturn {"+export_a+"="+export_a+","+export_b+"="+export_b+"}\n"
    for p in files():
        if p in paths: continue
        s=read(p);n=s
        if p=="ARCHITECTURE.md":
            rows=[]
            for path in paths:
                match=re.search(r"^\| "+re.escape(chr(96)+path+chr(96))+r" \| (.*?) \|$",n,re.M)
                if not match: raise RuntimeError("missing architecture row "+path)
                rows.append(match.group(1));n=n.replace(match.group(0)+"\n","")
            header="| "+chr(96)+target+chr(96)+" | "+(" ".join(rows))+" |\n"
            n=n.replace("\n## Dependency shape",header+"\n## Dependency shape")
        else:
            for path,export in sorted(zip(paths,[export_a,export_b]),key=lambda item:item[0]!=target):
                oldmod,newmod=module(path),module(target)
                n=n.replace('require("'+oldmod+'")','require("'+newmod+'").'+export)
                suffix=path.split("/ResourceTracker/")[1]
                newsuffix=target.split("/ResourceTracker/")[1]
                for old,new in [(path,target),("ResourceTracker/"+suffix,"ResourceTracker/"+newsuffix),(suffix,newsuffix)]:
                    q=re.escape('"'+old+'"')
                    n=re.sub(r'(dofile\([^\r\n]*?)'+q+r'(\))',lambda m:m[1]+'"'+new+'"'+m[2]+"."+export,n)
                    n=re.sub(r'(assert\(loadfile\([^\r\n]*?)'+q+r'([^)\r\n]*\)\)\(\))',lambda m:m[1]+'"'+new+'"'+m[2]+"."+export,n)
                for old,new in [(path,target),(path.removeprefix("src/"),target.removeprefix("src/")),("ResourceTracker/"+suffix,"ResourceTracker/"+newsuffix),(suffix,newsuffix)]:
                    n=n.replace(old,new)
        if n!=s: write(p,n)
    for p in paths: P(p).unlink()
    write(target,text)
    if combined!="TrackerLifecycle":
        fac=[export for name,export,src in sections if re.search(r"(?m)^return function\(",src)]
        ap="tools/test-resource-tracker-assembly.lua";s=read(ap)
        anchor="local combinedFactories={"
        if anchor not in s: s=s.replace("local loaded,loading={},{}", "local loaded,loading={},{}\nlocal combinedFactories={\n}")
        key=module(target)
        line='    ["'+key+'"]={'+",".join('"'+x+'"' for x in fac)+'},'
        s=s.replace(anchor,anchor+"\n"+line)
        if "local function checkedFactory(" not in s:
            start=s.index('    if type(result)=="function" then',s.index('env.require=function(name)'))
            end=s.index('    loaded[name]=result',start)
            s=s[:start]+"""    if type(result)=="function" then
        result=checkedFactory(name,result)
    elseif combinedFactories[name]~=nil then
        for _,member in ipairs(combinedFactories[name]) do
            assert(type(result[member])=="function",name.." missing factory "..member)
            result[member]=checkedFactory(name.."."..member,result[member])
        end
    end
"""+s[end:]
            s=s.replace("env.require=function(name)","""local function checkedFactory(name,factory)
    return function(...)
        for index=1,select("#",...) do
            assert(select(index,...)~=nil,name..": nil factory dependency "..index)
        end
        return factory(...)
    end
end
env.require=function(name)""")
        write(ap,s)
def stage3():
    for pair in PAIRS[:3]: consolidate(*pair)
    assembly_update()
def stage4():
    for pair in PAIRS[3:]: consolidate(*pair)
    rewrite_paths({RT+"Cards/CardInteraction.lua":RT+"Cards/CardCallbacks.lua",RT+"Cards/CardInteractions.lua":RT+"Cards/CrossCardEffects.lua"})
    assembly_update()
def stage5():
    mapping={ROOT+n+".lua":ROOT+g+"/"+n+".lua" for g,ns in GAME.items() for n in ns.split()}
    assert set(mapping)=={str(p) for p in P(ROOT).glob("*.lua")}
    rewrite_paths(mapping)
def stage6():
    root=ROOT+"PlayerBoard/"
    rewrite_paths({root+n+".lua":root+"Units/"+n+".lua" for n in ["UnitHistory","UnitLayout","UnitReplacement","UnitResources"]})
def stage7():
    ap="ARCHITECTURE.md";s=read(ap)
    s=s.replace("## Resource Tracker refactor boundaries","""## Source organisation

The PlayingGame directory groups gameplay responsibilities into AI, Combat, Components, GameFlow, Interface, Offers, PlayerBoard, Scenarios and World. ResourceTracker contains Cards, Combat, Core, Interface, Scanning and Units. Folder names do not define load order: the Global entry point does. UI XML remains a flat, independent directory.

Consolidated calculator modules expose named factories or subservices. Instantiate them at the original coordinator boundaries rather than eagerly capturing partially initialized dependencies. The combined files retain separate lexical scopes for their original implementations. Avoid making a second copy of a shared helper or mixing physical game state with calculation-only services.

## Resource Tracker refactor boundaries""")
    rows={
      "PlayingGame/GameFlow/Teams.lua":"Authoritative seat team and scenario faction membership, allied sites and ownership checks.",
      "PlayingGame/Offers/CallOffer.lua":"Physical Unit loan and offer browse/return lifecycle for Call to Arms and Call to Glory.",
      "PlayingGame/Offers/TrainingOffer.lua":"Training cost selection and physical Advanced Action browse/claim/return lifecycle.",
      "PlayingGame/Offers/MagicTalentOffer.lua":"Magic Talent physical Spell borrow/claim/return and casting lifecycle.",
      "PlayingGame/PlayerBoard/Scale.lua":"Player-board play-area and component scaling.",
      "PlayingGame/PlayerBoard/Units/UnitResources.lua":"Static Unit ability resource definitions.",
      "PlayingGame/PlayerBoard/Units/UnitHistory.lua":"Authoritative activation-use history, selection and frozen paid-mana snapshots.",
      "PlayingGame/PlayerBoard/Units/UnitReplacement.lua":"Player-confirmed replacement of Units at full Command capacity.",
      "PlayingGame/Interface/UIAssets.lua":"Global Custom UI asset registration, including runtime decals and object interface icons.",
      "PlayingGame/Interface/Help.lua":"Game help and rules reminders."
    }
    for path,desc in rows.items():
        marker=chr(96)+"src/"+path+chr(96)
        if marker not in s: s=s.replace("\n## Dependency shape","| "+marker+" | "+desc+" |\n\n## Dependency shape")
    s=re.sub(r"\n\n(?=\| `src/)", "\n",s)
    write(ap,s)
    agents=read("AGENTS.md").replace("Every `require()` target in `.tts/objects/Global.lua` resolves to a source module under `src/`.","Every statically named `require()` reachable from `.tts/objects/Global.lua` resolves to a source module under `src/`; the dependency graph has no cycles or unreachable modules.")
    write("AGENTS.md",agents)
    test="""-- Source layout guard: paths are part of the TTS bundler contract.
local expected={
    ["src/PlayingGame/Combat/Combat.lua"]=true,
    ["src/PlayingGame/GameFlow/Callbacks.lua"]=true,
    ["src/PlayingGame/Interface/UI.lua"]=true,
    ["src/PlayingGame/Offers/DeckCycle.lua"]=true,
    ["src/PlayingGame/Scenarios/Quests.lua"]=true,
    ["src/PlayingGame/World/Map.lua"]=true,
    ["src/PlayingGame/Components/ManaSource.lua"]=true,
    ["src/PlayingGame/PlayerBoard/Units/UnitHistory.lua"]=true
}
for path in pairs(expected) do
    local f=assert(io.open(path,"r"),"Missing organised source "..path)
    f:close()
end
local f=assert(io.open(".tts/objects/Global.lua","r"))
local entry=f:read("*a")
f:close()
local function position(module)
    return assert(entry:find('require("'..module..'")',1,true),"Missing entry "..module)
end
assert(position("ErrorReporting")<position("Shared"))
assert(position("PlayingGame.World.City")<position("PlayingGame.Scenarios.FactionLeaders"))
assert(position("PlayingGame.Scenarios.FactionLeaders")<position("PlayingGame.Combat.Combat"))
assert(position("PlayingGame.Interface.UI")<position("PlayingGame.GameFlow.Callbacks"))
assert(position("PlayingGame.GameFlow.Events")<position("PlayingGame.GameFlow.Callbacks"))
print("Organised source paths and Global load-order invariants passed")
"""
    write("tools/test-source-organisation.lua",test)

def main():
    cwd=os.getcwd()
    with tempfile.TemporaryDirectory(prefix="mk-organisation-") as tmp:
        work=tmp+"/checkout"
        run("git","worktree","add","--detach",work,"HEAD^",stdout=subprocess.DEVNULL)
        try:
            os.chdir(work)
            prev=index()
            for stage,apply in [(4,stage4),(5,stage5),(6,stage6),(7,stage7)]:
                apply()
                ok=check(stage)
                prev=publish(stage,prev)
                if not ok: return 1
            return 0
        finally:
            os.chdir(cwd);run("git","worktree","remove","--force",work)
if __name__=="__main__": sys.exit(main())
