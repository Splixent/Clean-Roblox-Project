return {
	Name = "giveitem",
	Aliases = { "gi" },
	Description = "Gives an item to a player.",
	Group = "BabyAdmin",
	Args = {
		{
			Type = "players",
			Name = "Players",
			Description = "Players to give the item to",
		},
		{
			Type = "item",
			Name = "Item",
			Description = "Name of the item to give",
		},
		{
			Type = "number",
			Name = "Quantity",
			Description = "Amount of items to give (default = 1)",
			Default = 1,
			Optional = true,
		},
	},
}
