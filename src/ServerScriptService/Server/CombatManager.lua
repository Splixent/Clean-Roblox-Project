local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local MarketplaceService = game:GetService("MarketplaceService")

local Shared = ReplicatedStorage.Shared
local Server = ServerScriptService.Server

local DataObject = require(Server.Datastore.DataObject)
local PlayerEntityManager = require(Server.PlayerEntityManager)
local ScriptUtils = require(Shared.ScriptUtils)
local Events = require(Shared.Events)
local Maid = require(Shared.Maid)
local WeaponData = require(Shared.WeaponData)
local BufferUtils = require(Shared.BetterReplication.Lib.BufferUtils)
local Gizmo = require(Shared.CeiveImGizmo)
local Hitbox = require(Shared.Hitbox)
local Signal = require(Shared.Signal)

local sanityFunc: (data: BufferUtils.from_client_packet) -> boolean = nil

local RequestAttack = Events.RequestAttack:Server()
local RequestHit = Events.RequestHit:Server()
local FromClient = Shared.BetterReplication.Remotes.FromClient
local RequestBlock = Events.RequestBlock:Server()

local FromAI = Signal.new()

local CombatManager = {
    playerPositions = {},
    aiPositions = {},
    visualize = true,
    rollbackFrames = 15,
    fromAI = FromAI,
}


function CombatManager:InitializePlayer(player)
	player.CharacterAdded:Connect(function(character)
       
    end)
end

function CombatManager.BasicAttack(player, timeStamp, attackData)
	local playerEntity = PlayerEntityManager.new(player, true).Replica
	local playerReplica = DataObject.new(player)

	if playerEntity == nil then
		return
	end

	if playerEntity.Data.weapon.isEquipped == false then
		return
	end

	local weaponName = playerReplica.equipment.weapon
	local weaponData = WeaponData[weaponName]
	local weaponState = playerEntity.Data.weapon

	local timeElapsed = (DateTime.now().UnixTimestampMillis / 1000) - timeStamp

	local clientAttackNumber = attackData.attackNumber
	local nextAttack = weaponState.attackNumber + 1 > #weaponData.basicAttack and 1 or weaponState.attackNumber + 1

	if
		CombatManager.playerPositions[player] == nil
		or CombatManager.playerPositions[player].lastUpdate + 3 < tick()
		or #CombatManager.playerPositions[player].rollbackPositions ~= CombatManager.rollbackFrames
	then
		print("POSITION_DATA_NOT_RECIEIVED")
		return
	end

    if tick() + timeElapsed - weaponState.lastAttack < weaponData.basicAttack[clientAttackNumber].cooldown then
        playerEntity:SetValue({"weapon", "attackNumber"}, clientAttackNumber)
        return
    end
    
    if clientAttackNumber > nextAttack then
        return
    end

    if clientAttackNumber < nextAttack then
        print("RESET_ATTACK_NUMBER")      
    end
    
    if weaponState.attackNumber == #weaponData.basicAttack and clientAttackNumber ~= 1 then
        return
    end

    playerEntity:SetValue({"weapon", "lastAttack"}, tick())
    playerEntity:SetValue({"weapon", "attackNumber"}, clientAttackNumber)

    task.delay(weaponData.basicAttack[clientAttackNumber].attackDelay - timeElapsed, function()
	    playerEntity:SetValue({ "weapon", "hitWindowOpen" }, true)
        task.delay(weaponData.basicAttack[clientAttackNumber].hitDuration, function()
            playerEntity:SetValue({ "weapon", "hitWindowOpen" }, false)
        end)
    end)
end

RequestBlock:On(function(player, blockStartTime)
    local playerEntity = PlayerEntityManager.new(player, true).Replica
    local playerReplica = DataObject.new(player)

    if playerEntity == nil then
        return
    end

    if playerEntity.Data.weapon.isEquipped == false then
        return
    end

    local weaponName = playerReplica.equipment.weapon
    local weaponData = WeaponData[weaponName]
    local weaponState = playerEntity.Data.weapon

    if not weaponState.blocking then
        local playerPing = player:GetNetworkPing()
        local timeElapsed = (DateTime.now().UnixTimestampMillis / 1000) - blockStartTime

        print(timeElapsed, (playerPing * 2))

        playerEntity:SetValue({"weapon", "blocking"}, true)
        playerEntity:SetValue({"weapon", "blockStartTime"}, blockStartTime)
    else
        print("blockend")
		playerEntity:SetValue({ "weapon", "blocking" }, false)
    end
    
end)

