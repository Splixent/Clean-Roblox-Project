local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = game:GetService("ReplicatedStorage").Shared

local Fusion = require(Shared.Fusion)
local PubTypes = require(Shared.Fusion.PubTypes)
local SharedConstants = require(Shared.Constants)

local Spring = Fusion.Spring
local Value = Fusion.Value
local Tween = Fusion.Tween

local ScriptUtils = {
    daySeedOffset = 16,
    weekSeedOffset = 0,
    unitCopyStoreName = "unitCopyStore_testing_1"
}

function ScriptUtils:Lerp(Min: number, Max: number, Alpha: number): number
    return Min + ((Max - Min) * Alpha)
end

function ScriptUtils:InverseLerp(value: number, min: number, max: number): number
	return (value / 100) * (max - min) + min
end

function ScriptUtils:Snap90(vector)
	local absX = math.abs(vector.x)
	local absZ = math.abs(vector.z)

	if absX > absZ then
		return vector.x > 0 and "right" or "left"
	else
		return vector.z > 0 and "down" or "up"
	end
end


function ScriptUtils:LerpAngle(start: number, target: number, alpha: number)
    local difference = (target - start) % 360
    local distance = (2 * difference % 360) - difference
    return (start + distance * alpha) % 360
end

function ScriptUtils:Map(value: number, min: number, max: number, mintwo: number, maxtwo: number): number
	return (value - min) / (max - min) * (maxtwo - mintwo) + mintwo
end

function ScriptUtils:HMSFormat(Int: number): string
	return string.format("%02i", Int)
end

function ScriptUtils:GetAverageNumberSequenceValue(numberSequence)
	if typeof(numberSequence) ~= "NumberSequence" then
		return nil
	end

	local sum = 0
	local keypoints = numberSequence.Keypoints

	for _, keypoint in ipairs(keypoints) do
		sum = sum + keypoint.Value
	end

	return sum / #keypoints
end

