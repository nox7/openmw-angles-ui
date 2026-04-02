local TextUtility = {}

-- Per-character pixel width estimates at the 16px baseline text size.
-- Values are scaled proportionally when a different textSize is used.
local CHAR_WIDTH_UPPERCASE = 12  -- A-Z
local CHAR_WIDTH_LOWERCASE = 8   -- a-z (general)
local CHAR_WIDTH_NARROW    = 5   -- 't' and 'l'
local CHAR_WIDTH_SPACE     = 9   -- space character
local CHAR_WIDTH_FALLBACK  = 8   -- digits, punctuation, and any other character

local DEFAULT_TEXT_SIZE = 16

-- Estimates the rendered pixel width of a string at the given text size.
-- When textSize is nil or 0 the 16px baseline widths are used as-is.
function TextUtility.EstimateTextWidth(text, textSize)
  if (text == nil or text == "") then
    return 0
  end

  local scale = (textSize ~= nil and textSize > 0) and (textSize / DEFAULT_TEXT_SIZE) or 1
  local width = 0

  for i = 1, #text do
    local c = string.sub(text, i, i)
    local charWidth

    if (c == " ") then
      charWidth = CHAR_WIDTH_SPACE
    elseif (c == "t" or c == "l") then
      charWidth = CHAR_WIDTH_NARROW
    elseif (c >= "a" and c <= "z") then
      charWidth = CHAR_WIDTH_LOWERCASE
    elseif (c >= "A" and c <= "Z") then
      charWidth = CHAR_WIDTH_UPPERCASE
    else
      charWidth = CHAR_WIDTH_FALLBACK
    end

    width = width + charWidth
  end

  return width * scale
end

return TextUtility
