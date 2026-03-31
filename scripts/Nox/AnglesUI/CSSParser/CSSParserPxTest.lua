package.path = package.path .. ";./?.lua"

local CSSParser = dofile("scripts/Nox/AnglesUI/CSSParser/CSSParser.lua")

local css = [[
.box {
  gap: 10px;
  width: 100px;
  height: 50%;
  padding: 10px 20px;
  grid-template-columns: 100px 1fr;
}
]]

local result = CSSParser.New():Parse(css)
local d = result.rules[1].declarations

assert(d["gap"] == "10",                        "gap px strip failed: " .. tostring(d["gap"]))
assert(d["width"] == "100",                     "width px strip failed: " .. tostring(d["width"]))
assert(d["height"] == "50%",                    "height percent unchanged: " .. tostring(d["height"]))
assert(d["padding"] == "10 20",                 "padding px strip failed: " .. tostring(d["padding"]))
assert(d["grid-template-columns"] == "100 1fr", "grid px strip failed: " .. tostring(d["grid-template-columns"]))

print("px strip tests PASS")
