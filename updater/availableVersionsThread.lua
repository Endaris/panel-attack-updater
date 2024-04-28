-- for macos we need to append the source directory to use our .so file in 
-- the exported version
require("love.system")
if love.system.getOS() == 'OS X' and love.filesystem.isFused() then
  package.cpath = package.cpath .. ';' .. love.filesystem.getSourceBaseDirectory() .. '/?.so'
end
local loadReleaseStream = require("updater.releaseStream")

local releaseStreamConfig = ...
print("entered thread")
local releaseStream = loadReleaseStream(releaseStreamConfig)
print("loaded release stream from the passed config")
local versions = releaseStream:getAvailableVersions()
print("fetched " .. #versions .. " versions")
love.thread.getChannel(releaseStream.name):push(versions)
print("pushed result under the name " .. releaseStream.name)