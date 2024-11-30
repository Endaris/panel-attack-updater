love.thread.getChannel("logging"):push("entered fetch versions thread (FVT)")

local loadReleaseStream = require("updater.releaseStream")

local releaseStreamConfig = ...
local releaseStream = loadReleaseStream(releaseStreamConfig)
love.thread.getChannel("logging"):push("FVT: loaded release stream from the passed config")
local versions = releaseStream:getAvailableVersions()
love.thread.getChannel("logging"):push("FVT: fetched " .. #versions .. " versions")
love.thread.getChannel(releaseStream.name):push(versions)
love.thread.getChannel("logging"):push("FVT: pushed result under the name " .. releaseStream.name)