function ScriptUtils:Abbreve(n)
    local abbrevs = {"", "k", "m", "b", "t", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "speed", "Ocd", "Nod", "Vg", "Uvg"}
    if n == 0 then return "0" end
    local order = math.max(0, math.floor((math.log10(math.abs(n))) / 3))
    order = math.min(order, #abbrevs - 1) -- ensure the order does not exceed the abbrevs array length
    local significant_value = n / (10 ^ (order * 3))
    return string.format("%.3g%s", significant_value, abbrevs[order + 1])
end

function ScriptUtils:RoundTosignificantFigures(number: number, sigFigs: number)
    if number == 0 then
        return 0
    end
    
    local orderOfMagnitude = 10 ^ (sigFigs - math.floor(math.log10(math.abs(number))) - 1)
    return math.floor(number * orderOfMagnitude) / orderOfMagnitude
end

function ScriptUtils:CreateSpring<T>(Properties: { Initial: PubTypes.Spring<T>, Speed: number, Damper: number }): any
    local SetValue = Value(Properties.Initial)
    local SetSpring = Spring(SetValue, Properties.Speed, Properties.Damper)

    return {
        Value = SetValue,
        Spring = SetSpring,
    }
end

function ScriptUtils:CreateTween<T>(Properties: { Initial: PubTypes.Spring<T>, tweenInfo: TweenInfo?}): any
    local SetValue = Value(Properties.Initial)
    local SetTween = Tween(SetValue, Properties.tweenInfo)

    return {
        Value = SetValue,
        Tween = SetTween,
    }
end

function ScriptUtils:ConvertTime(Seconds: number, formatType: string): string
    local formats = {
        DHMS = {"%02i:%02i:%02i:%02i", function(s)
            return math.floor(s / (60^2 * 24)), math.floor((s % (60^2 * 24)) / (60^2)), math.floor((s % (60^2)) / 60), s % 60
        end},
        DHMSPlus = {"%02id:%02ih:%02im:%02is", function(s)
            return math.floor(s / (60^2 * 24)), math.floor((s % (60^2 * 24)) / (60^2)), math.floor((s % (60^2)) / 60), s % 60
        end},
        DHM = {"%02i:%02i:%02i", function(s)
            return math.floor(s / (60^2 * 24)), math.floor((s % (60^2 * 24)) / (60^2)), math.floor((s % (60^2)) / 60)
        end},
        DHMPlus = {"%02id:%02ih:%02im", function(s)
            return math.floor(s / (60^2 * 24)), math.floor((s % (60^2 * 24)) / (60^2)), math.floor((s % (60^2)) / 60)
        end},
        HMS = {"%02i:%02i:%02i", function(s)
            return math.floor(s / 3600), math.floor((s % 3600) / 60), s % 60
        end},
        HMSPlus = {"%02ih:%02im:%02is", function(s)
            return math.floor(s / 3600), math.floor((s % 3600) / 60), s % 60
        end},
        HM = {"%02i:%02i", function(s)
            return math.floor(s / 3600), math.floor((s % 3600) / 60)
        end},
        HMPlus = {"%02ih:%02im", function(s)
            return math.floor(s / 3600), math.floor((s % 3600) / 60)
        end},
        MS = {"%02i:%02i", function(s)
            return math.floor(s / 60), s % 60
        end},
        MSPlus = {"%02im:%02is", function(s)
            return math.floor(s / 60), s % 60
        end}
    }

    local formatData = formats[formatType]
    if not formatData then
        error("Invalid format type specified")
    end

    local formatString, timeCalculator = formatData[1], formatData[2]
    return string.format(formatString, timeCalculator(Seconds))
end

function ScriptUtils:WeightedRandom(Dictionary, randomSeed: Random?, ReturnObject: boolean?): nil | any | { Chance: number, Index: number, Object: any, Weight: number }
	local totalWeight = 0
	for _, chanceInfo in pairs(Dictionary) do
		totalWeight = totalWeight + chanceInfo.weight
	end

	local randomnumber = if randomSeed ~= nil then randomSeed:NextNumber() * totalWeight else math.random() * totalWeight

	for index, chanceInfo in pairs(Dictionary) do
		if randomnumber <= chanceInfo.weight then
			chanceInfo.chance = chanceInfo.weight / totalWeight
			chanceInfo.index = index
			if ReturnObject == nil then
				return chanceInfo.object
			else
				return chanceInfo
			end
		else
			randomnumber = randomnumber - chanceInfo.weight
		end
	end

	return nil
end

function ScriptUtils:DeepCompare(t1: any, t2: any, ignore_mt: boolean?)
    local ty1 = type(t1)
    local ty2 = type(t2)
    if ty1 ~= ty2 then return false end
    -- non-table types can be directly compared
    if ty1 ~= 'table' and ty2 ~= 'table' then return t1 == t2 end
    -- as well as tables which have the metamethod __eq
    local mt = getmetatable(t1)
    if not ignore_mt and mt and mt.__eq then return t1 == t2 end
    for k1, v1 in pairs(t1) do
        local v2 = t2[k1]
        if v2 == nil or not ScriptUtils:DeepCompare(v1, v2) then return false end
    end
    for k2, v2 in pairs(t2) do
        local v1 = t1[k2]
        if v1 == nil or not ScriptUtils:DeepCompare(v1, v2) then return false end
    end
    return true
end

function ScriptUtils:DeepCopy(original: any): any
	local copy = {}
	for k, v in pairs(original) do
		if type(v) == "table" then
			v = ScriptUtils:DeepCopy(v)
		end
		copy[k] = v
	end
	return copy
end

function ScriptUtils:MergeTables(t1: any, t2: any): any
	local Result = {}

	for key, value in pairs(t1) do
		Result[key] = value
	end

	for key, value in pairs(t2) do
		Result[key] = value
	end
  
	return Result
end

function ScriptUtils:Extractnumbers(str)
    local numbers = {}
    for number in string.gmatch(str, "%d+") do
        table.insert(numbers, tonumber(number))
    end
    return numbers
end

function ScriptUtils:StringToBool(str: string): boolean
	return string.lower(str or "") == "true"
end

function ScriptUtils:CommaValue(amount: number): string
	local formatted = tostring(amount)
	local k
	while true do  
	  formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
	  if (k==0) then
		break
	  end
	end
	return formatted
end

function ScriptUtils:GetSourceModule(): string
	return string.split(debug.info(2, "s"), ".")[#string.split(debug.info(2, "s"), ".")]
end

function ScriptUtils:WeldAttachments(attach1, attach2)
    local weld = Instance.new("Weld")
    weld.Part0 = attach1.Parent
    weld.Part1 = attach2.Parent
    weld.C0 = attach1.CFrame
    weld.C1 = attach2.CFrame
    weld.Parent = attach1.Parent
    return weld
end
 
function ScriptUtils:BuildWeld(weldName, parent, part0, part1, c0, c1)
    local weld = Instance.new("Weld")
    weld.Name = weldName
    weld.Part0 = part0
    weld.Part1 = part1
    weld.C0 = c0
    weld.C1 = c1
    weld.Parent = parent
    return weld
end
 
function ScriptUtils:FindFirstMatchingAttachment(model, name)
    for _, child in pairs(model:GetChildren()) do
        if child:IsA("Attachment") and child.Name == name then
            return child
        elseif not child:IsA("Accoutrement") and not child:IsA("Tool") then -- Don't look in hats or tools in the character
            local foundAttachment = self:FindFirstMatchingAttachment(child, name)
            if foundAttachment then
                return foundAttachment
            end
        end
    end
end

function ScriptUtils:AddAccoutrement(character, accoutrement)  
    accoutrement.Parent = character
    local handle = accoutrement:FindFirstChild("Handle")
    if handle then
        local accoutrementAttachment = handle:FindFirstChildOfClass("Attachment")
        if accoutrementAttachment then
            local characterAttachment = self:FindFirstMatchingAttachment(character, accoutrementAttachment.Name)
            if characterAttachment then
                self:WeldAttachments(characterAttachment, accoutrementAttachment)
            end
        else
            local head = character:FindFirstChild("Head")
            if head then
                local attachmentCFrame = CFrame.new(0, 0.5, 0)
                local hatCFrame = accoutrement.AttachmentPoint
                self:BuildWeld("HeadWeld", head, head, handle, attachmentCFrame, hatCFrame)
            end
        end
    end
end

function ScriptUtils:FlatVec3(Vec3)
    return Vector3.new(Vec3.X, 0, Vec3.Z)
end

function ScriptUtils:LerpColor(color1, color2, t)
    return color1:Lerp(color2, t)
end

function ScriptUtils:LerpBetweenThreeColors(color1, color2, color3, t)
    if t < 0.5 then
        return ScriptUtils:LerpColor(color3, color2, t / 0.5)
    else
        return ScriptUtils:LerpColor(color2, color1, (t - 0.5) / 0.5)
    end
end 

function ScriptUtils:TableToString(v, shouldPrint, spaces, usesemicolon, depth)
	if type(v) ~= 'table' then
		return tostring(v)
	elseif not next(v) then
		return '{}'
	end

	spaces = spaces or 4
	depth = depth or 1

	local space = (" "):rep(depth * spaces)
	local sep = usesemicolon and ";" or ","
	local concatenationBuilder = {"{"}
	
	for k, x in next, v do
		table.insert(concatenationBuilder, ("\n%s[%s] = %s%s"):format(space,type(k)=='number'and tostring(k)or('"%s"'):format(tostring(k)), ScriptUtils:TableToString(x, spaces, usesemicolon, depth+1), sep))
	end

	local s = table.concat(concatenationBuilder)
    if shouldPrint then print(("%s\n%s}"):format(s:sub(1,-2), space:sub(1, -spaces-1))) end
    return ("%s\n%s}"):format(s:sub(1,-2), space:sub(1, -spaces-1))
end

function ScriptUtils:GetNextValue(t, key)
    local firstKey = nil
    local found = false
    local resultKey = nil

    for k, v in pairs(t) do
        if not firstKey then
            firstKey = k  -- Store the first key in case we need to wrap around
        end
        if found then
            resultKey = k
            break
        end
        if k == key then
            found = true
        end
    end

    if found and not resultKey then
        resultKey = firstKey  -- Wrap around to the first key
    end
    return resultKey and t[resultKey] or nil
end

function ScriptUtils:GetIndexOfInstance(t: {Instance}, name: string): number?
	for i, v in pairs(t) do
		if v.Name == name then return i end 
	end
	return nil
end

function ScriptUtils:GetOrdinalSuffix(number)
    local suffix = "th"
    local lastDigit = number % 10
    local lastTwoDigits = number % 100

    if lastTwoDigits ~= 11 and lastTwoDigits ~= 12 and lastTwoDigits ~= 13 then
        if lastDigit == 1 then
            suffix = "st"
        elseif lastDigit == 2 then
            suffix = "nd"
        elseif lastDigit == 3 then
            suffix = "rd"
        end
    end

    return ScriptUtils:CommaValue(number)..suffix
end

function ScriptUtils:CapitalizeFirstLetter(str)
    return (str:gsub("(%a)(%w*)", function(first, rest)
        return first:upper() .. rest:lower()
    end))
end

return ScriptUtils