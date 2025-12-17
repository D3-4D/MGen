-- Parent: game:GetService("ServerScriptService")

local function Colors(Amount:number)
	local p = {}
	local Rand = math.random(-2^12,2^12)/2^12
	
	for i = 0, Amount-1 do
		local val =  math.abs(1/(Amount-i)+Rand)
		table.insert(p, Color3.fromHSV((val>1 and val - math.floor(val)) or val, val, 1))
	end

	return p
end

local Funcs = require(game:GetService("ServerStorage").MazeFuncs)

local Threads = 6

local OperationalRange = { -- Master size
	X = {Min = 1, Max = 65},
	Z = {Min = 1, Max = 65},
}

local ConstructSettings = {
	-- General settings

	Layout = nil,                        -- Build application. Leave nil for visual grid
	StartingPosition = Vector3.zero,     -- Initial node build point
	Extension = {X = 65, Z = 65},        -- Node scale {X, Z}
	NodeArea = 2.5,                      -- Space between walls
	GenerateFloor = false,               -- Floored (configurations are excluded due to ease of access)
	Folder = nil,                        -- Parent folder. Leave nil for directory creation


	-- Wall properties (for thread individuality, repeat type in a table)

	-- Leave nil for application of default instance creation values

	WallWidth = .4, 								-- Width
	WallHeight = .8, 								-- Height
	
	ThreadNodeColors = Colors(Threads),				-- Color(s)
	ThreadNodeMaterials = {Enum.Material.Rock},		-- Material(s)
	ThreadNodeShadowing = {false},					-- Shadow(s)
	ThreadNodeCollision = {true},					-- Collision(s)
	ThreadNodeTransparency = {0},					-- Transparency
	ThreadNodeCollisionGroup = {"Default"},			-- Coll. group(s)
	PinIndicator = false,							-- Ball indicator
}

local BuildInstructs = {
	Threads = Threads, -- Threads
	Layout = nil, -- Current build layout (maze build)
				  -- If blank, performs build as empty;
				  -- Otherwise, will exclude already processed nodes (radius preservation thingy)

	Debugging = true, -- Debugging
	ClyclicThreadSettings = true,
	ThreadSettings = {				-- Threads settings (Leave nil for default settings)
		{ 								-- Thread setting (Leave values nil for defaults)
			LocalOperationalRange = nil,	-- Local size (master size format, will malfunction paired with active SRA)
			StartCoordinates = nil,			-- Starting point (leave nil for random)
			LinearRecursion = true,			-- Linear recursion
			Sequential = false,				-- Sequenced thread (executes after last thread is finished; doesn't work on first thread)
			SharedRecursion = true, 		-- Shared recursion access (SRA)
			Footprint = true,				-- Record thread action in nodes (for exhibition or examining)
			RapidExecutionCap = 30, 		-- Rapid execution cap
			WallPreference = { 1, 3 },		-- Path preferance mode (for structuring)
			--[[
				For Default mode(random), should be set nil
				Otherwise: {1,2,3} or {2,4} or {3}...
				
				1: PosX
				2: NegX
				3: PosZ
				4: NegZ
			]]--

			PreferenceProbablity = 1 -- 1 in X chance for wall preference mode
		},
	}
}

local Gen = Funcs.new()

ConstructSettings.Folder = Gen:Construct(ConstructSettings) -- From empty to grid

ConstructSettings.Layout = Gen:Build(OperationalRange, BuildInstructs)[1]

ConstructSettings.Folder = Gen:Construct(ConstructSettings) -- From grid to gen

local HB = Instance.new("Part")
HB.Shape = Enum.PartType.Cylinder
HB.Size = Vector3.new(.8, 20, 28)
HB.Transparency = .8
HB.Material = Enum.Material.Neon

local MinX = ConstructSettings.StartingPosition.X+HB.Size.Y/2
local MinZ = ConstructSettings.StartingPosition.Z+HB.Size.Y/2
local MaxX = ConstructSettings.StartingPosition.X+ConstructSettings.Extension.X*ConstructSettings.NodeArea-HB.Size.Y/2
local MaxZ = ConstructSettings.StartingPosition.Z+ConstructSettings.Extension.Z*ConstructSettings.NodeArea-HB.Size.Y/2

while task.wait() do
	ConstructSettings.PinIndicator = math.random(1,2)==1
	local Preserve = {}
	HB.Color = Color3.new(.8,.8,.8)
	HB.Position = Vector3.new(math.random(MinX,MaxX), ConstructSettings.StartingPosition.Y+ConstructSettings.WallHeight/2, math.random(MinZ,MaxZ))

	for _, obj in HB:GetTouchingParts() do
		if obj.Parent:IsA("Folder") and obj.Name ~= "Floor" then
			local XY = string.split(obj.Parent.Name, ".")
			Preserve[tonumber(XY[1])] = Preserve[tonumber(XY[1])] or {}
			Preserve[tonumber(XY[1])][tonumber(XY[2])] = {false,false,false,false,nil,true}
			for _, wall in obj.Parent:GetChildren() do
				if wall.Name ~= "Pin" then
					Preserve[tonumber(XY[1])][tonumber(XY[2])][tonumber(wall.Name)] = true
				end
			end
		end
	end
	
	BuildInstructs.Layout = Preserve
	
	ConstructSettings.Layout = Gen:Build(OperationalRange, BuildInstructs)[1]
	
	ConstructSettings.ThreadNodeColors = Colors(Threads)
	HB.Color = Color3.new(1,0,0)
	HB.Transparency = (ConstructSettings.PinIndicator == true and .5) or .65
	ConstructSettings.Folder = Gen:Construct(ConstructSettings)
end
