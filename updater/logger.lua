local logger = {
  messages = {
    os.date()
  },
  written = {}
}

function logger:log(message)
  self.messages[#self.messages+1] = string.format("%.3f", love.timer.getTime()) .. ": " .. message
  print(message)
end

function logger:write()
  love.filesystem.write("updater.log", table.concat(self.messages, "\n"))
  self.written[#self.written+1] = self.messages
  self.messages = { os.date() }
end

function logger:append()
  love.filesystem.append("updater.log", "\n" .. table.concat(self.messages, "\n"))
end

return logger