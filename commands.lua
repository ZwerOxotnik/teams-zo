--[[
Copyright 2019, 2021 ZwerOxotnik <zweroxotnik@gmail.com>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

		http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
]]--

-- You can write and receive any information on the links below.
-- Source: https://github.com/ZwerOxotnik/teams
-- Mod portal: https://mods.factorio.com/mod/teams-zo
-- Homepage: https://forums.factorio.com/viewtopic.php?f=190&t=73013

local module = {}
module.self_events = require('self_events')
local prohibited_forces = {neutral = true, player = true, enemy = true}

-- local function clear_player_data(event)
-- 	global.teams.players[event.player_index] = nil
-- end

local function trim(s)
	return s:match'^%s*(.*%S)' or ''
end

-- Sends message to a player or server
local function print_to_caller(message, caller)
	if caller then
		if caller.valid then
			caller.print(message)
		end
	else
		print(message) -- this message for server
	end
end

local function team_list_command(cmd)
	if cmd.player_index == 0 then
		for name, _ in pairs(game.forces) do
			print(name)
		end
		return
	end

	local caller = game.get_player(cmd.player_index)

	local function get_forces(forces)
		local list = ""
		for _, force in pairs(forces) do
			if #force.players > 0 then
				list = list .. force.name .. '(' .. #force.connected_players .. '/' .. #force.players .. ') '
			else
				list = list .. force.name .. ' '
			end
		end
		return list
	end

	local ally_forces = {}
	local neutral_forces = {}
	local enemy_forces = {}

	local caller_force = caller.force
	for _, force in pairs(game.forces) do
		if force ~= caller_force then
			if caller_force.get_friend(force) then
				table.insert(ally_forces, force)
			elseif caller_force.get_cease_fire(force) then
				table.insert(neutral_forces, force)
			else
				table.insert(enemy_forces, force)
			end
		end
	end

	caller.print({"", "[font=default-large-bold][color=#FFFFFF]", {"gui-map-editor-title.force-editor"}, {"colon"}, " for \"" .. caller.force.name .. "\"[/color][/font]"})
	if #enemy_forces > 0 then
		caller.print({"", "  [font=default-large-bold][color=#880000]Enemies[/color][/font]", {"colon"}, ' ', get_forces(enemy_forces)})
	end
	if #neutral_forces > 0 then
		caller.print({"", "  [font=default-large-bold]Neutrals[/font]", {"colon"}, ' ', get_forces(neutral_forces)})
	end
	if #ally_forces > 0 then
		caller.print({"", "  [font=default-large-bold][color=green]Allies[/color][/font]", {"colon"}, ' ', get_forces(ally_forces)})
	end
end

local function show_team_command(cmd)
	local caller = game.get_player(cmd.player_index)
	if cmd.parameter == nil then
		if cmd.player_index == 0 then return end
		cmd.parameter = caller.force.name
	elseif #cmd.parameter > 52 then
		print_to_caller({"too-long-team-name"}, caller)
		return
	else
		cmd.parameter = trim(cmd.parameter)
	end

	local target_force = game.forces[cmd.parameter]
	if target_force == nil then
		print_to_caller({"force-doesnt-exist", cmd.parameter}, caller)
		return
	end

	local function get_players(force)
		local list = ""
		local count = 0
		for _, player in pairs(force.connected_players) do
			list = ' ' .. list .. player.name
			count = count + 1
			if count > 40 then
				return list .. "+" .. tostring(#force.players - 40)
			end
		end
		for _, player in pairs(force.players) do
			if player.connected == false then
				list = ' ' .. list .. player.name
				count = count + 1
				if count > 40 then
					return list .. "+" .. tostring(#force.players - 40)
				end
			end
		end
		return list
	end

	print_to_caller({"", {"gui-browse-games.games-headers-players"}, {"colon"}, get_players(target_force)}, caller)
end

local function kick_teammate_command(cmd)
	local caller = game.get_player(cmd.player_index)
	local target_player = game.get_player(cmd.parameter)
	if caller.admin then
		game.print(cmd.parameter .. " was kicked from \"" .. target_player.force.name .. "\" team by " .. caller.name)
		target_player.force = game.forces["player"]
		script.raise_event(module.self_events.on_kick, {player_index = target_player.index, kicker = caller.index})
	elseif caller.force == target_player.force then
		if caller.force.players[1] == caller then
			game.print(cmd.parameter .. " was kicked from \"" .. target_player.force.name .. "\" team by " .. caller.name)
			target_player.force = game.forces["player"]
			script.raise_event(module.self_events.on_kick, {player_index = target_player.index, kicker = caller.index})
		else
			caller.print("You don't have permissions to kick players")
		end
	else
		caller.print("You can't kick a player from another force")
	end
end

local function create_new_team_command(cmd)
	local caller = game.get_player(cmd.player_index)

	if #cmd.parameter > 52 then
		caller.print({"too-long-team-name"}, cmd.player_index)
		return
	end
	cmd.parameter = trim(cmd.parameter)

	-- for compability with other mods/scenarios and forces count max = 64 (https://lua-api.factorio.com/1.1.30/LuaGameScript.html#LuaGameScript.create_force)
	if #game.forces >= 60 then caller.print({"teams.too_many"}) return end
	if game.forces[cmd.parameter] then
		caller.print({"gui-map-editor-force-editor.new-force-name-already-used", cmd.parameter})
		return
	end

	local new_team = game.create_force(cmd.parameter)
	if #caller.force.players == 1 and not prohibited_forces[caller.force.name] then
		local technologies = new_team.technologies
		for name, tech in pairs(caller.force.technologies) do
			technologies[name].researched = tech.researched
		end
		game.merge_forces(caller.force, new_team)
	else
		local prev_force = caller.force
		caller.force = new_team
		local technologies = new_team.technologies
		for name, tech in pairs(prev_force.technologies) do
			technologies[name].researched = tech.researched
		end
	end
end

local function remove_team_command(cmd)
	local caller = game.get_player(cmd.player_index)
	local target_force = game.forces[cmd.parameter]
	if #target_force.players ~= 0 then
		caller.print("The team isn't empty. There are still players in it")
		return
	elseif prohibited_forces[target_force.name] then
		caller.print({"gui-map-editor-force-editor.cant-delete-built-in-force"})
		return
	end

	game.merge_forces(target_force, game.forces["player"])
end

-- local function update_global_data()
-- 	global.teams = global.teams or {}
-- 	local data = global.teams
-- 	-- data.teams = data.teams or {}
-- 	-- data.players = data.players or {}
-- 	-- data.settings = data.settings or {}
-- end
-- module.on_init = update_global_data
-- module.on_configuration_changed = update_global_data

remote.remove_interface("zo-teams-core")
remote.add_interface("zo-teams-core", {
  get_event_name = function(name)
    return module.self_events[name]
  end
})

-- module.get_default_events = function()
-- 	local events = {}
-- 	local on_nth_tick = {}

-- 	return events, on_nth_tick
-- end

module.commands = {
	create_team = create_new_team_command,
	remove_team = remove_team_command,
	team_list = team_list_command,
	show_team = show_team_command,
	kick_teammate = kick_teammate_command
}

return module
