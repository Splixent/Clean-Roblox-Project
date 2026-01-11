local ReplicatedStorage = game:GetService("ReplicatedStorage")

local alias = require(ReplicatedStorage.Shared.Cmdr.BuiltInCommands.Utility.alias)
local SharedConstants = {

    potteryStationInfo = {
        ClayPatch = {
            levelStats = {
                ["0"] = {maxClay = 20, clayPerInterval = 1, harvestAmount = 1, harvestCooldown = 1, generateDelay = 3},
            }
        }
    },

    clayTypes = {
        normal = {
            displayName = "Clay",
            icon = "rbxassetid://86846067959868",
            color = Color3.fromRGB(150, 111, 51),
        }
    },

    itemData = {
        Clay = {
            displayName = "Clay",
            clayType = "normal",
            description = "A lump of clay, ready to be shaped into pottery.",
            maxStackSize = 999,
            icon = "rbxassetid://86846067959868",
        },
    },
    pottteryData = {
        -- Bowls
        bowl = {
            name = "Bowl",
            model = "Bowl", -- Model name in ReplicatedStorage.Assets.PotteryStyles
            rarity = "Common",
            description = "A simple bowl made of clay.",
            sectionType = "Bowls",
            cost = { clay = 5 }
        },

    }

}

table.freeze(SharedConstants)
return SharedConstants
