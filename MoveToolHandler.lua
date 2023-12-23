local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")

local MoveTool = {}
MoveTool.__index = MoveTool

function MoveTool.new(player: Player)
	local self = {
		_player = player,
		_mouse = player:GetMouse(),

		_keyBinds = {
			["ToggleMode"] = {Enum.KeyCode.R},
			["SelectPart"] = {Enum.UserInputType.MouseButton1},
		},

		_actions = {},

		_currentPart = nil,
		_holdingLMB = false,
		_modeToggled = false,

		_highlight = script.Highlight,
		_highlightCache = nil,

		_moveTool = RS:WaitForChild("MoveTool"),
		_moveToolCache = nil,
		
		_editMode = "move",
		
		_maxRange = 10,
		_connections = {},
		
		_startHoldPosition = nil
	}

	return setmetatable(self, MoveTool)
end

function MoveTool:Init()
	self._actions["ToggleMode"] = CAS:BindAction("ToggleMode", function (...) self:ToggleMode(...) end, true, unpack(self._keyBinds["ToggleMode"]))
end

function MoveTool:ToggleMode(actionName, inputState, _inputObject)
	if inputState == Enum.UserInputState.Begin then
		self._modeToggled = not self._modeToggled

		if self._modeToggled then
			self._actions["SelectPart"] = CAS:BindAction("SelectPart", function (...) self:SelectPart(...) end, true, unpack(self._keyBinds["SelectPart"]))
		else
			CAS:UnbindAction("SelectPart")
			self:DestroyDeps()
			
			self._currentPart = nil
			self._holdingLMB = false
		end
	end
end

function MoveTool:PositionAxisOnPart(Part, MoveTool)
	local X, Y, Z = MoveTool:FindFirstChild("X"), MoveTool:FindFirstChild("Y"), MoveTool:FindFirstChild("Z")
	
	local XAxis = X.Origin.Attach.Axis
	local YAxis = Y.Origin.Attach.Axis
	local ZAxis = Z.Origin.Attach.Axis
	
	X.PrimaryPart.CFrame = Part.CFrame * CFrame.new(Part.Size.X / 2, 0, 0)
	Y.PrimaryPart.CFrame = Part.CFrame * CFrame.new(0, Part.Size.Y / 2, 0)
	Z.PrimaryPart.CFrame = Part.CFrame * CFrame.new(0, 0, Part.Size.Z / 2)
end

function MoveTool:DestroyDeps()
	if self._highlightCache then
		self._highlightCache:Destroy()
		self._highlightCache = nil
	end
	
	if self._moveToolCache then 
		self._moveToolCache:Destroy() 
		self._moveToolCache = nil
	end
end

function MoveTool:SelectPart(actionName, inputState, _inputObject)
	if inputState == Enum.UserInputState.Begin then
		if self._mouse.Target then
			self._holdingLMB = true
			
			-- If we are pressing on the move tool, begin the move logic
			if self._mouse.Target:FindFirstAncestorOfClass("Model") then
				local Axis = self._mouse.Target:FindFirstAncestorOfClass("Model")
				
				if Axis.Parent and Axis.Parent.Name == self._moveTool.Name then
					self:EditPart(Axis)
					
					return
				end
			end
			self:DestroyDeps()
			
			self._currentPart = self._mouse.Target
			
			-- if we are not, then we just select the part
			if self._highlight then
				self._highlightCache = self._highlight:Clone()
				self._highlightCache.Parent = self._currentPart
			end
			
			-- Instantiate the move tool
			if self._moveTool then
				self._moveToolCache = self._moveTool:Clone()
				self._moveToolCache.Parent = self._currentPart
			end
			
			self:PositionAxisOnPart(self._currentPart, self._moveToolCache)
		end
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		self._holdingLMB = false
	end
end

function MoveTool:EditPart(Axis)
	if not self._currentPart then return end
		
	self._startHoldPosition = Vector2.new(self._mouse.X, self._mouse.Y)
	
	local axis = Vector3.fromAxis(Enum.Axis[Axis.Name])

	while self._holdingLMB and self._currentPart do
		-- relative mouse coords
		if self._editMode == "move" then
			local position = Vector2.new(self._mouse.X, self._mouse.Y)
			local offset = position - self._startHoldPosition
			local x_offset, y_offset = offset.X, offset.Y
			
			local z_offset = (x_offset + y_offset) / 2
					
			local camCF = workspace.CurrentCamera.CFrame
			local rv = camCF.XVector -- for the xaxis, multiply by cam xvector to acc cam's rotation
			local uv = camCF.YVector -- same for yAxis
			local fv = camCF.LookVector -- same for zAxis (lookvector)
						
			-- Calculate the movement relative to the camera orientation
			local delta = CFrame.new(
				math.sign(rv.X) * x_offset * axis.X / relativeDistance, 
				math.sign(uv.Y) * -y_offset * axis.Y / relativeDistance, 
				math.sign(fv.Z) * -z_offset * axis.Z / relativeDistance
			)
			
			self._currentPart.CFrame = self._currentPart.CFrame * delta
			self._startHoldPosition = position
		end
		
		self:PositionAxisOnPart(self._currentPart, self._moveToolCache)

		task.wait()
	end
end

return MoveTool
