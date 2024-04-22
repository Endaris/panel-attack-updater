local timestampVersion = require("updater.timestampVersion")
local date = { year = 2024, month = 1, day = 27, hour = 13, min = 24, sec = 56}
local expectedTimestamp = os.time(date)

local function t1()
  local dateString = "2024-01-27_13-24-56"
  local timestamp = timestampVersion.toVersion(dateString)
  assert(expectedTimestamp == timestamp)
end

local function t2()
  local dateString = "2024-01-28"
  local timestamp = timestampVersion.toVersion(dateString)
  assert(timestamp > expectedTimestamp)
end

t1()
t2()