local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Client = Players.LocalPlayer.PlayerScripts.Client

local ScriptUtils = require(Shared.ScriptUtils)
local Events = require(Shared.Events)
local Maid = require(Shared.Maid)
local Fusion = require(Shared.Fusion)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local Value = Fusion.Value
local Computed = Fusion.Computed
local Spring = Fusion.Spring
local peek = Fusion.peek

local LocalPlayer = Players.LocalPlayer

-- Stack configuration
local STACK_KEYS = {
	{ keyboard = Enum.KeyCode.E, gamepad = Enum.KeyCode.DPadUp, display = "E", gamepadDisplay = "▲" },
	{ keyboard = Enum.KeyCode.R, gamepad = Enum.KeyCode.DPadRight, display = "R", gamepadDisplay = "►" },
	{ keyboard = Enum.KeyCode.F, gamepad = Enum.KeyCode.DPadDown, display = "F", gamepadDisplay = "▼" },
	{ keyboard = Enum.KeyCode.C, gamepad = Enum.KeyCode.DPadLeft, display = "C", gamepadDisplay = "◄" },
}
local STACK_OFFSET = 1.5 -- Studs between stacked prompts
local SIMPLE_STACK_GAP = 1.5 -- Vertical gap between simple prompts in their stack
local SIMPLE_HORIZONTAL_OFFSET = 5.8 -- Studs to push simple prompts to the right
local SIMPLE_VERTICAL_OFFSET = 0 -- Base vertical offset for all simple prompts (positive = up, negative = down)

-- Dynamic offset adjustment (can be modified externally)
local SimpleHorizontalOffsetAdjustment = 0.1 -- Added to SIMPLE_HORIZONTAL_OFFSET when calculating position

-- Static registry for all active prompts
local ActivePrompts = {} -- { [prompt] = ProximityPromptManager }
local WantsToBeVisible = {} -- { [ProximityPromptManager] = true } -- Prompts that want to show but may be hidden due to key conflicts

-- Type definitions
export type PromptData = {
	objectText: string,
	actionText: string,
	holdDuration: number?,
	keyboardKeyCode: Enum.KeyCode?,
	gamepadKeyCode: Enum.KeyCode?,
	maxActivationDistance: number?,
	requiresLineOfSight: boolean?,
	priority: number?, -- Higher priority = assigned primary keys (E first), default 0
	simple: boolean?, -- Use compact circular prompt style
	left: boolean?, -- For simple prompts: position on left instead of right
	onTriggered: ((player: Player) -> ())?,
	onHoldBegan: ((player: Player) -> ())?,
	onHoldEnded: ((player: Player) -> ())?,
	onPromptHidden: ((player: Player) -> ())?,
}

local ProximityPromptManager = {}
ProximityPromptManager.__index = ProximityPromptManager

--[=[
	Gets the distance from the player's character to a position
	@param position Vector3
	@return number
]=]
local function getPlayerDistance(position: Vector3): number
	local character = LocalPlayer.Character
	if not character then
		return math.huge
	end
	
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return math.huge
	end
	
	return (rootPart.Position - position).Magnitude
end

--[=[
	Gets the world position of a prompt's parent/adornee
	@param parent Instance
	@return Vector3?
]=]
local function getParentPosition(parent: Instance): Vector3?
	if parent:IsA("BasePart") then
		return parent.Position
	elseif parent:IsA("Model") then
		local primaryPart = parent.PrimaryPart
		if primaryPart then
			return primaryPart.Position
		end
		-- Try to get position from any part
		local part = parent:FindFirstChildWhichIsA("BasePart")
		if part then
			return part.Position
		end
	elseif parent:IsA("Attachment") then
		return parent.WorldPosition
	end
	return nil
end

--[=[
	Gets nearby visible prompts for the same adornee/parent (uses WantsToBeVisible for consistency)
	@param parent Instance
	@return { ProximityPromptManager }
]=]
local function getPromptsForParent(parent: Instance): { any }
	local prompts = {}
	for prompt, manager in pairs(ActivePrompts) do
		if manager._parent == parent and WantsToBeVisible[manager] then
			table.insert(prompts, manager)
		end
	end
	return prompts
end

