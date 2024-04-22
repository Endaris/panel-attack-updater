local loadReleaseStream = require("updater.releaseStream")

local releaseStreamConfig = ...
print("entered thread")
local releaseStream = loadReleaseStream(releaseStreamConfig)
print("loaded release stream from the passed config")
local versions = releaseStream:getAvailableVersions()
print("fetched " .. #versions .. " versions")
love.thread.getChannel(releaseStream.name):push(versions)
print("pushed result under the name " .. releaseStream.name)