RequestHit:On(function(player, targetCharacter, timeStamp)
	local playerEntity = PlayerEntityManager.new(player, true).Replica
	local playerReplica = DataObject.new(player)

    if playerEntity.Data.weapon.hitWindowOpen then
        if targetCharacter.Parent.Name == "AICharacters" then
            local weaponType = playerReplica.equipment.weapon
            local attackNumber = playerEntity.Data.weapon.attackNumber

            local attackerCharacter = player.Character

            local attackerHumanoidRootPart = attackerCharacter and attackerCharacter:FindFirstChild("HumanoidRootPart")
            local targetHumanoidRootPart = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")

            if targetHumanoidRootPart and attackerCharacter and attackerHumanoidRootPart then
                local targetRollbackData = CombatManager.aiPositions[targetCharacter]
                local attackerRollbackData = CombatManager.playerPositions[player]

                if targetRollbackData and targetRollbackData.rollbackPositions and attackerRollbackData and attackerRollbackData.rollbackPositions then
                    local targetIndex
                    local attackerIndex

                    for i, positionData in ipairs(attackerRollbackData.rollbackPositions) do
                        if positionData.timeStamp <= timeStamp then
                            attackerIndex = i
                            break
                        end
                    end

                    for i, positionData in ipairs(targetRollbackData.rollbackPositions) do
                        if positionData.timeStamp <= timeStamp then
                            targetIndex = i
                            break
                        end
                    end

                    if targetIndex and attackerIndex then
                        local targetHurtbox = Instance.new("Part")
                        targetHurtbox.Anchored = true
                        targetHurtbox.CanCollide = false
                        targetHurtbox.Parent = game.Workspace
                        targetHurtbox.Size = Vector3.new(4, 6, 2)
                        targetHurtbox.CFrame = targetRollbackData.rollbackPositions[targetIndex].cframe
                        targetHurtbox.Transparency = 1

                        local validHit
    
                        local simulatedHitbox = Hitbox.new(table.clone(WeaponData[weaponType].basicAttack[tonumber(attackNumber)]), {
                            scan = true,
                            onScan = function(hitData, handler)
    							validHit = hitData
                                targetHurtbox:Destroy()
                                handler:Destroy()
                            end,
                            whiteList = {targetHurtbox},
                            attachTarget = targetRollbackData.rollbackPositions[attackerIndex].cframe,
                        })
                        
                        local scanTask = task.spawn(function()
                            task.wait()
                            simulatedHitbox:Stop()
                        end)

                        simulatedHitbox:Play(true):Wait()
                        if scanTask then
                            task.cancel(scanTask)               
                        end
                        
                        if validHit then
                            targetCharacter.Humanoid:TakeDamage(10)
                        end
                    end
                end
            end
        elseif targetCharacter.Parent.Name == "PlayerCharacters" then
            local weaponType = playerReplica.equipment.weapon
            local attackNumber = playerEntity.Data.weapon.attackNumber

            local attackerCharacter = player.Character
            local targetPlayer = Players:GetPlayerFromCharacter(targetCharacter)

            local attackerHumanoidRootPart = attackerCharacter and attackerCharacter:FindFirstChild("HumanoidRootPart")
            local targetHumanoidRootPart = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")

            if targetPlayer and targetHumanoidRootPart and attackerCharacter and attackerHumanoidRootPart then
                local targetRollbackData = CombatManager.playerPositions[targetPlayer]
                local attackerRollbackData = CombatManager.playerPositions[player]

                if targetRollbackData and targetRollbackData.rollbackPositions and attackerRollbackData and attackerRollbackData.rollbackPositions then
                    local targetIndex
                    local attackerIndex

                    for i, positionData in ipairs(attackerRollbackData.rollbackPositions) do
                        if positionData.timeStamp <= timeStamp then
                            attackerIndex = i
                            break
                        end
                    end

                    for i, positionData in ipairs(targetRollbackData.rollbackPositions) do
                        if positionData.timeStamp <= timeStamp then
                            targetIndex = i
                            break
                        end
                    end

                    if targetIndex and attackerIndex then
                        local targetHurtbox = Instance.new("Part")
                        targetHurtbox.Anchored = true
                        targetHurtbox.CanCollide = false
                        targetHurtbox.Parent = game.Workspace
                        targetHurtbox.Size = Vector3.new(4, 6, 2)
                        targetHurtbox.CFrame = targetRollbackData.rollbackPositions[targetIndex].cframe
                        targetHurtbox.Transparency = 1

                        local validHit
    
                        local simulatedHitbox = Hitbox.new(table.clone(WeaponData[weaponType].basicAttack[tonumber(attackNumber)]), {
                            scan = true,
                            onScan = function(hitData, handler)
    							validHit = hitData
                                targetHurtbox:Destroy()
                                handler:Destroy()
                            end,
                            whiteList = {targetHurtbox},
                            attachTarget = targetRollbackData.rollbackPositions[attackerIndex].cframe,
                        })
                        
                        local scanTask = task.spawn(function()
                            task.wait()
                            simulatedHitbox:Stop()
                        end)

                        simulatedHitbox:Play(true):Wait()
                        if scanTask then
                            task.cancel(scanTask)               
                        end
                        
                        if validHit then
                            print("Hit validated for character:", targetCharacter.Name, "from player:", player.Name) 

                            local targetReplica = PlayerEntityManager.new(targetPlayer, true).Replica
                            print(targetReplica.Data.weapon.blocking)
                            if targetReplica.Data.weapon.blocking then
                                print("Blocking attack for character:", targetCharacter.Name)
                            else
                                print("Dealing damage to target character:", targetCharacter.Name)
								targetCharacter.Humanoid:TakeDamage(10)
                            end
                        end
                    end
                end
            end
        end
    end
end)

