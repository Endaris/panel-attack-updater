local helpers = require "updater.helpers"


local function toVersion(versionString, prefix)
  if prefix then
    versionString = versionString:gsub(helpers.escapeSpecialCharacters(prefix), "")
  end

  if tonumber(versionString) then
    return tonumber(versionString)
  else
    -- assuming format yyyy-MM-dd_hh-mm-ss
    local dateTime = {}
    dateTime.year = versionString:sub(1, 4)
    dateTime.month = versionString:sub(6, 7)
    dateTime.day = versionString:sub(9, 10)
    if versionString:sub(12, 13) then
      dateTime.hour = versionString:sub(12, 13)
      dateTime.min = versionString:sub(15, 16)
      dateTime.sec = versionString:sub(18, 19)
    end
    return os.time(dateTime)
  end
end

local function getDefaultVersion()
  return 0
end

local timestampVersion = { toVersion = toVersion, getDefaultVersion = getDefaultVersion}

return timestampVersion