--[[
Recommended to know about https://lua-api.factorio.com/latest/LuaCommandProcessor.html#LuaCommandProcessor.add_command

Returns table of commands without functions as command "settings". All parameters are optional!
  Contains:
  	name :: string: The name of your /command. (default: key of the table)
  	description :: string or LocalisedString: The description of your command. (default: nil)
  	allow_empty_args :: bool: Ignores empty parameters in commands, otherwise stops the command.  (default: true)
  	input_type :: string: filter for parameters by type of input. (default: nil)
      possible variants:
        "player" - Stops execution if can't find a player by parameter
        "team" - Stops execution if can't find a team (force) by parameter
    allow_for_server :: bool: Allow execution of a command from a server (default: false)
    only_for_admin :: bool: The command can be executed only by admins (default: false)
]]--

return {
	create_team = {name = "create-team", allow_empty_args = false, description = {"gui-map-editor-force-editor.no-force-name-given"}},
	remove_team = {name = "remove-team", input_type = "team", description = {"teams.remove-team"}, only_for_admin = true},
	team_list = {name = "team-list", description = {"teams.team-list"}, allow_for_server = true},
	show_team = {name = "show-team", description = {"teams.show-team"}, allow_for_server = true},
	kick_teammate = {name = "kick-teammate", description = {"teams.kick-teammate"}, input_type = "player"}
}
