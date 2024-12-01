require("updater.macCompatibility")
local lfs = love.filesystem
local json = require("updater.libs.json")
local loadReleaseStream = require("updater.releaseStream")
local logger = require("updater.logger")
local semanticVersion = require("updater.semanticVersion")
require("love.thread")

local GameUpdater = {
  path = "updater/",
  -- keys: version{url, version, releaseStream}, values: thread
  downloadThreads = {},
  releaseThreads = {},
  onDownloadedCallbacks = {},
  state = GAME_UPDATER_STATES.idle,
  version = semanticVersion.toVersion("1.2")
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
    return releaseStreams, releaseStreamConfig.default
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

  local defaultName
  self.releaseStreams, defaultName = readReleaseStreamConfig()
  self.defaultReleaseStream = self.releaseStreams[defaultName]
  local activeReleaseStreamName, activeVersionString = readLaunchConfig()
  for name, releaseStream in pairs(self.releaseStreams) do
    if not love.filesystem.getInfo(self.path .. name, "directory") then
      love.filesystem.createDirectory(self.path .. name)
    end

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

  -- this can happen if the releaseStream got removed by an update
  if self.activeReleaseStream == nil then
    self.activeReleaseStream = self.defaultReleaseStream
    self.activeVersion = self.getLatestInstalledVersion(self.activeReleaseStream)
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
          -- if we failed to download it, we should no longer consider it available
          for i = #self.releaseStreams[version.releaseStream.name].availableVersions, 1, -1 do
            if version == self.releaseStreams[version.releaseStream.name].availableVersions[i] then
              table.remove(self.releaseStreams[version.releaseStream.name].availableVersions, i)
            end
          end
          -- also remove its directory since it will be empty
          love.filesystem.remove(self.path .. version.releaseStream.name .. "/" .. version.version)
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

local function launchWithVersion(version)
  local _, _, vendor, _ = love.graphics.getRendererInfo( )

  local loveMajor = love.getVersion()

  if loveMajor >= 12 then
    if love.system.getOS() == "Windows" and (vendor == "ATI Technologies Inc." or vendor == "AMD") then
      -- there is a silent crash lua panic issue on windows 10 with AMD gpus if the game is relaunched via restart
      -- at least that's the anecdotal evidence
      package.loaded.main = nil
      package.loaded.conf = nil
      love.conf = nil
      love.restart = { restartSource = "updater", startUpFile = version.path }
      love.init()
      -- command line args for love automatically are saved inside a global args table
      love.load(arg)
    else
      -- cleaner solution but meh
      love.event.restart({ restartSource = "updater", startUpFile = version.path })
    end
  else
    love.filesystem.write("updater/startUp.txt", "updater\n" .. version.path)
    love.event.quit("restart")
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
    launchWithVersion(version)
  end
end

-- tries to remove the specified version from disk
-- returns true if it was found and removed
-- returns false if the version could not be removed
function GameUpdater:removeInstalledVersion(versionInfo)
  if self.activeVersion.version == versionInfo then
    return false
  end
  if versionInfo and versionInfo.releaseStream and self.releaseStreams[versionInfo.releaseStream.name] then
    local releaseStream = self.releaseStreams[versionInfo.releaseStream.name]
    for versionString, installedVersion in pairs(releaseStream.installedVersions) do
      if installedVersion.version == versionInfo.version then
        if love.filesystem.remove(installedVersion.path) then
          -- also remove the directory in which the game file was present
          love.filesystem.remove(self.path .. "/" .. versionInfo.releaseStream.name .. "/" .. versionString)
          releaseStream.installedVersions[versionString] = nil
          return true
        end
      end
    end
  end

  return false
end

return GameUpdater