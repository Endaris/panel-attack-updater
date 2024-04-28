love.thread.getChannel("logging"):push("entered fetch versions thread (FVT)")
-- for macos we need to append the source directory to use our .so file in 
-- the exported version
require("love.system")
if love.system.getOS() == 'OS X' and love.filesystem.isFused() then
  package.cpath = package.cpath .. ';' .. love.filesystem.getSourceBaseDirectory() .. '/?.so'
  love.thread.getChannel("logging"):push("FVT: on Mac, sourcebasedirectory is " .. love.filesystem.getSourceBaseDirectory())
end
local loadReleaseStream = require("updater.releaseStream")

local releaseStreamConfig = ...
local releaseStream = loadReleaseStream(releaseStreamConfig)
love.thread.getChannel("logging"):push("FVT: loaded release stream from the passed config")
local versions = releaseStream:getAvailableVersions()
love.thread.getChannel("logging"):push("FVT: fetched " .. #versions .. " versions")
love.thread.getChannel(releaseStream.name):push(versions)
love.thread.getChannel("logging"):push("FVT: pushed result under the name " .. releaseStream.name)