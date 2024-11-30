local https = require("https")

local url, filepath = ...

local status, body, headers = https.request(url, {method = "GET", headers = { ["user-agent"] = love.filesystem.getIdentity()}})
if status == 200 and body then
  love.filesystem.write(filepath, body)
end

love.thread.getChannel(url):push({success = status == 200 and body, status = status, headers = headers})