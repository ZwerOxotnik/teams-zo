local mod_commands = require("mod-commands")
local commands_control = require("commands")

-- Adds commands into mod_commands to interact with commands 
mod_commands.handle_custom_commands(commands_control)

-- This is important \/
script.on_event(defines.events.on_runtime_mod_setting_changed, mod_commands.on_runtime_mod_setting_changed)
