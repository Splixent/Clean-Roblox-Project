
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared

local Maid = require(Shared.Maid)
local SharedConstants = require(Shared.Constants)

local Player = Players.LocalPlayer

local PlotStation = {}
PlotStation.__index = PlotStation

export type PlotStation = {
    model: Model,
    stationInfo: any,
    levelStats: any,
    maid: Maid.Maid,
    player: Player,
    data: {
        stationType: string,
        level: number,
        ownerId: number,
        model: Model,
    },
    __attributes: {
        [string]: any,
    },
}

function PlotStation.new(ownerPlayer: Player, stationModel: Model)
    local self = setmetatable({}, PlotStation)
    self.ownerPlayer = ownerPlayer
    self.player = Player
	self.model = stationModel
    self.maid = Maid.new()

	self.stationInfo = SharedConstants.potteryStationInfo[stationModel:GetAttribute("StationType") or "Unknown"] or {}
    self.levelStats = self.stationInfo.levelStats or {}
    
    self.data = {
        stationType = stationModel:GetAttribute("StationType") or "Unknown",
        level = stationModel:GetAttribute("Level") or 0,
        ownerId = stationModel:GetAttribute("Owner") or 0,
        model = self.model,
    }

	self.__attributes = setmetatable({}, {
		__index = function(_, key)
			return self.model:GetAttribute(key)
		end,
		__newindex = function(_, key, value)
			self.model:SetAttribute(key, value)
		end,
	})

    self.__attributeChanged = setmetatable({}, {
		__index = function(_, key)
			return self.model:GetAttributeChangedSignal(key)
		end,
	})

    return self
end

function PlotStation:SetupInteraction()
end

function PlotStation:Upgrade()
end

function PlotStation:Destroy()
    self.maid:DoCleaning()
end

return PlotStation
