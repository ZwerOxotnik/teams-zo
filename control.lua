local SWITCHABLE_COMMANDS, CONST_COMMANDS = require("mod-commands").get_commands()
local commands_control = require("commands")

-- Don't use symbols like '-' etc (it'll break pattern of regular expressions)
local MOD_SHORT_NAME = "zo_teams_"
local MAX_INPUT_LENGTH = 500 -- set any number

local function trim(s)
	return s:match'^%s*(.*%S)' or ''
end

-- Sends message to a player or server
local function print_to_caller(message, player_index)
	if player_index == 0 then
		print(message) -- this message for server
	else
		game.get_player(player_index).print(message)
	end
end

local player_input_type = 1
local team_input_type = 2
local input_types = {
	player = player_input_type,
	team = team_input_type
}
local function add_custom_command(command_settings, original_func)
	local input_type = input_types[command_settings.input_type]
	local is_allowed_empty_args = command_settings.is_allowed_empty_args
	local command_name = command_settings.name
	local command_description = command_settings.description

	commands.add_command(command_settings.name, command_description, function(cmd)
		if cmd.player_index == 0 then
			if command_settings.allow_for_server == false then
				print({"prohibited-server-command"})
				return
			end
		else
			local caller = game.get_player(cmd.player_index)
			if not (caller and caller.valid) then return end
			if command_settings.only_for_admin and caller.admin == false then
				caller.print({"command-output.parameters-require-admin"})
				return
			end
		end

		if cmd.parameter == nil then
			if is_allowed_empty_args == false then
				print_to_caller({"", '/' .. command_name .. ' ', command_description}, cmd.player_index)
				return
			end
		elseif #cmd.parameter > MAX_INPUT_LENGTH then
			print_to_caller({"", {"description.maximum-length", '=', MAX_INPUT_LENGTH}}, cmd.player_index)
			return
		end

		if cmd.parameter and input_type then
			if input_type == player_input_type then
				if #cmd.parameter > 32 then
					print_to_caller({"gui-auth-server.username-too-long"}, cmd.player_index)
					return
				else
					cmd.parameter = trim(cmd.parameter)
					local player = game.get_player(cmd.parameter)
					if not (player and player.valid) then
						print_to_caller({"player-doesnt-exist", cmd.parameter}, cmd.player_index)
						return
					end
				end
			elseif input_type == team_input_type then
				if #cmd.parameter > 52 then
					print_to_caller({"too-long-team-name"}, cmd.player_index)
					return
				else
					cmd.parameter = trim(cmd.parameter)
					local force = game.forces[cmd.parameter]
					if not (force and force.valid) then
						print_to_caller({"force-doesnt-exist", cmd.parameter}, cmd.player_index)
						return
					end
				end
			end
		end

		-- error handling
		local is_ok, error_message = pcall(original_func, cmd)
		if is_ok then return end
		print_to_caller(error_message, cmd.player_index)

		local is_message_sended = false
		for _, player in pairs(game.connected_players) do
			if player.admin then
				player.print(error_message)
				is_message_sended = true
			end
		end
		if is_message_sended == false then
			log(error_message)
		end
	end)
end

local function handle_custom_commands(module)
	for key, func in pairs(module.commands) do
		local command_settings = SWITCHABLE_COMMANDS[key] or CONST_COMMANDS[key] or {}
		command_settings.name = command_settings.name or key
		local setting = nil
		if SWITCHABLE_COMMANDS[key] then
			setting = settings.global[MOD_SHORT_NAME .. key]
		end

		if setting == nil or setting.value then
			add_custom_command(command_settings, func)
		else
			commands.remove_command(command_settings.name)
		end
	end
end

local function check_custom_addons_on_runtime_mod_setting_changed(event)
	if event.setting_type ~= "runtime-global" then return end
	if string.find(event.setting, '^' .. MOD_SHORT_NAME) ~= 1 then return end

	local command_name = string.gsub(event.setting, '^' .. MOD_SHORT_NAME, "")
	local func = commands_control.commands[command_name] -- WARNING: check this throughly!
	local command_settings = SWITCHABLE_COMMANDS[command_name] or {}
	local state = settings.global[event.setting].value
	command_settings.name = command_settings.name or command_name
	if state then
		game.print("Added command: " .. command_settings.name or command_name)
		add_custom_command(command_settings, func)
	else
		game.print("Removed command: " .. command_settings.name or command_name)
		commands.remove_command(command_settings.name or command_name)
	end
end

handle_custom_commands(commands_control)
script.on_event(defines.events.on_runtime_mod_setting_changed, check_custom_addons_on_runtime_mod_setting_changed)