RequestAttack:On(function(player, timeStamp, attackData)
    if CombatManager[attackData.attackType] ~= nil then
        CombatManager[attackData.attackType](player, timeStamp, attackData)
    end
end)

FromAI:Connect(function(character, bufferData)
	local data = BufferUtils.readFromClientSimplified(bufferData)

	CombatManager.aiPositions[character] = CombatManager.aiPositions[character]
		or {
			rollbackPositions = {},
			lastUpdate = tick(),
		}

	table.insert(CombatManager.aiPositions[character].rollbackPositions, {
		timeStamp = data.t,
		cframe = data.c,
	})

	table.sort(CombatManager.aiPositions[character].rollbackPositions, function(a, b)
		return a.timeStamp < b.timeStamp
	end)

	if #CombatManager.aiPositions[character].rollbackPositions > CombatManager.rollbackFrames then
		table.remove(CombatManager.aiPositions[character].rollbackPositions, 1)
	end

	CombatManager.aiPositions[character].lastUpdate = tick()
end)

FromClient.OnServerEvent:Connect(function(player, bufferData)
    local data = BufferUtils.readFromClientSimplified(bufferData)

	if sanityFunc then
		local res = sanityFunc(data)
		if not res then
			return
		end
	end

    CombatManager.playerPositions[player] =  CombatManager.playerPositions[player] or {
        rollbackPositions = {},
        lastUpdate = tick(),
    }

    table.insert(CombatManager.playerPositions[player].rollbackPositions, {
        timeStamp = data.t,
        cframe = data.c,
    })

    table.sort(CombatManager.playerPositions[player].rollbackPositions, function(a, b)
        return a.timeStamp < b.timeStamp
    end)

    if #CombatManager.playerPositions[player].rollbackPositions > CombatManager.rollbackFrames then
        table.remove(CombatManager.playerPositions[player].rollbackPositions, 1)
    end

    CombatManager.playerPositions[player].lastUpdate = tick()
end)

for _, player in ipairs(Players:GetPlayers()) do
    CombatManager:InitializePlayer(player)
end

Players.PlayerAdded:Connect(function(player)
	CombatManager:InitializePlayer(player)
end)

Players.PlayerRemoving:Connect(function(player)
    CombatManager.playerPositions[player] = nil
end)

task.spawn(function()
    while true do
        if CombatManager.visualize == false then
            break
        end
		for player, playerData in pairs(CombatManager.playerPositions) do
			for index, positionData in ipairs(playerData) do
                Gizmo.PushProperty("AlwaysOnTop", true)
				Gizmo.PushProperty("Transparency", 0)
				Gizmo.PushProperty(
					"Color3",
					ScriptUtils:LerpBetweenThreeColors(
                        Color3.fromRGB(255, 230, 0),   -- Warm orange
                        Color3.fromRGB(255, 120, 0),  -- Purple transition
                        Color3.fromRGB(50, 0, 120),    -- Dark blue/purple
						index / #playerData
					)
				)
				Gizmo.VolumeSphere:Draw(positionData.cframe, 1)
			end
		end

        for character, aiData in pairs(CombatManager.aiPositions) do
            for index, positionData in ipairs (aiData) do
				Gizmo.PushProperty("AlwaysOnTop", true)
				Gizmo.PushProperty("Transparency", 0)
				Gizmo.PushProperty(
					"Color3",
					ScriptUtils:LerpBetweenThreeColors(
						Color3.fromRGB(255, 230, 0), -- Warm orange
						Color3.fromRGB(255, 120, 0), -- Purple transition
						Color3.fromRGB(50, 0, 120), -- Dark blue/purple
						index / #aiData
					)
				)
				Gizmo.VolumeSphere:Draw(positionData.cframe, 1)
            end
        end

        task.wait()
    end
end)

return CombatManager