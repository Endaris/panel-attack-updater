local helpers = {}

local magicCharacters = "^$().[]*+-?)"
function helpers.escapeSpecialCharacters(prefix)
    prefix = prefix:gsub("%%", "%%%")
    for i = 1, magicCharacters:len() do
      prefix = prefix:gsub("%" .. magicCharacters:sub(i, i), "%%" .. magicCharacters:sub(i, i))
    end
    return prefix
  end


return helpers