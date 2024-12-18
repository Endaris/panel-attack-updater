local externalstorage = true
local identity = "Panel Attack"

if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
  require("lldebugger").start()
end

love.filesystem._setAndroidSaveExternal(externalstorage)
love.filesystem.setIdentity(identity)

-- read startup file
if love.filesystem.getInfo("updater/startUp.txt", "file") then
  love.restart = {}
  local i = 1
  for line in love.filesystem.lines("updater/startUp.txt") do
    if i == 1 then
      love.restart.restartSource = line
    elseif i == 2 then
      love.restart.startUpFile = line
    end
    i = i + 1
  end
  love.filesystem.remove("updater/startUp.txt")
end


function love.conf(t)
  if love.restart then
    if love.filesystem.mount(love.restart.startUpFile, '') then
      -- the mount prepends the priority list of locations to check for file paths
      -- this means the next require will prefer the mounted directory
      -- so clear out the cached conf so we can reload it
      package.loaded["conf"] = nil
      require("conf")
      -- and then execute that one (it overrode the function we're currently in)
      love.conf(t)
      love.restart = nil
      GAME_UPDATER_STATES = { idle = 0, checkingForUpdates = 1, downloading = 2}
      GAME_UPDATER = require("updater.gameUpdater")
    end
  else
    t.identity = identity -- The name of the save directory (string)
    t.appendidentity = false -- Search files in source directory before save directory (boolean)
    t.version = "11.5" -- The LÖVE version this game was made for (string)
    t.console = false -- Attach a console (boolean, Windows only)
    t.accelerometerjoystick = false -- Enable the accelerometer on iOS and Android by exposing it as a Joystick (boolean)
    t.externalstorage = externalstorage -- True to save files (and read from the save directory) in external storage on Android (boolean)
    t.gammacorrect = false -- Enable gamma-correct rendering, when supported by the system (boolean)

    t.audio.mic = false -- Request and use microphone capabilities in Android (boolean)
    t.audio.mixwithsystem = false -- Keep background music playing when opening LOVE (boolean, iOS and Android only)

    t.window.title = "Panel Attack - Updater" -- The window title (string)
    t.window.icon = "icon.png" -- Filepath to an image to use as the window's icon (string)
    t.window.width = 800 -- The window width (number)
    t.window.height = 600 -- The window height (number)
    t.window.borderless = false -- Remove all border visuals from the window (boolean)
    t.window.resizable = false -- Let the window be user-resizable (boolean)
    t.window.minwidth = 1 -- Minimum window width if the window is resizable (number)
    t.window.minheight = 1 -- Minimum window height if the window is resizable (number)
    t.window.fullscreen = false -- Enable fullscreen (boolean)
    t.window.fullscreentype = "desktop" -- Choose between "desktop" fullscreen or "exclusive" fullscreen mode (string)
    t.window.usedpiscale = true -- Enable automatic DPI scaling (boolean)
    t.window.vsync = 1 -- Vertical sync mode (number)
    t.window.msaa = 0 -- The number of samples to use with multi-sampled antialiasing (number)
    t.window.depth = nil -- The number of bits per sample in the depth buffer
    t.window.stencil = nil -- The number of bits per sample in the stencil buffer
    t.window.x = nil -- The x-coordinate of the window's position in the specified display (number)
    t.window.y = nil -- The y-coordinate of the window's position in the specified display (number)
    t.window.display = 1
    t.window.highdpi = true

    -- for love 12
    t.highdpi = true -- Enable high-dpi mode for the window on a Retina display (boolean)
    t.window.displayindex = 1 -- Index of the monitor to show the window in (number)

    t.modules.audio = false -- Enable the audio module (boolean)
    t.modules.data = true -- Enable the data module (boolean, mandatory)
    t.modules.event = true -- Enable the event module (boolean)
    t.modules.font = true -- Enable the font module (boolean)
    t.modules.graphics = true -- Enable the graphics module (boolean)
    t.modules.image = true -- Enable the image module (boolean)
    t.modules.joystick = false -- Enable the joystick module (boolean)
    t.modules.keyboard = true -- Enable the keyboard module (boolean)
    t.modules.math = false -- Enable the math module (boolean)
    t.modules.mouse = false -- Enable the mouse module (boolean)
    t.modules.physics = false -- Enable the physics module (boolean)
    t.modules.sound = false -- Enable the sound module (boolean)
    t.modules.system = true -- Enable the system module (boolean)
    t.modules.thread = true -- Enable the thread module (boolean)
    t.modules.timer = true -- Enable the timer module (boolean), Disabling it will result 0 delta time in love.update
    t.modules.touch = false -- Enable the touch module (boolean)
    t.modules.video = false -- Enable the video module (boolean)
    t.modules.window = true -- Enable the window module (boolean)
  end

  t.renderers = {"opengl"}
end
