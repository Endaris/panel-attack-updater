-- configuration file for platform independent love powered building tool https://github.com/ellraiser/love-build

return {
  -- basic settings:
  name = 'Panel Attack', -- name of the game for your executable
  developer = 'Panel Attack Devs', -- dev name used in metadata of the file
  --output = '../dev-build', -- output location for your game, defaults to $SAVE_DIRECTORY
  version = '1.0', -- 'version' of your game, used to make a version folder in output
  love = '12.0', -- version of LÖVE to use, must match github releases
  ignore = { -- folders/files to ignore in your project
    'updater/tests',
    '.DS_Store',
    '.gitignore',
    '.vscode',
    'https'
  },
  icon = 'icon.png', -- 256x256px PNG icon for game, will be converted for you

  -- optional settings:
  use32bit = false, -- set true to build windows 32-bit as well as 64-bit

  libs = { -- files to place in output directly rather than fuse
   -- windows = {'https/win64/https.dll'}, -- can specify per platform or "all"
   -- macos = {'https/macos/https.so'},
   -- linux = {'https/linux/https.so'}
   all = {}
  },

  platforms = {'linux', 'windows, macos'} -- set if you only want to build for a specific platform
}