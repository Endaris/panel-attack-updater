local lfs = love.filesystem
local json = require("updater.libs.json")
local loadReleaseStream = require("updater.releaseStream")
local logger = require("updater.logger")
local semanticVersion = require("updater.semanticVersion")

local GameUpdater = {
  path = "updater/",
  -- keys: version{url, version, releaseStream}, values: thread
  downloadThreads = {},
  releaseThreads = {},
  onDownloadedCallbacks = {},
  state = GAME_UPDATER_STATES.idle,
  version = semanticVersion.toVersion("1.0")
}

function GameUpdater:onDownloaded(version)
  for _, callback in pairs(self.onDownloadedCallbacks) do
    callback(version)
  end
end

function GameUpdater:registerCallback(func)
  self.onDownloadedCallbacks[func] = func
end

-- returns the release streams in releaseStreams.json
local function readReleaseStreamConfig()
  logger:log("Reading available release streams...")
  local releaseStreamConfig = json.decodeFile("releaseStreams.json")
  if not releaseStreamConfig then
    error("Could not read releaseStreams.json, please validate it")
  else
    logger:log("Found " .. #releaseStreamConfig.releaseStreams .. " configured release streams")

    local releaseStreams = {}
    for _, config in ipairs(releaseStreamConfig.releaseStreams) do
      releaseStreams[config.name] = loadReleaseStream(config)
      releaseStreams[config.name].config = config
    end
    return releaseStreams
  end
end

local function readLaunchConfig()
  logger:log("Reading launch configuration")
  local launchConfig = json.decodeFile("updater/launch.json")
  if not launchConfig then
    error("Could not read launch.json, please validate it")
  else
    return launchConfig.activeReleaseStream, launchConfig.activeVersion
  end
end

function GameUpdater:writeLaunchConfig(version)
  local launchJson =  '{"activeReleaseStream":"' .. version.releaseStream.name .. '"'
  launchJson = launchJson .. ', "activeVersion":"' .. version.version .. '"}'
  love.filesystem.write(self.path .. "launch.json", launchJson)
end

function GameUpdater.getLatestInstalledVersion(releaseStream)
  local latestVersion
  for _, version in pairs(releaseStream.installedVersions) do
    if not latestVersion then
      latestVersion = version
    else
      if version.version > latestVersion.version then
        latestVersion = version
      end
    end
  end
  return latestVersion
end

function GameUpdater:init()
  if not lfs.getInfo(self.path) then
    lfs.createDirectory(self.path)
  end

  if lfs.getRealDirectory(self.path .. "launch.json") ~= lfs.getSaveDirectory() then
    -- write the internal template to the save directory so it may receive updates
    local launchJson = lfs.read("updater/launch.json")
    lfs.write("updater/launch.json", launchJson)
  end

  self.releaseStreams = readReleaseStreamConfig()
  local activeReleaseStreamName, activeVersionString = readLaunchConfig()
  for name, releaseStream in pairs(self.releaseStreams) do
    local installedVersions = releaseStream:getInstalledVersions(self.path)
    releaseStream.installedVersions = installedVersions

    if name == activeReleaseStreamName then
      self.activeReleaseStream = self.releaseStreams[activeReleaseStreamName]
      if installedVersions[activeVersionString] then
        self.activeVersion = installedVersions[activeVersionString]
      elseif next(installedVersions) then
        -- default to latest version
        self.activeVersion = self.getLatestInstalledVersion(releaseStream)
      end
    end
  end

  if self.activeReleaseStream == nil then
    error("Invalid release stream " .. activeReleaseStreamName .. " in launch.json")
  end
end


function GameUpdater:downloadVersion(version)
  if not self.downloadThreads[version] then
    self.state = GAME_UPDATER_STATES.busy
    logger:log("Downloading " .. version.releaseStream.name .. " " .. version.version .. " from " .. version.url)
    local thread = love.thread.newThread("updater/downloadThread.lua")
    local directory = self.path .. version.releaseStream.name .. "/" .. tostring(version.version)
    love.filesystem.createDirectory(directory)
    version.path = directory .. "/game.love"
    thread:start(version.url, version.path)
    self.downloadThreads[version] = thread
  else
    logger:log("Client tried to download " .. version.version .. " of " .. version.releaseStream.name .. " when a download for it is still in progress")
  end
end

local function processOngoingDownloads(self)
  for version, thread in pairs(self.downloadThreads) do
    local threadError = thread:getError()
    local result = love.thread.getChannel(version.url):pop()
    if threadError or result then
      thread:release()
      self.downloadThreads[version] = nil
      if threadError then
        logger:log("Failed downloading version for " .. version.releaseStream.name)
        logger:log(threadError)
      elseif result then
        if result.success then
          logger:log("Successfully finished download of " .. version.url)
          table.insert(self.releaseStreams[version.releaseStream.name].installedVersions, version)
          self:onDownloaded(version)
        else
          logger:log("Download of " .. version.url .. " unsuccessful with status " .. result.status)
          for key, value in pairs(result.headers) do
            logger:log("Header: " .. key .. " | Value: " .. value)
          end
        end
      end
    end
  end
end

local function processOngoingAvailableVersionsFetches(self)
  for releaseStreamName, thread in pairs(self.releaseThreads) do
    logger:log("Polling results for fetching available versions of releaseStream " .. releaseStreamName)
    local threadError = thread:getError()
    local result = love.thread.getChannel(releaseStreamName):pop()
    if threadError or result then
      thread:release()
      self.releaseThreads[releaseStreamName] = nil
      if threadError then
        logger:log("Failed fetching available versions for " .. releaseStreamName)
        logger:log(threadError)
      elseif result then
        logger:log("Fetched " .. #result .. " available versions for " .. releaseStreamName)
        self.releaseStreams[releaseStreamName].availableVersions = result
        for i = 1, #result do
          result[i].releaseStream = self.releaseStreams[releaseStreamName]
        end
      end
    end
  end
end

local function processLoggingMessages(self)
  local msg = love.thread.getChannel("logging"):pop()
  while msg do
    logger:log(msg)
    msg = love.thread.getChannel("logging"):pop()
  end
end

function GameUpdater:update()
  processLoggingMessages(self)
  if self.state ~= GAME_UPDATER_STATES.idle then
    processOngoingDownloads(self)
    processOngoingAvailableVersionsFetches(self)

    if next(self.downloadThreads) == nil and next(self.releaseThreads) == nil then
      self.state = GAME_UPDATER_STATES.idle
    end
  end
end

function GameUpdater:getAvailableVersions(releaseStream)
  if not self.releaseThreads[releaseStream.name] then
    releaseStream.availableVersions = nil
    self.state = GAME_UPDATER_STATES.checkingForUpdates
    logger:log("Downloading available versions for " .. releaseStream.name)
    local thread = love.thread.newThread("updater/availableVersionsThread.lua")
    thread:start(releaseStream.config)
    self.releaseThreads[releaseStream.name] = thread
  else
    logger:log("Client tried to poll available versions for " .. releaseStream.name .. " when a download for it is still in progress")
  end
end

-- compares the releaseStream's installed versions with the availableVersions table
-- the availableVersions table needs to be populated via releaseStream:getAvailableVersions before
function GameUpdater:updateAvailable(releaseStream)
  logger:log("Checking for available updates for release stream " .. releaseStream.name)
  if not releaseStream.availableVersions or #releaseStream.availableVersions == 0 then
    logger:log("Failed to find any available versions for release stream " .. releaseStream.name)
    return false
  else
    releaseStream.installedVersions = releaseStream:getInstalledVersions(self.path)
    local latestInstalled = self.getLatestInstalledVersion(releaseStream)

    local availableVersions = releaseStream.availableVersions
    table.sort(availableVersions, function(a,b) return a.version < b.version end)
    local latestOnline = availableVersions[#availableVersions]

    if not latestInstalled then
      logger:log("No version installed yet")
      return latestOnline
    else
      logger:log("Latest installed version is " .. latestInstalled.version)
      return latestInstalled.version < latestOnline.version
    end
  end
end

function GameUpdater:launch(version)
  if self.downloadThreads[version] then
    error("Trying to launch a version that is still getting downloaded")
  end
  if not love.filesystem.mount(version.path, '') then
    error("Could not mount file " .. version.path)
  else
    self.activeVersion = version
    self:writeLaunchConfig(version)
    logger:log("Launching version " .. version.version .. " of releaseStream " .. version.releaseStream.name)
    pcall(logger.write, logger)
    love.event.restart(version.path)
  end
end

-- tries to remove the specified version from disk
-- returns true if it was found and removed
-- returns false if the version could not be found (and thus not removed)
function GameUpdater:removeInstalledVersion(version)
  if version and version.releaseStream and self.releaseStreams[version.releaseStream.name] then
    for versionString, installedVersion in pairs(version.releaseStream.installedVersions) do
      if installedVersion.version == version then
        love.filesystem.remove(installedVersion.path)
        version.releaseStream.installedVersions[versionString] = nil
        return true
      end
    end
  end

  return false
end

return GameUpdater