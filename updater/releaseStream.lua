local https = require("https")
local versioning = require("updater.versioning")
local json = require("updater.libs.json")
local logger = require("updater.logger")
local helpers = require("updater.helpers")
local github = {}

-- returns the last 10 releases for the repository
-- expects repository as "user/repository"
-- prefix is optional
function github.getAvailableVersions(versionProcessor, repository, prefix)
  local versions = {}
  local url = "https://api.github.com/repos/" .. repository .. "/releases?per_page=10&page=1"
  local status, body, headers = https.request(url, {method = "GET", headers = { ["user-agent"] = love.filesystem.getIdentity()}})

  if body and status == 200 then
    local response = json.decode(body)
    if response then
      for _, release in ipairs(response) do
        -- for simplicity's sake, let's assume we're only interested in the first archive of a release
        if release.assets and release.assets[1] then
          local version = {
            -- and version is running via the tag_name field, not actual asset file name
            version = versionProcessor.toVersion(release.tag_name, prefix),
            url = release.assets[1].browser_download_url,
          }
          versions[#versions + 1] = version
        end
      end
    end
  end

  return versions
end

local filesystem = {}

function filesystem.getAvailableVersions(versionProcessor, url, prefix)
  local versions = {}
  local escapedPrefix = helpers.escapeSpecialCharacters(prefix)

  local status, body, headers = https.request(url, {method = "GET", headers = { ["user-agent"] = love.filesystem.getIdentity()}})

  if body and status == 200 then
    local patternMatch = 'href="' .. escapedPrefix .. '[^%s%.]+.love'
    for w in body:gmatch(patternMatch) do
      local version = {}
      local versionString = w:gsub(".love", ""):gsub('href="', "")
      version.version = versionProcessor.toVersion(versionString, prefix)
      version.url = url .. versionString .. ".love"

      versions[#versions + 1] = version
    end
    -- else
    -- couldn't retrieve the desired data for whatever reason
    -- returning an empty version list is fine, can always try again later
  end

  return versions
end

local lfs = love.filesystem

local function getInstalledVersions(releaseStream, path)
  logger:log("Reading locally installed versions for release stream " .. releaseStream.name)
  local installedVersions = {}
  if not lfs.getInfo(path .. releaseStream.name, "directory") then
    lfs.createDirectory(path ..releaseStream.name)
  else
    -- the expectation is to have one directory per version, identified by the version name and then the mountable zip/love file inside that folder
    local versions = lfs.getDirectoryItems(path .. releaseStream.name)
    for _, versionString in ipairs(versions) do
      local file = path .. releaseStream.name .. "/" .. versionString
      if lfs.getInfo(file, "directory") then
        local files = lfs.getDirectoryItems(file)
        if #files == 1 then
          local reverse = files[1]:reverse()
          if reverse:sub(1, 4) == "piz." or reverse:sub(1, 5) == "evol." then
            local version = releaseStream.versionProcessor.toVersion(versionString)
            installedVersions[versionString] = {
              releaseStream = releaseStream,
              version = version,
              path = file .. "/" .. files[1]
            }
            logger:log("Found local version " .. version)
          end
        end
      end
    end
  end
  return installedVersions
end

local function loadReleaseStream(config)
  local releaseStream = {}
  releaseStream.name = config.name
  releaseStream.versionProcessor = versioning.getVersionProcessor(config.versioningType)
  if config.serverEndPoint.type == "github" then
    releaseStream.getAvailableVersions = function(self)
      return github.getAvailableVersions(self.versionProcessor, config.serverEndPoint.repository, config.serverEndPoint.prefix)
    end
  elseif config.serverEndPoint.type == "filesystem" then
    releaseStream.getAvailableVersions = function(self)
      return filesystem.getAvailableVersions(self.versionProcessor, config.serverEndPoint.url, config.serverEndPoint.prefix)
    end
  end

  releaseStream.getInstalledVersions = getInstalledVersions

  return releaseStream
end

return loadReleaseStream