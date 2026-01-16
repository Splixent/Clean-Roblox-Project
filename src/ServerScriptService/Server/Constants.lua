local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local SharedConstants = require(Shared.Constants)
local ScriptUtils = require(Shared.ScriptUtils)

local Constants = {

	profileSettings = {
		profileTemplate = {
            loginInfo = {
                totalLogins = 0,
                lastLogin = 0,
                loginTime = 0,
                totalPlaytime = 0
            },
            settings = {},
            plot = "Starter",
            potteryStations = {
                ClayPatch = {
                    level = 0,
                    clay = 0,
                },
                CoolingTable = {
                    level = 0,
                    coolingPottery = {
                        
                    }
                },
                Kiln = {
                    level = 0,
                    firingPottery = {
                        
                    }
                },
                PottersWheel = {level = 0},
                GlazeTable = {level = 0},
            },
             
            inventory =  {
                hotbar =  {
                    "Clay",
                    "bowl_1"
                },
                items =  {
                    Clay =  {
                        amount = 45
                    },
                    bowl_1 =  {
                        amount = 1,
                        clayType = "normal",
                        cooled = true,
                        dried = true,
                        fired = true,
                        potteryStyle = true,
                        styleKey = "bowl"
                    }
                }
            }
		},

	},
    
    states = {
        loaded = false,
        inGame = false,

        equippedItem = nil,
    }
}

table.freeze(Constants)

return Constants