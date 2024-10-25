local logger = {
  messages = {
    os.date()
  }
}

function logger:log(message)
  if message then
    self.messages[#self.messages+1] = string.format("%.3f", love.timer.getTime()) .. ": " .. message
    print(message)
  else
    print("tried to log nil value")
  end
end

function logger:write()
  love.filesystem.write("updater.log", table.concat(self.messages, "\n"))
end

function logger:append()
  love.filesystem.append("updater.log", "\n" .. table.concat(self.messages, "\n"))
end

return logger