local mod_commands = require("mod-commands")

-- Don't use symbols like '-' etc (it'll break pattern of regular expressions)
local MOD_SHORT_NAME = "zo_teams_"

local commands = {}
for key, command in pairs(mod_commands) do
	local command_name = command.name or key
	commands[#commands + 1] = {
		type = "bool-setting",
		name = MOD_SHORT_NAME .. key,
		setting_type = "runtime-global",
		default_value = command.default_value or true,
		localised_name = '/' .. command_name,
		localised_description = command.description or ""
	}
end
data:extend(commands)
