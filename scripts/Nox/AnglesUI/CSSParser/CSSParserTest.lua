package.path = package.path .. ";./?.lua"

local CSSParser = dofile("scripts/Nox/AnglesUI/CSSParser/CSSParser.lua")

local css = [[
#outer-flex {
  gap: 10;
  flex-direction: row;
}

#outer-flex {
  & > mw-widget {
    flex-grow: 1;
    height: 100%;
  }
}

@media (max-width: 1200px) {
  #outer-flex {
    flex-direction: column;
    width: 100%;
    height: 500;
  }
}
]]

local result = CSSParser.New():Parse(css)
print("rules: " .. #result.rules)
print("mediaQueries: " .. #result.mediaQueries)
for i, rule in ipairs(result.rules) do
  print("  rule " .. i .. ": selectors=" .. table.concat(rule.selectors, ", "))
  for k, v in pairs(rule.declarations) do
    print("    " .. k .. " = " .. v)
  end
end
if result.mediaQueries[1] then
  print("media[1] rules: " .. #result.mediaQueries[1].rules)
end
print("PASS")
