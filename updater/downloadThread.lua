-- for macos we need to append the source directory to use our .so file in 
-- the exported version
require("love.system")
if love.system.getOS() == 'OS X' and love.filesystem.isFused() then
  package.cpath = package.cpath .. ';' .. love.filesystem.getSourceBaseDirectory() .. '/?.so'
end
local https = require("https")

local url, filepath = ...

local status, body, headers = https.request(url, {method = "GET", headers = { ["user-agent"] = love.filesystem.getIdentity()}})
if status == 200 and body then
  love.filesystem.write(filepath, body)
end

love.thread.getChannel(url):push({success = status == 200 and body, status = status, headers = headers})