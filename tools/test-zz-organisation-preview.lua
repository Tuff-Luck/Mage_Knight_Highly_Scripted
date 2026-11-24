local ok=os.execute("python3 tools/organisation-preview.py")
assert(ok,"Organisation preview failed; inspect ORG-CHECK and ORG-FAIL")
