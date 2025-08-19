local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local MarketplaceService = game:GetService("MarketplaceService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local ServerInfoMap = MemoryStoreService:GetSortedMap("ServerInfo")

local Shared = ReplicatedStorage.Shared
local Server = ServerScriptService.Server

local DataObject = require(Server.Datastore.DataObject)
local ScriptUtils = require(Shared.ScriptUtils)
local Events = require(Shared.Events)
local ServerConstants = require(Server.Constants)

local GetServerList = Events.GetServerList

local ServerNetworkManager = {
    serverName = ScriptUtils:WeightedRandom(ServerConstants.serverNames.first).." "..ScriptUtils:WeightedRandom(ServerConstants.serverNames.last),
    serverKey = tostring(game.JobId),
    accessCode = nil,

    serverListPlaces = {},

    serverListDebounce = {}
}

function ServerNetworkManager:SanitizeForClient(serverInfos)
    local newServerInfos = {}

    for i, keyValue in ipairs (serverInfos) do
        if keyValue.value.setup == true then continue end
        keyValue.value.accessCode = nil
        keyValue.value.playerList = HttpService:JSONDecode(keyValue.value.playerList)
        table.insert(newServerInfos, keyValue.value)
    end

    return newServerInfos
end

function ServerNetworkManager:CatchSetupHook()
    while ServerNetworkManager.accessCode == nil do
        local success, serverInfos = pcall(function()
            return ServerInfoMap:GetRangeAsync(Enum.SortDirection.Ascending, 199)
        end)

        if success == true then
            for i, keyValue in ipairs (serverInfos) do
                if keyValue.value.setup == true and keyValue.key == game.PrivateServerId then
                    ServerNetworkManager.accessCode = keyValue.value.accessCode
                    break
                end
            end
            break
        end
        task.wait(1)
    end
end

function ServerNetworkManager:UpdateServer()
    ServerNetworkManager.updateTask = task.spawn(function()
        while true do
            local _, rawInfo = pcall(function()
                return HttpService:JSONDecode(HttpService:GetAsync("http://ip-api.com/json/?fields=1110015"))
            end)

            local playerList = {}

            for _, player in pairs (Players:GetPlayers()) do
                table.insert(playerList, player.UserId)
            end

            ServerNetworkManager:CatchSetupHook()

            ServerNetworkManager.serverInfo = {
                serverName = ServerNetworkManager.serverName,
                continent = rawInfo ~= nil and rawInfo.continent or "-",
                regionName = rawInfo ~= nil and rawInfo.regionName or "-",
                country = rawInfo ~= nil and rawInfo.country or "-",
                connectivity = "None",
                state = "None",
                playerList = HttpService:JSONEncode(playerList),
                serverAge = game.Workspace.DistributedGameTime,
                accessCode = ServerNetworkManager.accessCode,
            }

            if RunService:IsStudio() then
                ServerNetworkManager.serverKey = "Default"
            end
            
            local success, _ = pcall(function()
                return ServerInfoMap:SetAsync(ServerNetworkManager.serverKey, ServerNetworkManager.serverInfo, 10)
            end)

            if not success then
                warn("Failed to upload serverInfo")
            end
            
            task.wait(10)
        end
    end)
end

GetServerList:SetCallback(function(player)
    if ServerNetworkManager.serverListDebounce[player] == nil or ServerNetworkManager.serverListDebounce[player] == false then
        ServerNetworkManager.serverListDebounce[player] = true

        local success, serverInfos = pcall(function()
            return ServerInfoMap:GetRangeAsync(Enum.SortDirection.Ascending, 199)
        end)

        task.delay(2, function()
            ServerNetworkManager.serverListDebounce[player] = false
        end)
    
        if success then
            return ServerNetworkManager:SanitizeForClient(serverInfos)
        end
    end
    return "cooldown"
end)

task.spawn(function()
    if table.find(ServerNetworkManager.serverListPlaces, game.PlaceId) then
        ServerNetworkManager:UpdateServer()

        game:BindToClose(function()
            if ServerNetworkManager.updateTask ~= nil then
                ServerInfoMap:RemoveAsync(ServerNetworkManager.serverKey)
                task.cancel(ServerNetworkManager.updateTask)
            end
        end)
    end
end)

return ServerNetworkManager