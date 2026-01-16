local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedConstants = {

    potteryStationInfo = {
        ClayPatch = {
            levelStats = {
                ["0"] = {maxSlots = 2, maxClay = 20, clayPerInterval = 1, harvestAmount = 1, harvestCooldown = 1, generateDelay = 3},
            }
        },
        CoolingTable = {
            levelStats = {
                ["0"] = {maxSlots = 4, dryTimeMultiplier = 1.0, coolTimeMultiplier = 1.0}, -- coolingTime: time to cool after firing
            }
        },
        Kiln = {
            levelStats = {
                ["0"] = {maxSlots = 2, fireTimeMultiplier = 1.0}, -- fireTime: time to fire pottery in kiln
            }
        }
    },

    clayTypes = {
        normal = {
            displayName = "Clay",
            icon = "rbxassetid://86846067959868",
            color = Color3.fromRGB(168, 73, 23),
            driedColor = Color3.fromRGB(189, 156, 124),
            firedColor = Color3.fromRGB(197, 95, 69),
            cooledColor = Color3.fromRGB(205, 77, 45),
            colorChangeEase = {
                style = Enum.EasingStyle.Linear,
                direction = Enum.EasingDirection.Out,
            },
            baseDryTime = 3, -- Base drying time in seconds for this clay type
            baseCoolTime = 3, -- Base cooling time in seconds for this clay type
            baseFireTime = 5, -- Base firing time in seconds for this clay type
        }
    },

    glazeTypes = {
        -- Finish icons for glaze table UI
        finishIcons = {
            matte = "rbxassetid://105406395394510",
            glossy = "rbxassetid://103159489658926",
            metallic = "rbxassetid://126865545695591",
            polished = "rbxassetid://110217006696402",
            lustrous = "rbxassetid://127534525226064",
            radiant = "rbxassetid://77810916576639",
            noFinish = "rbxassetid://129644060059853",
        },
        colors = {
            {
                name = "red",
                displayName = "Red",
                color = Color3.fromRGB(255, 0, 0),
            }
        },
        patterns = {
            {
                name = "noPattern",
                displayName = "No Pattern",
                icon = "rbxassetid://0",
            },
            {
                name = "triangles",
                displayName = "Triangle",
                icon = "rbxassetid://114699052452303",
            }
        },
        finishes = {
            {
                name = "matte",
                displayName = "Matte",
                icon = "rbxassetid://0",
            },
            {
                name = "metallic",
                displayName = "Metallic",
                icon = "rbxassetid://0",
            },
            {
                name = "glossy",
                displayName = "Glossy",
                icon = "rbxassetid://0",
            },
            {
                name = "polished",
                displayName = "Polished",
                icon = "rbxassetid://0",
            },
            {
                name = "lustrous",
                displayName = "Lustrous",
                icon = "rbxassetid://0",
            },
            {
                name = "radiant",
                displayName = "Radiant",
                icon = "rbxassetid://0",
            },
        },
        uniquePatterns = {
            bowl = {
                patterns = {
                    {
                        name = "hex",
                        displayName = "Hexagon",
                        icon = "rbxassetid://0",

                        finishes = {
                            name = "iridescent",
                            displayName = "Iridescent",
                            icon = "rbxassetid://0",
                        }
                    }
                },
            }
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
            fireTimeMultiplier = 1.0,
            cost = { clay = 5 }
        },

    }

}

table.freeze(SharedConstants)
return SharedConstants
