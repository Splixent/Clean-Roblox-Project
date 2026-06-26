local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ByteNet = require(ReplicatedStorage.Shared.Packages.ByteNet)

return ByteNet.defineNamespace("Events", function()
	return {
		InGame = ByteNet.definePacket({
			value = ByteNet.nothing,
		}),
	}
end)
