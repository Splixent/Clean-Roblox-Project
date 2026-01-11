return {
	Name = "respawn";
	Description = "Respawns a player or a group of players.";
	Group = "BabyAdmin";
	AutoExec = {
		"alias \"refresh|Respawns the player and returns them to their previous location.\" var= .refresh_pos ${position $1{player|Player}} && respawn $1 && tp $1 @${{var .refresh_pos}}"
	},
	Args = {
		{
			Type = "players";
			Name = "targets";
			Description = "The players to respawn."
		}
	}
}