--[=[
	Updates visibility based on key conflicts - only the closest prompt with each key is shown
	Also assigns global key indices based on distance (closest gets primary keys E, R, F, C)
	This runs globally across all prompts that want to be visible
]=]
local function updateKeyConflicts()
	-- Collect all prompts that want to be visible with their distances
	local allPrompts = {}
	
	for manager, _ in pairs(WantsToBeVisible) do
		local position = getParentPosition(manager._parent)
		local distance = position and getPlayerDistance(position) or math.huge
		table.insert(allPrompts, {
			manager = manager,
			distance = distance,
		})
	end
	
	-- Sort by distance (closest first), then by priority (higher first), then by creation time
	table.sort(allPrompts, function(a, b)
		-- First by distance
		if math.abs(a.distance - b.distance) > 0.1 then
			return a.distance < b.distance
		end
		-- Then by priority (higher priority = more important)
		if a.manager._priority ~= b.manager._priority then
			return a.manager._priority > b.manager._priority
		end
		-- Finally by creation time
		return a.manager._creationTime < b.manager._creationTime
	end)
	
	-- Assign keys sequentially: closest prompt gets E (1), next gets R (2), etc.
	for i, promptData in ipairs(allPrompts) do
		local manager = promptData.manager
		local assignedKey = i -- Sequential assignment: 1st prompt = key 1 (E), 2nd = key 2 (R), etc.
		
		if assignedKey <= #STACK_KEYS then
			-- Update the manager's key
			local keyConfig = STACK_KEYS[assignedKey]
			if keyConfig then
				manager._stackIndex = assignedKey
				manager._prompt.KeyboardKeyCode = keyConfig.keyboard
				manager._prompt.GamepadKeyCode = keyConfig.gamepad
				manager._keyText:set(manager:_getKeyText())
			end
			
			-- Show this prompt
			if not manager._isVisible then
				manager._isVisible = true
				manager._visible:set(true)
				manager._transparency:set(0)
			end
		else
			-- No available keys (more than 4 prompts), hide this prompt
			if manager._isVisible then
				manager._isVisible = false
				manager._visible:set(false)
				manager._transparency:set(1)
				manager._holdProgress:set(0)
				manager:_stopButtonHold()
			end
		end
	end
end

