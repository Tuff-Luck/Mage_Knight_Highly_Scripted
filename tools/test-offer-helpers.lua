-- Regression tests for production-shared Call Offer and Training helpers.
-- Run from repository root: lua5.2 tools/test-offer-helpers.lua
local zones={
    present={getObjects=function() return {{guid="a11111"},{guid="b22222"}} end},
    empty={getObjects=function() return {} end}
}
getObjectFromGUID=function(guid) return zones[guid] end
dofile("tools/load-offer-helpers.lua")
assert(objectGUIDInZone("a11111","present"),"present GUID should match")
assert(not objectGUIDInZone("missing","present"),"missing GUID should not match")
assert(not objectGUIDInZone("a11111","empty"),"empty zone should not match")
assert(not objectGUIDInZone("a11111",nil),"nil zone should not match")
local fromVector=ttsVectorArray({x=1,y=2,z=3})
local fromArray=ttsVectorArray({4,5,6})
assert(table.concat(fromVector,",")=="1,2,3","Vector coordinates")
assert(table.concat(fromArray,",")=="4,5,6","Array coordinates")

dofile("src/PlayingGame/UIAssets.lua")
local writes=0
local xml={
    {tag="Button",attributes={id="CallOfferControl_a11111_previous"}},
    {tag="Button",attributes={id="ResourceCardChoice_a11111_1"}},
    {tag="Button",attributes={id="AttackAssignmentSource_a11111_1"}},
    {tag="Button",attributes={id="OtherControl"}}
}
local ui={
    getXmlTable=function() return xml end,
    setXmlTable=function(nextXml)
        assert(#nextXml>0,"empty Object UI must use setXml")
        writes=writes+1
        xml=nextXml
    end,
    setXml=function(value)
        assert(value=="","Object UI should clear with empty string")
        writes=writes+1
        xml={}
    end
}
local obj={UI=ui}
assert(resourceObjectUiRemovePrefixes(obj,{"CallOfferControl_"}),"matching prefix should remove")
assert(#xml==3 and xml[1].attributes.id=="ResourceCardChoice_a11111_1","other controls preserved")
assert(writes==1,"one write for matching prefix")
assert(not resourceObjectUiRemovePrefixes(obj,{"CallOfferControl_"}),"no-op prefix should not rewrite")
assert(writes==1,"unchanged UI should not be rewritten")
assert(resourceObjectUiRemovePrefixes(obj,{"ResourceCardChoice_","AttackAssignmentSource_"}),"resources removed")
assert(#xml==1 and xml[1].attributes.id=="OtherControl","unrelated control remains")
assert(resourceObjectUiRemovePrefixes(obj,{"OtherControl"}),"last control removed")
assert(#xml==0 and writes==3,"last control cleared through setXml")
print("Shared Offer helper regressions passed")
