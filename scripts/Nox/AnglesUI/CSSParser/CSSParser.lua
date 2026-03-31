local CSSParser = {}
CSSParser.__index = CSSParser

function CSSParser.New()
  local self = setmetatable({}, CSSParser)
  return self
end

function CSSParser:Parse(cssSource)
  if (cssSource == nil or cssSource == "") then
    return {}
  end

  return {
    rules = {},
    mediaQueries = {},
    raw = cssSource,
  }
end

return CSSParser