--[=[
	Updates stack positions and keys for all visible prompts on a parent
	@param parent Instance
]=]
local function updateStackForParent(parent: Instance)
	local prompts = getPromptsForParent(parent)
	
	-- Separate regular, simple-left, and simple-right prompts
	local regularPrompts = {}
	local simpleLeftPrompts = {}
	local simpleRightPrompts = {}
	
	for _, manager in ipairs(prompts) do
		if manager._simple then
			if manager._left then
				table.insert(simpleLeftPrompts, manager)
			else
				table.insert(simpleRightPrompts, manager)
			end
		else
			table.insert(regularPrompts, manager)
		end
	end
	
	-- Sort regular prompts by priority (descending), then by creation time (ascending)
	table.sort(regularPrompts, function(a, b)
		if a._priority ~= b._priority then
			return a._priority > b._priority -- Higher priority first
		end
		return a._creationTime < b._creationTime -- Earlier creation first for same priority
	end)
	
	-- Sort simple-left prompts by priority (descending), then by creation time (ascending)
	table.sort(simpleLeftPrompts, function(a, b)
		if a._priority ~= b._priority then
			return a._priority > b._priority -- Higher priority first
		end
		return a._creationTime < b._creationTime -- Earlier creation first for same priority
	end)
	
	-- Sort simple-right prompts by priority (descending), then by creation time (ascending)
	table.sort(simpleRightPrompts, function(a, b)
		if a._priority ~= b._priority then
			return a._priority > b._priority -- Higher priority first
		end
		return a._creationTime < b._creationTime -- Earlier creation first for same priority
	end)
	
	-- Assign stack positions to regular prompts (vertically stacked at top)
	local totalRegular = #regularPrompts
	for i, manager in ipairs(regularPrompts) do
		local stackIndex = math.min(i, #STACK_KEYS)
		manager:_setStackPosition(i, stackIndex, totalRegular, 0, false)
	end
	
	-- Assign stack positions to simple-left prompts (separate stack on the left)
	local totalSimpleLeft = #simpleLeftPrompts
	local keyOffsetLeft = #regularPrompts -- Left simple prompts get keys after regular prompts
	for i, manager in ipairs(simpleLeftPrompts) do
		local stackIndex = math.min(keyOffsetLeft + i, #STACK_KEYS)
		manager:_setStackPosition(i, stackIndex, totalSimpleLeft, 0, #regularPrompts > 0)
	end
	
	-- Assign stack positions to simple-right prompts (separate stack on the right)
	local totalSimpleRight = #simpleRightPrompts
	local keyOffsetRight = #regularPrompts + #simpleLeftPrompts -- Right simple prompts get keys after regular and left simple
	for i, manager in ipairs(simpleRightPrompts) do
		local stackIndex = math.min(keyOffsetRight + i, #STACK_KEYS)
		manager:_setStackPosition(i, stackIndex, totalSimpleRight, 0, #regularPrompts > 0)
	end
end

--[=[
	Creates a new custom proximity prompt
	@param parent Instance -- The instance to attach the proximity prompt to
	@param promptData PromptData -- Configuration for the prompt
	@return ProximityPromptObject
]=]
function ProximityPromptManager.new(parent: Instance, promptData: PromptData)
	local self = setmetatable({}, ProximityPromptManager)
	
	self._maid = Maid.new()
	self._parent = parent
	self._promptData = promptData
	self._isVisible = false
	self._currentInputType = "Keyboard"
	self._creationTime = tick()
	self._stackPosition = 1
	self._stackIndex = 1
	self._priority = promptData.priority or 0 -- Higher priority = assigned primary keys first
	self._simple = promptData.simple or false -- Use compact circular prompt style
	self._left = promptData.left or false -- For simple prompts: position on left instead of right
	
	-- Create the ProximityPrompt
	self._prompt = Instance.new("ProximityPrompt")
	self._prompt.Style = Enum.ProximityPromptStyle.Custom
	self._prompt.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow -- Allow multiple prompts
	self._prompt.ObjectText = promptData.objectText or ""
	self._prompt.ActionText = promptData.actionText or "Interact"
	self._prompt.HoldDuration = 0 -- We handle hold duration ourselves
	self._holdDuration = promptData.holdDuration or 0 -- Store for our custom handling
	self._prompt.KeyboardKeyCode = promptData.keyboardKeyCode or Enum.KeyCode.E
	self._prompt.GamepadKeyCode = promptData.gamepadKeyCode or Enum.KeyCode.ButtonX
	self._prompt.MaxActivationDistance = promptData.maxActivationDistance or 5
	self._prompt.RequiresLineOfSight = promptData.requiresLineOfSight ~= nil
	self._prompt.Parent = parent
	self._maid:GiveTask(self._prompt)
	
	-- Store original keys (may be overridden by stacking)
	self._originalKeyboardKey = self._prompt.KeyboardKeyCode
	self._originalGamepadKey = self._prompt.GamepadKeyCode
	
	-- Register in active prompts
	ActivePrompts[self._prompt] = self
	
	-- Create Fusion scope for reactive UI
	self._scope = Fusion.scoped(Fusion)
	local s = self._scope
	
	-- Reactive state
	self._holdProgress = s:Value(0)
	self._visible = s:Value(false)
	self._transparency = s:Value(1)
	self._keyText = s:Value(self:_getKeyText())
	self._buttonScale = s:Value(1)
	self._promptScale = s:Value(1)
	self._stackOffset = s:Value(0) -- Y offset for stacking
	self._stackHorizontalOffset = s:Value(0) -- X offset for simple prompt horizontal alignment
	self._customHorizontalOffset = promptData.customHorizontalOffset or 0 -- Per-prompt adjustment (added to base offset)
	self._isHoldingButton = false
	self._hasTriggered = false -- Prevents re-triggering while key is still held
	self._onCooldown = false -- Blocks all interaction during cooldown
	
	-- Animated values
	self._animatedTransparency = s:Spring(self._transparency, 20, 0.9)
	self._animatedProgress = s:Spring(self._holdProgress, 30, 1)
	self._animatedButtonScale = s:Spring(self._buttonScale, 35, 0.7)
	self._animatedPromptScale = s:Spring(self._promptScale, 25, 0.8)
	self._animatedStackOffset = s:Spring(self._stackOffset, 20, 0.8)
	self._animatedStackHorizontalOffset = s:Spring(self._stackHorizontalOffset, 20, 0.8)
	
	-- Create the UI
	self:_createUI()
	
	-- Connect prompt events
	self:_connectEvents()
	
	-- Listen for input type changes
	self._maid:GiveTask(UserInputService.LastInputTypeChanged:Connect(function(inputType)
		self:_onInputTypeChanged(inputType)
	end))
	
	-- Listen for keyboard input (current assigned key)
	self._maid:GiveTask(UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if input.KeyCode == self._prompt.KeyboardKeyCode and self._isVisible then
			self:_startButtonHold()
		end
	end))
	
	self._maid:GiveTask(UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if input.KeyCode == self._prompt.KeyboardKeyCode then
			self:_stopButtonHold()
		end
	end))
	
	return self
end

--[=[
	Gets the display text for the current input key
	@return string
]=]
function ProximityPromptManager:_getKeyText(): string
	local inputType = UserInputService:GetLastInputType()
	local keyConfig = STACK_KEYS[self._stackIndex]
	
	if inputType == Enum.UserInputType.Gamepad1 then
		self._currentInputType = "Gamepad"
		if keyConfig then
			return keyConfig.gamepadDisplay
		end
		local keyCode = self._prompt.GamepadKeyCode
		if keyCode == Enum.KeyCode.ButtonX then return "X"
		elseif keyCode == Enum.KeyCode.ButtonY then return "Y"
		elseif keyCode == Enum.KeyCode.ButtonA then return "A"
		elseif keyCode == Enum.KeyCode.ButtonB then return "B"
		else return keyCode.Name end
	else
		self._currentInputType = "Keyboard"
		if keyConfig then
			return keyConfig.display
		end
		local keyCode = self._prompt.KeyboardKeyCode
		return keyCode.Name
	end
end

--[=[
	Handles input type changes to update the key display
]=]
function ProximityPromptManager:_onInputTypeChanged(inputType: Enum.UserInputType)
	self._keyText:set(self:_getKeyText())
end

--[=[
	Creates the custom UI for the proximity prompt
]=]
function ProximityPromptManager:_createUI()
	local s = self._scope
	
	-- Computed gradient for hold progress
	local progressGradient = s:Computed(function(use)
		local progress = use(self._animatedProgress)
		
		-- Fully transparent when not holding
		if progress <= 0.001 then
			return NumberSequence.new(1)
		end
		
		local midPoint = math.clamp(progress, 0.001, 0.999)
		
		return NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(math.max(0.001, midPoint - 0.005), 0),
			NumberSequenceKeypoint.new(math.min(0.999, midPoint + 0.005), 1),
			NumberSequenceKeypoint.new(1, 1),
		})
	end)
	
	-- Choose UI based on simple mode
	if self._simple then
		self:_createSimpleUI(s, progressGradient)
	else
		self:_createStandardUI(s, progressGradient)
	end
end

--[=[
	Creates the simple/compact circular UI
]=]
function ProximityPromptManager:_createSimpleUI(s, progressGradient)
	-- Position values - mirrored when left is true
	local buttonPosX = self._left and (1 - 0.157479) or 0.157479
	local textPosX = self._left and (1 - 0.3) or 0.3
	local textAnchorX = self._left and 1 or 0
	local textAlignment = self._left and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left
	
	-- Main BillboardGui for simple prompt
	self._billboardGui = s:New "BillboardGui" {
		Name = "CustomProximityPromptSimple",
		Active = true,
		Size = UDim2.fromScale(6.7, 2),
		StudsOffset = s:Computed(function(use)
			local yOffset = use(self._animatedStackOffset)
			local xOffset = use(self._animatedStackHorizontalOffset)
			return Vector3.new(xOffset, 2 + yOffset, 0)
		end),
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = math.huge,
		Adornee = self._parent,
		Parent = LocalPlayer:WaitForChild("PlayerGui").UI.ProximityPrompts,
		
		[Children] = {
			s:New "CanvasGroup" {
				Name = "Container",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
				GroupTransparency = self._animatedTransparency,
				
				[Children] = {
					s:New "Frame" {
						Name = "ProximityPromptSimple",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.5, 0.5),
						Size = s:Computed(function(use)
							local scale = use(self._animatedPromptScale)
							return UDim2.fromScale(scale, scale)
						end),
						
						[Children] = {
							-- Background
							s:New "ImageLabel" {
								Name = "Background",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								Image = "rbxassetid://99448744269230",
								ImageTransparency = 0.3,
								Position = UDim2.fromScale(buttonPosX, 0.5),
								ScaleType = Enum.ScaleType.Slice,
								Size = UDim2.fromScale(0.21, 0.72),
								SliceCenter = Rect.new(512, 512, 512, 512),
								ZIndex = -1,
							},
							
							-- Progress Overlay
							s:New "ImageLabel" {
								Name = "Overlay",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								Image = "rbxassetid://99448744269230",
								ImageTransparency = 0.38,
								Position = UDim2.fromScale(buttonPosX, 0.5),
								ScaleType = Enum.ScaleType.Slice,
								Size = UDim2.fromScale(0.21, 0.72),
								SliceCenter = Rect.new(512, 512, 512, 512),
								ZIndex = 3,
								
								[Children] = {
									s:New "UIGradient" {
										Name = "UIGradient",
										Color = ColorSequence.new({
											ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 22, 22)),
											ColorSequenceKeypoint.new(1, Color3.fromRGB(22, 22, 22)),
										}),
										Transparency = progressGradient,
									},
								}
							},
							
							-- Button Stroke
							s:New "ImageLabel" {
								Name = "ButtonStroke",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								Image = "rbxassetid://132440398359005",
								ImageColor3 = Color3.fromRGB(113, 113, 113),
								Position = UDim2.fromScale(buttonPosX, 0.5),
								ScaleType = Enum.ScaleType.Slice,
								Size = s:Computed(function(use)
									local scale = use(self._animatedButtonScale)
									return UDim2.fromScale(0.175 * scale, 0.6 * scale)
								end),
								SliceCenter = Rect.new(512, 512, 512, 512),
								ZIndex = 0,
							},
							
							-- Button Icon with Key (ImageButton for click interaction)
							s:New "ImageButton" {
								Name = "ButtonIcon",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								Image = "rbxassetid://123413392379402",
								Position = UDim2.fromScale(buttonPosX, 0.5),
								Size = s:Computed(function(use)
									local scale = use(self._animatedButtonScale)
									return UDim2.fromScale(0.145 * scale, 0.5 * scale)
								end),
								
								[OnEvent "MouseButton1Down"] = function()
									self:_startButtonHold()
								end,
								
								[OnEvent "MouseButton1Up"] = function()
									self:_stopButtonHold()
								end,
								
								[OnEvent "MouseLeave"] = function()
									self:_stopButtonHold()
								end,
								
								[Children] = {
									s:New "TextLabel" {
										Name = "Key",
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundTransparency = 1,
										FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
										Position = UDim2.fromScale(0.5, 0.5),
										Size = UDim2.fromScale(0.755009, 0.755),
										Text = self._keyText,
										TextColor3 = Color3.new(1, 1, 1),
										TextScaled = true,
										
										[Children] = {
											s:New "UIStroke" {
												Name = "UIStroke",
												StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
												Thickness = 0.05,
												Transparency = 0.61,
											},
										}
									},
									
									s:New "UIGradient" {
										Name = "UIGradient",
										Rotation = 90,
										Transparency = NumberSequence.new({
											NumberSequenceKeypoint.new(0, 0),
											NumberSequenceKeypoint.new(1, 0.95625),
										}),
									},
								}
							},
							
							-- Background Stroke
							s:New "ImageLabel" {
								Name = "BackgroundStroke",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								Image = "rbxassetid://138803086803744",
								ImageColor3 = Color3.fromRGB(230, 230, 230),
								Position = UDim2.fromScale(buttonPosX, 0.5),
								ScaleType = Enum.ScaleType.Slice,
								Size = UDim2.fromScale(0.21, 0.72),
								SliceCenter = Rect.new(512, 512, 512, 512),
								ZIndex = -2,
							},
							
							-- Action Text (to the side of button)
							s:New "TextLabel" {
								Name = "ActionText",
								AnchorPoint = Vector2.new(textAnchorX, 0.5),
								BackgroundTransparency = 1,
								FontFace = Font.new(
									"rbxasset://fonts/families/HighwayGothic.json",
									Enum.FontWeight.Bold,
									Enum.FontStyle.Normal
								),
								Position = UDim2.fromScale(textPosX, 0.5),
								Size = UDim2.fromScale(0.6, 0.4),
								Text = self._promptData.actionText or "Interact",
								TextColor3 = Color3.new(1, 1, 1),
								TextScaled = true,
								TextXAlignment = textAlignment,
								
								[Children] = {
									s:New "UIStroke" {
										Name = "UIStroke",
										StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
										Thickness = 0.05,
										Transparency = 0.54,
									},
								}
							},
						}
					}
				}
			}
		}
	}
	
	self._maid:GiveTask(self._billboardGui)
