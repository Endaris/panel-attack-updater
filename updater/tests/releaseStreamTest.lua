local loadReleaseStream = require("updater.releaseStream")
local json = require("updater.libs.json")
local https = require("https")

local function t1()
  local fileconfig = json.decodeFile("updater/tests/testData/fileConfig.json")
  local releaseStream = loadReleaseStream(fileconfig)
  assert(releaseStream.name == "stable")
  assert(releaseStream.versionProcessor.getDefaultVersion() == 0)
  local availableVersions = releaseStream:getAvailableVersions()
  assert(availableVersions and type(availableVersions) == "table")
  if #availableVersions > 0 then
    assert(tonumber(availableVersions[1].version))
    -- we got something implies the connection is working
    -- just verify the url actually points to an existing resource
    local status, body, headers = https.request(availableVersions[1].url, {method = "HEAD", headers = {["user-agent"] = love.filesystem.getIdentity()}})
    assert(body and tonumber(status))
  end
end

local function t2()
  local githubConfig = json.decodeFile("updater/tests/testData/githubConfig.json")
  local releaseStream = loadReleaseStream(githubConfig)
  assert(releaseStream.name == "sceneRefactor")
  local defaultVersion = releaseStream.versionProcessor.getDefaultVersion()
  assert(tostring(defaultVersion) == "0.0.0-noversion")
  local availableVersions = releaseStream:getAvailableVersions()
  assert(availableVersions and type(availableVersions) == "table")
  if #availableVersions > 0 then
    assert(availableVersions[1].version ~= defaultVersion)
    -- we got something implies the connection is working
    -- just verify the url actually points to an existing resource
    local status, body, headers = https.request(availableVersions[1].url, {method = "HEAD", headers = {["user-agent"] = love.filesystem.getIdentity()}})
    assert(body and tonumber(status))
  end
end

t1()
t2()