local lfs = love.filesystem
local json = require("updater.libs.json")
local loadReleaseStream = require("updater.releaseStream")
local logger = require("updater.logger")

local GameUpdater = {
  path = "updater/",
  -- keys: version{url, version, releaseStream}, values: thread
  downloadThreads = {},
  releaseThreads = {},
  onDownloadedCallbacks = {},
  state = GAME_UPDATER_STATES.idle
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
    local releaseStreams = {}
    for _, config in ipairs(releaseStreamConfig.releaseStreams) do
      releaseStreams[config.name] = loadReleaseStream(config)
      releaseStreams[config.name].config = config
    end
    logger:log("Found " .. #releaseStreams .. " configured release streams")
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
    local result = love.thread.getChannel(version.url):pop()
    if result then
      thread:release()
      self.downloadThreads[version] = nil
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

local function processOngoingAvailableVersionsFetches(self)
  for releaseStreamName, thread in pairs(self.releaseThreads) do
    logger:log("Polling results for fetching available versions of releaseStream " .. releaseStreamName)
    local result = love.thread.getChannel(releaseStreamName):pop()
    if result then
      thread:release()
      self.releaseThreads[releaseStreamName] = nil
      logger:log("Fetched available versions for " .. releaseStreamName)
      self.releaseStreams[releaseStreamName].availableVersions = result
      for i = 1, #result do
        result[i].releaseStream = self.releaseStreams[releaseStreamName]
      end
    end
  end
end

function GameUpdater:update()
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
  if not releaseStream.availableVersions then
    logger:log("Failed to find any available versions for release stream " .. releaseStream.name)
    return false
  else
    releaseStream.installedVersions = releaseStream:getInstalledVersions(self.path)
    local latestInstalled = self.getLatestInstalledVersion(releaseStream)

    local availableVersions = releaseStream.availableVersions
    table.sort(availableVersions, function(a,b) return a.version < b.version end)
    local latestOnline = availableVersions[#availableVersions]

    return latestInstalled.version < latestOnline.version
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
    package.loaded.main = nil
    package.loaded.conf = nil
    love.conf = nil
    love.init()
    -- command line args for love are saved inside a global arg table
    love.load(arg)
  end
end


return GameUpdater