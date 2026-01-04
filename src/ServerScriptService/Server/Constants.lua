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
		},
	},
    
    states = {
        loaded = false,
        inGame = false,
    }
}

table.freeze(Constants)

return Constants