end
	
--[=[
	Creates the standard/full UI with object and action text
]=]
function ProximityPromptManager:_createStandardUI(s, progressGradient)
	-- Main BillboardGui
	self._billboardGui = s:New "BillboardGui" {
		Name = "CustomProximityPrompt",
		Active = true,
		Size = UDim2.fromScale(5, 1.5),
		StudsOffset = s:Computed(function(use)
			local offset = use(self._animatedStackOffset)
			return Vector3.new(0, 2 + offset, 0)
		end),
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = math.huge, -- Don't cull by distance, we handle visibility via transparency
		Adornee = self._parent,
		Parent = LocalPlayer:WaitForChild("PlayerGui").UI.ProximityPrompts,
		
		[Children] = {
			s:New "CanvasGroup" {
				Name = "Container",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
				GroupTransparency = self._animatedTransparency,
				
				[Children] = {
					s:New "Frame" {
						Name = "ProximityPrompt",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.5, 0.5),
						Size = s:Computed(function(use)
							local scale = use(self._animatedPromptScale)
							return UDim2.fromScale(scale, scale)
						end),
						
						[Children] = {
							-- Background
							s:New "ImageLabel" {
								Name = "Background",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								Image = "rbxassetid://99448744269230",
								ImageTransparency = 0.3,
								Position = UDim2.fromScale(0.5, 0.5),
								ScaleType = Enum.ScaleType.Slice,
								Size = UDim2.fromScale(1, 1),
								SliceCenter = Rect.new(512, 512, 512, 512),
								ZIndex = -1,
							},
							
							-- Progress Overlay
							s:New "ImageLabel" {
								Name = "Overlay",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								Image = "rbxassetid://99448744269230",
								ImageTransparency = 0.38,
								Position = UDim2.fromScale(0.5, 0.5),
								ScaleType = Enum.ScaleType.Slice,
								Size = UDim2.fromScale(1, 1),
								SliceCenter = Rect.new(512, 512, 512, 512),
								ZIndex = 3,
								
								[Children] = {
									s:New "UIGradient" {
										Name = "UIGradient",
										Color = ColorSequence.new({
											ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 22, 22)),
											ColorSequenceKeypoint.new(1, Color3.fromRGB(22, 22, 22)),
										}),
										Transparency = progressGradient,
									},
								}
							},
							
							-- Action Text
							s:New "TextLabel" {
								Name = "ActionText",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								FontFace = Font.new(
									"rbxasset://fonts/families/HighwayGothic.json",
									Enum.FontWeight.Bold,
									Enum.FontStyle.Normal
								),
								Position = UDim2.fromScale(0.586575, 0.641193),
								Size = UDim2.fromScale(0.669315, 0.349339),
								Text = self._promptData.actionText or "Interact",
								TextColor3 = Color3.fromRGB(116, 116, 116),
								TextScaled = true,
								TextXAlignment = Enum.TextXAlignment.Right,
							},
							
							-- Object Text
							s:New "TextLabel" {
								Name = "ObjectText",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								FontFace = Font.new(
									"rbxasset://fonts/families/HighwayGothic.json",
									Enum.FontWeight.Bold,
									Enum.FontStyle.Normal
								),
								Position = UDim2.fromScale(0.591847, 0.329614),
								Size = UDim2.fromScale(0.655157, 0.259914),
								Text = self._promptData.objectText or "",
								TextColor3 = Color3.fromRGB(162, 162, 162),
								TextScaled = true,
								TextXAlignment = Enum.TextXAlignment.Right,
							},
							
							-- Button Stroke
							s:New "ImageLabel" {
								Name = "ButtonStroke",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								Image = "rbxassetid://132440398359005",
								ImageColor3 = Color3.fromRGB(113, 113, 113),
								Position = UDim2.fromScale(0.157479, 0.5),
								ScaleType = Enum.ScaleType.Slice,
                                Size = s:Computed(function(use)
									local scale = use(self._animatedButtonScale)
									return UDim2.fromScale(0.210005 * scale, 0.71941 * scale)
								end),
								SliceCenter = Rect.new(512, 512, 512, 512),
								ZIndex = 0,
							},
							
							-- Button Icon with Key (ImageButton for click interaction)
							s:New "ImageButton" {
								Name = "ButtonIcon",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								Image = "rbxassetid://123413392379402",
								Position = UDim2.fromScale(0.157342, 0.5),
								Size = s:Computed(function(use)
									local scale = use(self._animatedButtonScale)
									return UDim2.fromScale(0.175004 * scale, 0.599508 * scale)
								end),
								
								[OnEvent "MouseButton1Down"] = function()
									self:_startButtonHold()
								end,
								
								[OnEvent "MouseButton1Up"] = function()
									self:_stopButtonHold()
								end,
								
								[OnEvent "MouseLeave"] = function()
									self:_stopButtonHold()
								end,
								
								[Children] = {
									s:New "TextLabel" {
										Name = "Key",
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundTransparency = 1,
										FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
										Position = UDim2.fromScale(0.5, 0.5),
										Size = UDim2.fromScale(0.755009, 0.755),
										Text = self._keyText,
										TextColor3 = Color3.new(1, 1, 1),
										TextScaled = true,
										
										[Children] = {
											s:New "UIStroke" {
												Name = "UIStroke",
												StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
												Thickness = 0.05,
												Transparency = 0.61,
											},
										}
									},
									
									s:New "UIGradient" {
										Name = "UIGradient",
										Rotation = 90,
										Transparency = NumberSequence.new({
											NumberSequenceKeypoint.new(0, 0),
											NumberSequenceKeypoint.new(1, 0.95625),
										}),
									},
								}
							},
							
							-- Background Stroke
							s:New "ImageLabel" {
								Name = "BackgroundStroke",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								Image = "rbxassetid://138803086803744",
								ImageColor3 = Color3.fromRGB(230, 230, 230),
								Position = UDim2.fromScale(0.5, 0.5),
								ScaleType = Enum.ScaleType.Slice,
								Size = UDim2.fromScale(1, 1),
								SliceCenter = Rect.new(512, 512, 512, 512),
								ZIndex = -2,
							},
						}
					}
				}
			}
		}
	}
	
	self._maid:GiveTask(self._billboardGui)
