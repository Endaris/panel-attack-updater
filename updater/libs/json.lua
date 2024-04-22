-- provides a wrapper around dkjson or whatever other json library you intend to use
local jsonFuncs = {}
local jsonLib = "dkjson"
local json = require("updater.libs." .. jsonLib)

function jsonFuncs.decodeFile(file)
  if not love.filesystem.getInfo(file, "file") then
    print("No file at specified path " .. file)
    return nil
  else
    local fileContent, info = love.filesystem.read(file)
    if type(info) == "string" then
      -- info is the number of read bytes if successful, otherwise an error string
      -- thus, if it is of type string, that indicates an error
      print("Could not read file at path " .. file)
      return nil
    else
      return jsonFuncs.decode(fileContent)
    end
  end
end

function jsonFuncs.decode(jsonString)
  local value, _, errorMsg = json.decode(jsonString)
  if errorMsg then
    print(errorMsg .. ":\n" .. jsonString)
    return nil
  else
    return value
  end
end

-- unloads the required json library of choice
function jsonFuncs.unload()
  package.loaded[jsonLib] = nil
end

return jsonFuncs