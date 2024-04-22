local versionMeta = {
  __lt = function(a, b)
    if a.major ~= b.major then
      return a.major < b.major
    else
      if a.minor ~= b.minor then
        return a.minor < b.minor
      else
        if a.patch ~= b.patch then
          return a.patch < b.patch
        else
          if a.preRelease and b.preRelease then
            -- proper prerelease resolution currently unsupported
            return a.preRelease < b.preRelease
          else
            return a.preRelease ~= nil
          end
        end
      end
    end
  end,
  __eq = function(a, b)
    return a.major == b.major
       and a.minor == b.minor
       and a.patch == b.patch
       and ((a.preRelease and b.preRelease) or (not a.preRelease and not b.preRelease))
  end,
  __tostring = function(v)
    local versionString = v.major .. "." .. v.minor .. "." .. v.patch
    if v.preRelease then
      versionString = versionString .. "-" .. v.preRelease
    end
    if v.metadata then
      versionString = versionString .. "+" .. v.metadata
    end
    return versionString
  end
}


-- returns a table with separate fields according to semantic versioning:
-- expected format is major.minor.patch-prelease+metadata
local function toVersion(versionString)
  local version = {}
  setmetatable(version, versionMeta)

  local dot1Pos = versionString:find("%.")
  version.major = tonumber(versionString:sub(1, dot1Pos - 1))
  versionString = versionString:sub(dot1Pos + 1)
  local dot2Pos = versionString:find("%.")
  if not dot2Pos then
    version.minor = tonumber(versionString)
    version.patch = 0
  else
    version.minor = tonumber(versionString:sub(1, dot2Pos - 1))
    versionString = versionString:sub(dot2Pos + 1)
    if versionString:len() > 0 then
      local dashPos = versionString:find("%-")
      local plusPos = versionString:find("%+")
      if dashPos or plusPos then
        version.patch = tonumber(versionString:sub(1, math.min(dashPos or math.huge, plusPos or math.huge) - 1))
        if dashPos then
          if not plusPos then
            version.preRelease = versionString:sub(dashPos + 1)
          else
            version.preRelease = versionString:sub(dashPos + 1, plusPos - 1)
            version.metadata = versionString:sub(plusPos + 1)
          end
        end
      else
        version.patch = tonumber(versionString)
      end
    end
  end

  return version
end

local function getDefaultVersion()
  return toVersion("0.0.0-noversion")
end

local semanticVersion = { toVersion = toVersion, getDefaultVersion = getDefaultVersion}

return semanticVersion