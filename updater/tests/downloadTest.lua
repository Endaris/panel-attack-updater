
local function t1()
  local thread = love.thread.newThread("updater/downloadThread.lua")
  local url = "http://panelattack.com/index.html"
  thread:start(url, "testdownload.html")
  local result
  local startTime = love.timer.getTime()

  while not result and love.timer.getTime() < startTime + 5 do
    result = love.thread.getChannel("downloadUrl:" .. url):pop()
  end

  assert(result)
  assert(result.success)
  assert(love.filesystem.getInfo("testdownload.html"))
end

t1()