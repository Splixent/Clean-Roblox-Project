return {
	Name = "teleport";
	Aliases = {"tp", "tplm"};
	Description = "Teleports a player or set of players to one target.";
	Group = "BabyAdmin";
	AutoExec = {
		"alias \"bring|Brings a player or set of players to you.\" teleport $1{players|players|The players to bring} ${me}";
		"alias \"to|Teleports you to another player or location.\" teleport ${me} $1{player @ vector3|Destination|The player or location to teleport to}";
	};
	Args = {
		{
			Type = "players @ string";
			Name = "From";
			Description = "The players to teleport";
            Optional = true,
		},
		{
			Type = "player @ vector3";
			Name = "Destination";
			Description = "The player to teleport to";
            Optional = true,
		}
	};
}