end

--[=[
	Connects all proximity prompt events
]=]
function ProximityPromptManager:_connectEvents()
	-- Show prompt
	self._maid:GiveTask(self._prompt.PromptShown:Connect(function()
		self:_show()
	end))
	
	-- Hide prompt
	self._maid:GiveTask(self._prompt.PromptHidden:Connect(function()
		self:_hide()
	end))
	
	-- Note: We do NOT connect to Triggered, PromptButtonHoldBegan, or PromptButtonHoldEnded
	-- because we handle all interaction ourselves via UserInputService
	-- The native events fire incorrectly since we set HoldDuration = 0 on the prompt
end

--[=[
	Shows the proximity prompt UI
]=]
function ProximityPromptManager:_show()
	-- Mark that this prompt wants to be visible
	WantsToBeVisible[self] = true
	
	-- Initially set as visible (key conflicts will be resolved after)
	self._isVisible = true
	self._visible:set(true)
	self._transparency:set(0)
	
	-- Update stack for this parent (assigns keys)
	updateStackForParent(self._parent)
	
	-- Now resolve key conflicts across all prompts
	updateKeyConflicts()
end

--[=[
	Hides the proximity prompt UI
]=]
function ProximityPromptManager:_hide()
	-- Remove from wants-to-be-visible tracking
	WantsToBeVisible[self] = nil
	
	self._isVisible = false
	self._visible:set(false)
	self._transparency:set(1)
	self._holdProgress:set(0)
	
	-- Stop any button hold in progress
	self:_stopButtonHold()
	
	-- Call onPromptHidden callback
	if self._promptData.onPromptHidden then
		self._promptData.onPromptHidden(LocalPlayer)
	end
	
	-- Update stack for remaining prompts
	task.defer(function()
		updateStackForParent(self._parent)
		-- Re-check key conflicts - a hidden prompt may allow another to show
		updateKeyConflicts()
	end)
