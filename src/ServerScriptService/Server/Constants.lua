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
                CoolingTable = {level = 0},
                Kiln = {level = 0},
                PottersWheel = {level = 0},
                GlazeTable = {level = 0},
            }
		},
	},
    
    states = {
        loaded = false,
        inGame = false,
    }
}

table.freeze(Constants)

return Constants