local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = game:GetService("ReplicatedStorage").Shared

local Fusion = require(Shared.Fusion)
local FusionTypes = require(Shared.Fusion.Types)
local SharedConstants = require(Shared.Constants)

local Spring = Fusion.Spring
local Value = Fusion.Value
local Tween = Fusion.Tween

type WeightedChanceInfo = {
    weight: number,
    object: any,
    chance: number?,
    index: (number | string)?
}

type WeightedRandomDictionary = { [number | string]: WeightedChanceInfo }

type WeightedRandomResult = {
    chance: number,
    index: number | string,
    object: any,
    weight: number
}

local ScriptUtils = {
    daySeedOffset = 16 :: number,
    weekSeedOffset = 0 :: number,
    unitCopyStoreName = "unitCopyStore_testing_1" :: string
}

function ScriptUtils:Lerp(Min: number, Max: number, Alpha: number): number
    return Min + ((Max - Min) * Alpha)
end

function ScriptUtils:InverseLerp(value: number, min: number, max: number): number
    return (value / 100) * (max - min) + min
end

function ScriptUtils:Snap90(vector: Vector3): string
    local absX = math.abs(vector.X)
    local absZ = math.abs(vector.Z)

    if absX > absZ then
        return vector.X > 0 and "right" or "left"
    else
        return vector.Z > 0 and "down" or "up"
    end
end

function ScriptUtils:LerpAngle(start: number, target: number, alpha: number): number
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

function ScriptUtils:GetAverageNumberSequenceValue(numberSequence: NumberSequence): number?
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