end

--[=[
	Sets the stack position for this prompt (called by stack manager)
	@param position number -- Visual position in stack (1 = top for regular, 1 = leftmost for simple)
	@param stackIndex number -- Index into STACK_KEYS for key binding
	@param totalPrompts number -- Total number of prompts in this category
	@param horizontalOffset number -- Horizontal offset for simple prompts (0 for regular)
	@param hasRegularAbove boolean -- Whether there are regular prompts above (for simple prompts gap)
]=]
function ProximityPromptManager:_setStackPosition(position: number, stackIndex: number, totalPrompts: number, horizontalOffset: number, hasRegularAbove: boolean)
	self._stackPosition = position
	self._stackIndex = stackIndex
	
	if self._simple then
		-- Simple prompts: to the right (or left) of regular prompts, vertically stacked among themselves
		-- X offset pushes them to the side, Y offset controlled by SIMPLE_VERTICAL_OFFSET + stacking
		local stackOffset = (totalPrompts - position) * SIMPLE_STACK_GAP
		self._stackOffset:set(SIMPLE_VERTICAL_OFFSET + stackOffset) -- Base offset + stacking
		local horizontalDir = self._left and -1 or 1
		local totalHorizontalOffset = SIMPLE_HORIZONTAL_OFFSET + SimpleHorizontalOffsetAdjustment + self._customHorizontalOffset
		self._stackHorizontalOffset:set(totalHorizontalOffset * horizontalDir) -- Push to the right or left
	else
		-- Regular prompts: vertically stacked (position 1 = top = highest offset)
		local offset = (totalPrompts - position) * STACK_OFFSET
		self._stackOffset:set(offset)
		self._stackHorizontalOffset:set(0)
	end
	
	-- Update key bindings
	local keyConfig = STACK_KEYS[stackIndex]
	if keyConfig then
		self._prompt.KeyboardKeyCode = keyConfig.keyboard
		self._prompt.GamepadKeyCode = keyConfig.gamepad
		
		-- Update displayed key text
		self._keyText:set(self:_getKeyText())
	end
