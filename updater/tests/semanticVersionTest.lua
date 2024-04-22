local semanticVersion = require("updater.semanticVersion")

local function t1()
  local default = semanticVersion.getDefaultVersion()
  local v001 = semanticVersion.toVersion("0.0.1")
  local v100pre = semanticVersion.toVersion("1.0.0-alpha")
  local v100 = semanticVersion.toVersion("1.0.0")
  local v200 = semanticVersion.toVersion("2.0.0")
  local v210 = semanticVersion.toVersion("2.1.0")
  local v211 = semanticVersion.toVersion("2.1.1")

  assert(default < v001)
  assert(v001 < v100pre)
  assert(v100pre < v100)
  assert(v100 < v200)
  assert(v200 < v210)
  assert(v210 < v211)
end

local function t2()
  local short1 = semanticVersion.toVersion("1.0")
  local long1 = semanticVersion.toVersion("1.0.0")

  assert(short1 == long1)
end

local function t3()
  local short1 = semanticVersion.toVersion("1.0-alpha")
  local long1 = semanticVersion.toVersion("1.0.0-alpha")

  -- this distinction is not implemented yet as versions without a patch number don't have their prerelease loaded
  assert (short1 == long1)
end

t1()
t2()
-- t3()