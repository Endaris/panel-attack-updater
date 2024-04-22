require("lldebugger").start()
--require("updater.tests.tests")

local logger = require("updater.logger")

-- love run needs to be overwritten before it can run because it runs only ONCE
-- after that the mainloop can no longer be overwritten without fully restarting
-- however, fully restarting would mean that the game updater cannot leave a global behind for the main game to use
local DefaultLoveRunFunctions = require("DefaultLoveRunFunctions")
-- leave behind a reference to the mainloop on the love global that the main game can overwrite with its own mainloop
love.runInternal = DefaultLoveRunFunctions.innerRun
love.run = DefaultLoveRunFunctions.run
local love_errorhandler = love.errorhandler

GAME_UPDATER_STATES = { idle = 0, checkingForUpdates = 1, downloading = 2}
GAME_UPDATER = require("updater.gameUpdater")

local loadingIndicator = require("loadingIndicator")
local bigFont = love.graphics.newFont(24)
local updateString = ""


function love.load(args)
  loadingIndicator:setDrawPosition(love.graphics:getDimensions())
  loadingIndicator:setFont(bigFont)

  GAME_UPDATER:registerCallback(function(version)
    -- if we downloaded something we want to use it
    GAME_UPDATER.activeVersion = version
    -- clear for later use by the actual game
    GAME_UPDATER.onDownloadedCallbacks = {}
  end)

  GAME_UPDATER:init()
  GAME_UPDATER:getAvailableVersions(GAME_UPDATER.activeReleaseStream)
end

function love.update(dt)
  GAME_UPDATER:update()

  if GAME_UPDATER.state ~= GAME_UPDATER_STATES.idle then
    if GAME_UPDATER.state == GAME_UPDATER_STATES.checkingForUpdates then
      updateString = "Checking for updates..."
    else
      updateString = "Downloading new version..."
    end
  else
    if GAME_UPDATER:updateAvailable(GAME_UPDATER.activeReleaseStream) then
      -- auto update
      table.sort(GAME_UPDATER.activeReleaseStream.availableVersions, function(a,b) return a.version > b.version end)
      GAME_UPDATER:downloadVersion(GAME_UPDATER.activeReleaseStream.availableVersions[1])
    else
      GAME_UPDATER:launch(GAME_UPDATER.activeVersion)
    end
  end
end

local width, height = love.graphics.getDimensions()
function love.draw()

  love.graphics.printf(updateString, bigFont, 0, height / 2 - 12, width, "center")

  loadingIndicator:draw()
end

function love.errorhandler(msg)
  if lldebugger then
    error(msg, 2)
  else
    logger:log(msg)
    pcall(logger.write, logger)
    return love_errorhandler(msg)
  end
end