end

--[=[
	Starts the button hold (triggered by clicking the button)
]=]
function ProximityPromptManager:_startButtonHold()
	if self._isHoldingButton or not self._isVisible or self._hasTriggered or self._onCooldown then
		return
	end
	
	self._isHoldingButton = true
	self._buttonScale:set(0.85)
	self._promptScale:set(0.95)
	
	-- Call onHoldBegan callback
	if self._promptData.onHoldBegan then
		self._promptData.onHoldBegan(LocalPlayer)
	end
	
	-- Start progress animation only if there's a hold duration
	if self._holdDuration > 0 then
		self._buttonHoldConnection = RunService.Heartbeat:Connect(function(dt)
			if not self._isVisible or not self._isHoldingButton then
				self:_stopButtonHold()
				return
			end
			
			local currentProgress = peek(self._holdProgress)
			local increment = dt / self._holdDuration
			local newProgress = math.min(1, currentProgress + increment)
			self._holdProgress:set(newProgress)
			
			-- Check if hold is complete
			if newProgress >= 1 then
				self._hasTriggered = true
				self._onCooldown = true
				
				-- Disconnect progress immediately to prevent further updates
				if self._buttonHoldConnection then
					self._buttonHoldConnection:Disconnect()
					self._buttonHoldConnection = nil
				end
				
				-- Reset scales and state
				self._isHoldingButton = false
				self._buttonScale:set(1)
				self._promptScale:set(1)
				self._holdProgress:set(0)
				
				-- Hide the prompt temporarily as cooldown
				self._transparency:set(1)
				
				-- Trigger the prompt
				if self._promptData.onTriggered then
					self._promptData.onTriggered(LocalPlayer)
				end
				
				-- Call onHoldEnded callback
				if self._promptData.onHoldEnded then
					self._promptData.onHoldEnded(LocalPlayer)
				end
				
				-- Show again after cooldown if still in range
				task.delay(0.5, function()
					self._onCooldown = false
					if self._prompt and self._prompt.Parent and peek(self._visible) then
						self._transparency:set(0)
					end
				end)
				return
			end
		end)
	end
	-- For instant triggers (no hold duration), we wait for release in _stopButtonHold
end

--[=[
	Stops the button hold
]=]
function ProximityPromptManager:_stopButtonHold()
	if not self._isHoldingButton then
		-- If not holding but _hasTriggered is set, reset it (key was released)
		self._hasTriggered = false
		return
	end
	
	self._isHoldingButton = false
	self._buttonScale:set(1)
	self._promptScale:set(1)
	
	-- Stop the progress connection
	if self._buttonHoldConnection then
		self._buttonHoldConnection:Disconnect()
		self._buttonHoldConnection = nil
	end
	
	-- For instant triggers (no hold duration), trigger on release
	if self._holdDuration <= 0 and not self._hasTriggered and not self._onCooldown then
		if self._promptData.onTriggered then
			self._promptData.onTriggered(LocalPlayer)
		end
	end
	
	-- Call onHoldEnded callback
	if self._promptData.onHoldEnded then
		self._promptData.onHoldEnded(LocalPlayer)
	end
	
	-- Reset progress
	self._holdProgress:set(0)
