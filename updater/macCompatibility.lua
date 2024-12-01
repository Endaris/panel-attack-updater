-- for macos we need to append the source directory to use our .so file in the exported version
-- each thread is also spun up with only the base cpath for love/lua, not keeping additions from the mainthread
-- so we do it again every time
-- love.system is not loaded per default in threads, so make sure it is loaded for the OS check
require("love.system")
if love.system.getOS() == 'OS X' and love.filesystem.isFused() then
  package.cpath = package.cpath .. ';' .. love.filesystem.getSourceBaseDirectory() .. '/?.so'
  love.thread.getChannel("logging"):push("New DL thread on Mac, sourcebasedirectory is " .. love.filesystem.getSourceBaseDirectory())
end