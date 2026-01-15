local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedConstants = {

    potteryStationInfo = {
        ClayPatch = {
            levelStats = {
                ["0"] = {maxClay = 20, clayPerInterval = 1, harvestAmount = 1, harvestCooldown = 1, generateDelay = 3},
            }
        },
        CoolingTable = {
            levelStats = {
                ["0"] = {maxSlots = 4, dryTimeMultiplier = 1.0, coolTimeMultiplier = 1.0}, -- coolingTime: time to cool after firing
            }
        }
    },

    clayTypes = {
        normal = {
            displayName = "Clay",
            icon = "rbxassetid://86846067959868",
            color = Color3.fromRGB(168, 73, 23),
            driedColor = Color3.fromRGB(189, 156, 124),
            colorChangeEase = {
                style = Enum.EasingStyle.Linear,
                direction = Enum.EasingDirection.Out,
            },
            baseDryTime = 3, -- Base drying time in seconds for this clay type
            baseCoolTime = 3, -- Base cooling time in seconds for this clay type
        }
    },

    itemData = {
        Clay = {
            displayName = "Clay",
            itemType = "clay",
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
            rarity = "Common",
            description = "A simple bowl made of clay.",
            icon = "rbxassetid://0",
            sectionType = "Bowls",
            clayType = "normal", -- Required clay type
            dryTimeMultiplier = 1.0,
            coolTimeMultiplier = 1.0,
            cost = { clay = 5 }
        },

    }

}

table.freeze(SharedConstants)
return SharedConstants