end

--[=[
	Updates the prompt text
	@param objectText string? -- New object text
	@param actionText string? -- New action text
]=]
function ProximityPromptManager:SetText(objectText: string?, actionText: string?)
	if objectText then
		self._prompt.ObjectText = objectText
		self._promptData.objectText = objectText
	end
	if actionText then
		self._prompt.ActionText = actionText
		self._promptData.actionText = actionText
	end
end

--[=[
	Sets the enabled state of the prompt
	@param enabled boolean
]=]
function ProximityPromptManager:SetEnabled(enabled: boolean)
	self._prompt.Enabled = enabled
end

--[=[
	Gets the underlying ProximityPrompt instance
	@return ProximityPrompt
]=]
function ProximityPromptManager:GetPrompt(): ProximityPrompt
	return self._prompt
end

--[=[
	Destroys the proximity prompt and cleans up
]=]
function ProximityPromptManager:Destroy()
	-- Unregister from active prompts
	ActivePrompts[self._prompt] = nil
	
	-- Remove from wants-to-be-visible tracking
	WantsToBeVisible[self] = nil
	
	-- Update stack for remaining prompts
	local parent = self._parent
	task.defer(function()
		updateStackForParent(parent)
		-- Re-check key conflicts
		updateKeyConflicts()
	end)
	
	if self._buttonHoldConnection then
		self._buttonHoldConnection:Disconnect()
		self._buttonHoldConnection = nil
	end
	
	self._maid:DoCleaning()
	
	if self._scope then
		self._scope:doCleanup()
	end
	
	setmetatable(self, nil)
end

task.spawn(function()
	-- Periodically update key conflicts as player moves
	-- This ensures the closest prompt is always shown when multiple share the same key
	while true do
		task.wait(0.1) -- Update every 100ms
		if next(WantsToBeVisible) then
			updateKeyConflicts()
		end
	end
end)

--[=[
	Sets an additional horizontal offset for simple prompts (to make room for other UI elements)
	@param offset number -- Additional studs to add to SIMPLE_HORIZONTAL_OFFSET
]=]
function ProximityPromptManager.SetSimpleHorizontalOffset(offset: number)
	SimpleHorizontalOffsetAdjustment = offset
	-- Update all active simple prompts
	for _, manager in pairs(ActivePrompts) do
		if manager._simple and WantsToBeVisible[manager] then
			local horizontalDir = manager._left and -1 or 1
			local totalHorizontalOffset = SIMPLE_HORIZONTAL_OFFSET + SimpleHorizontalOffsetAdjustment
			manager._stackHorizontalOffset:set(totalHorizontalOffset * horizontalDir)
		end
	end
end

--[=[
	Gets the current simple horizontal offset adjustment
	@return number
]=]
function ProximityPromptManager.GetSimpleHorizontalOffset(): number
	return SimpleHorizontalOffsetAdjustment
end

--[=[
	Sets a custom horizontal offset adjustment for this specific prompt
	@param offset number -- Additional studs to add to this prompt's horizontal offset
]=]
function ProximityPromptManager:SetCustomHorizontalOffset(offset: number)
	self._customHorizontalOffset = offset
	-- Immediately update the position if this is a simple prompt
	if self._simple and self._isVisible then
		local horizontalDir = self._left and -1 or 1
		local totalHorizontalOffset = SIMPLE_HORIZONTAL_OFFSET + SimpleHorizontalOffsetAdjustment + self._customHorizontalOffset
		self._stackHorizontalOffset:set(totalHorizontalOffset * horizontalDir)
	end
end

--[=[
	Gets the custom horizontal offset for this specific prompt
	@return number
]=]
function ProximityPromptManager:GetCustomHorizontalOffset(): number
	return self._customHorizontalOffset
end

--[=[
	Sets whether this simple prompt should be on the left or right side
	@param left boolean -- True for left side, false for right side (centered if no other prompts)
]=]
function ProximityPromptManager:SetLeft(left: boolean)
	if not self._simple then return end -- Only applies to simple prompts
	
	self._left = left
	
	-- Immediately update the position if visible
	if self._isVisible then
		local horizontalDir = self._left and -1 or 1
		local totalHorizontalOffset = SIMPLE_HORIZONTAL_OFFSET + SimpleHorizontalOffsetAdjustment + self._customHorizontalOffset
		self._stackHorizontalOffset:set(totalHorizontalOffset * horizontalDir)
		
		-- Re-update stacking for all prompts on this parent
		updateStackForParent(self._parent)
	end
end

return ProximityPromptManager