function ScriptUtils:Abbreve(n: number): string
    local abbrevs = {"", "k", "m", "b", "t", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "speed", "Ocd", "Nod", "Vg", "Uvg"}
    if n == 0 then return "0" end
    local order = math.max(0, math.floor((math.log10(math.abs(n))) / 3))
    order = math.min(order, #abbrevs - 1) -- ensure the order does not exceed the abbrevs array length
    local significant_value = n / (10 ^ (order * 3))
    return string.format("%.3g%s", significant_value, abbrevs[order + 1])
end

function ScriptUtils:RoundTosignificantFigures(number: number, sigFigs: number): number
    if number == 0 then
        return 0
    end
    
    local orderOfMagnitude = 10 ^ (sigFigs - math.floor(math.log10(math.abs(number))) - 1)
    return math.floor(number * orderOfMagnitude) / orderOfMagnitude
end

function ScriptUtils:CreateSpring<T>(s: FusionTypes.Scope<T>, Properties: { initial: T, speed: number, damper: number }): { Value: FusionTypes.Value<T>, Spring: FusionTypes.Spring<T> }
    local SetValue = s:Value(Properties.Initial)
    local SetSpring = s:Spring(SetValue, Properties.Speed, Properties.Damper)

    return {
        Value = SetValue,
        Spring = SetSpring,
    }
end

function ScriptUtils:CreateTween<T>(s: FusionTypes.Scope<T>, Properties: { Initial: T, tweenInfo: TweenInfo? }): { Value: FusionTypes.Value<T>, Tween: FusionTypes.Tween<T> }
    local SetValue = s:Value(Properties.Initial)
    local SetTween = s:Tween(SetValue, Properties.tweenInfo)

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

function ScriptUtils:WeightedRandom(Dictionary: WeightedRandomDictionary, randomSeed: Random?, ReturnObject: boolean?): any | WeightedRandomResult | nil
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

function ScriptUtils:DeepCompare(t1: any, t2: any, ignore_mt: boolean?): boolean
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

function ScriptUtils:DeepCopy<T>(original: T): T
    local copy = {}
    for k, v in pairs(original :: any) do
        if type(v) == "table" then
            v = ScriptUtils:DeepCopy(v)
        end
        copy[k] = v
    end
    return copy :: any
end

function ScriptUtils:MergeTables<T, U>(t1: T, t2: U): T & U
    local Result = {}

    for key, value in pairs(t1 :: any) do
        Result[key] = value
    end

    for key, value in pairs(t2 :: any) do
        Result[key] = value
    end
  
    return Result :: any
end

function ScriptUtils:Extractnumbers(str: string): {number}
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

function ScriptUtils:WeldAttachments(attach1: Attachment, attach2: Attachment): Weld
    local weld = Instance.new("Weld")
    weld.Part0 = attach1.Parent :: BasePart
    weld.Part1 = attach2.Parent :: BasePart
    weld.C0 = attach1.CFrame
    weld.C1 = attach2.CFrame
    weld.Parent = attach1.Parent
    return weld
end
 
function ScriptUtils:BuildWeld(weldName: string, parent: Instance, part0: BasePart, part1: BasePart, c0: CFrame, c1: CFrame): Weld
    local weld = Instance.new("Weld")
    weld.Name = weldName
    weld.Part0 = part0
    weld.Part1 = part1
    weld.C0 = c0
    weld.C1 = c1
    weld.Parent = parent
    return weld
end
 
function ScriptUtils:FindFirstMatchingAttachment(model: Instance, name: string): Attachment?
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
    return nil
end

function ScriptUtils:AddAccoutrement(character: Model, accoutrement: Accoutrement): ()
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
                self:BuildWeld("HeadWeld", head, head :: BasePart, handle :: BasePart, attachmentCFrame, hatCFrame)
            end
        end
    end
end

function ScriptUtils:FlatVec3(Vec3: Vector3): Vector3
    return Vector3.new(Vec3.X, 0, Vec3.Z)
end

function ScriptUtils:LerpColor(color1: Color3, color2: Color3, t: number): Color3
    return color1:Lerp(color2, t)
end

function ScriptUtils:LerpBetweenThreeColors(color1: Color3, color2: Color3, color3: Color3, t: number): Color3
    if t < 0.5 then
        return ScriptUtils:LerpColor(color3, color2, t / 0.5)
    else
        return ScriptUtils:LerpColor(color2, color1, (t - 0.5) / 0.5)
    end
end 

function ScriptUtils:TableToString(v: any, shouldPrint: boolean?, spaces: number?, usesemicolon: boolean?, depth: number?): string
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

function ScriptUtils:GetNextValue<K, V>(t: {[K]: V}, key: K): V?
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

function ScriptUtils:GetOrdinalSuffix(number: number): string
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

function ScriptUtils:CapitalizeFirstLetter(str: string): string
    return (str:gsub("(%a)(%w*)", function(first, rest)
        return first:upper() .. rest:lower()
    end))
end

-- Calculate drying duration based on clay type, style, and optional multiplier
-- Formula: baseDryTime (clayType) × dryTimeMultiplier (style) × dryTimeMultiplier (station level)
function ScriptUtils:CalculateDryingDuration(clayType: string, styleKey: string, stationDryMultiplier: number?): number
    -- Get base dry time from clay type
    local clayTypeData = SharedConstants.clayTypes[clayType]
    local baseDryTime = clayTypeData and clayTypeData.baseDryTime or 120
    
    -- Get style multiplier
    local styleData = SharedConstants.pottteryData and SharedConstants.pottteryData[styleKey]
    local styleDryMultiplier = styleData and styleData.dryTimeMultiplier or 1.0
    
    -- Apply station level multiplier (e.g., from CoolingTable level stats)
    local stationMultiplier = stationDryMultiplier or 1.0
    
    return math.floor(baseDryTime * styleDryMultiplier * stationMultiplier)
end

-- Calculate cooling duration based on clay type, style, and optional multiplier
-- Formula: baseCoolTime (clayType) × coolTimeMultiplier (style) × coolTimeMultiplier (station level)
function ScriptUtils:CalculateCoolingDuration(clayType: string, styleKey: string, stationCoolMultiplier: number?): number
    -- Get base cool time from clay type
    local clayTypeData = SharedConstants.clayTypes[clayType]
    local baseCoolTime = clayTypeData and clayTypeData.baseCoolTime or 60
    
    -- Get style multiplier
    local styleData = SharedConstants.pottteryData and SharedConstants.pottteryData[styleKey]
    local styleCoolMultiplier = styleData and styleData.coolTimeMultiplier or 1.0
    
    -- Apply station level multiplier (e.g., from CoolingTable level stats)
    local stationMultiplier = stationCoolMultiplier or 1.0
    
    return math.floor(baseCoolTime * styleCoolMultiplier * stationMultiplier)
end

-- Calculate drying progress (0 to 1) based on start time and duration
function ScriptUtils:GetDryingProgress(dryingStartTime: number, dryingDuration: number): number
    if not dryingStartTime or not dryingDuration or dryingDuration <= 0 then
        return 0
    end
    
    local elapsed = os.time() - dryingStartTime
    local progress = math.clamp(elapsed / dryingDuration, 0, 1)
    return progress
end

-- Apply easing to a progress value
function ScriptUtils:ApplyEasing(progress: number, easingStyle: Enum.EasingStyle, easingDirection: Enum.EasingDirection): number
    -- Use TweenService's GetValue for accurate easing
    local TweenService = game:GetService("TweenService")
    return TweenService:GetValue(progress, easingStyle, easingDirection)
end

-- Get interpolated color for drying pottery
function ScriptUtils:GetDryingColor(clayType: string, dryingProgress: number): Color3
    local clayTypeInfo = SharedConstants.clayTypes[clayType]
    if not clayTypeInfo then
        clayTypeInfo = SharedConstants.clayTypes.normal
    end
    
    local startColor = clayTypeInfo.color
    local endColor = clayTypeInfo.driedColor
    local easeInfo = clayTypeInfo.colorChangeEase
    
    -- Apply easing to the progress
    local easedProgress = self:ApplyEasing(
        dryingProgress, 
        easeInfo.style or Enum.EasingStyle.Linear, 
        easeInfo.direction or Enum.EasingDirection.Out
    )
    
    -- Lerp between colors
    return startColor:Lerp(endColor, easedProgress)
end

-- Check if pottery is fully dried based on start time and duration
function ScriptUtils:IsDried(dryingStartTime: number, dryingDuration: number): boolean
    if not dryingStartTime or not dryingDuration then
        return false
    end
    
    local elapsed = os.time() - dryingStartTime
    return elapsed >= dryingDuration
end

return ScriptUtils