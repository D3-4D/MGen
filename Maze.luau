local r = {}
r.__index = r

export type Maze = {
	{
		{
			--[[ Dict format is not used for memory optimization
				[1] - XPos: boolean,
				[2] - XNeg: boolean,
				[3] - ZPos: boolean,
				[4] - ZNeg: boolean,
				[5] - Thread: number?,
				[6] - RetentionTag: boolean?
			]]--
			
			boolean | (number?)
		}
	}
}

export type ThreadSetting = {
	LocalOperationalRange: {
		X: {Min: number, Max: number},
		Z: {Min: number, Max: number}
	}?,
	StartCoordinates: {X:number,Z:number}?,
	LinearRecursion:boolean,
	Sequential: boolean,
	SharedRecursion:boolean,
	Footprint:boolean,
	RapidExecutionCap:number,
	WallPreference: {number}?,
	PreferenceProbablity: number?
}

export type ConstructSettings = {
	Layout: Maze?,
	StartingPosition: number,
	Extension: {X: number, Z:number},
	NodeArea: number,
	GenerateFloor:boolean,
	Folder:Instance,
	WallHeight:number,
	WallWidth:number,
	ThreadNodeColors:{Color3},
	ThreadNodeMaterials:{Enum.Material},
	ThreadNodeShadowing:{boolean},
	ThreadNodeCollision:{boolean},
	ThreadNodeTransparency:{number},
	ThreadNodeCollisionGroup:{string},
	PinIndicator:boolean
}

export type BuildSettings = {
	Threads: number,
	Debugging:boolean,
	Layout: Maze?,
	ClyclicThreadSettings:boolean,
	ThreadSettings:{ThreadSetting}?
}

local PathCoversion = {2, 1, 4, 3}

local function Navigate(Current:{number--[[X,Z]]}, MaxX: number, MaxZ: number, MinX: number, MinZ: number)
	return {
		{math.clamp(Current[1]+1, MinX, MaxX), Current[2]}; -- X+
		{math.clamp(Current[1]-1, MinX, MaxX), Current[2]}; -- X-
		{Current[1], math.clamp(Current[2]+1, MinZ, MaxZ)}; -- Z+
		{Current[1], math.clamp(Current[2]-1, MinZ, MaxZ)}  -- Z-
	}
end

local function CleanUp(Maze: Maze, FastExcCap: number): Maze
	local SizeXZ = {#Maze, #Maze[1]}
	FastExcCap = FastExcCap or 5

	for X = 1, SizeXZ[1] do

		if X%FastExcCap == 0 then task.wait() end

		for Z = 1, SizeXZ[2] do
			if Z%(FastExcCap*2) == 0 then task.wait() end
			
			for Wall, Neighbor in Navigate({X, Z}, SizeXZ[1], SizeXZ[2], 1, 1) do
				if not Neighbor or (Neighbor[1] == X and Neighbor[2] == Z) then
					continue -- Skip border clamp selection & (invalid neighbors)?
				elseif  Maze[Neighbor[1]] and Maze[Neighbor[1]][Neighbor[2]] then
					if Maze[Neighbor[1]][Neighbor[2]][6] and not Maze[X][Z][6] then
						if not Maze[Neighbor[1]][Neighbor[2]][PathCoversion[Wall]] and Maze[X][Z][Wall] then
							Maze[X][Z][Wall] = false
						end
					else
						for i = 1, 4 do
							if Maze[Neighbor[1]][Neighbor[2]][i] and Maze[X][Z][PathCoversion[i]] then
								Maze[Neighbor[1]][Neighbor[2]][i] = false
							end
						end
					end
				end
			end
		end
	end
	return Maze
end

function r.new(Defaults: BuildSettings?)
	local Self: {Defaults: {Build: BuildSettings, Construct:ConstructSettings}} = {
		Defaults = Defaults or {
			Build = {
				Threads = 1,
				Layout = nil,
				Debugging = true,
				ClyclicThreadSettings = false,
				
				ThreadSettings = {
					{
						LocalOperationalRange = nil,
						StartCoordinates = nil,
						LinearRecursion = true,
						Sequential = false,
						SharedRecursion = false,
						Footprint = false,
						RapidExecutionCap = 30,
						WallPreference = {1, 3},
						PreferenceProbablity = 1,
					},
				}
			},
			Construct = {
				StartingPosition = Vector3.zero,
				Extension = {X = 60, Z = 60},
				NodeArea = 4,
				GenerateFloor = true,

				WallWidth = .4,
				WallHeight = 5,

				ThreadNodeColors = {Color3.new(.8,.8,.8)},
				ThreadNodeMaterials = {Enum.Material.SmoothPlastic},
				ThreadNodeShadowing = {false},
				ThreadNodeCollision = {true},
				ThreadNodeTransparency = {0},
				ThreadNodeCollisionGroup = {"Default"},
				PinIndicator = false
			}

		}
	}
	setmetatable(Self, r)
	
	return Self
end

function r:Build(
	OperationalRange:{
		X: {Min: number, Max: number},
		Z: {Min: number, Max: number}
	},
	BuildSettings:BuildSettings?|{}?
):  {
		Result: Maze,
		Debugging: {
			{Timing: {Init: number, End: number?}, UnitsProcessed: {{X: number, Y: number, PreviousThread:number|nil}}}
		}
	}
	local D:boolean=false -- Default Flag
	
	if not BuildSettings then
		D = true
		BuildSettings = self.Defaults.Build
	else
		for Idx, Obj in self.Defaults.Build do
			if BuildSettings[Idx] == nil then
				BuildSettings[Idx] = Obj
			end
		end
	end
	
	local Settings:BuildSettings = BuildSettings

	if not D then
		for Idx, Obj in self.Defaults.Build.ThreadSettings do
			if Settings.ThreadSettings[Idx] == nil then
				Settings.ThreadSettings[Idx] = Obj
			end
		end
	end
	
	local ThreadSettings:{ThreadSetting} = Settings.ThreadSettings
	
	local Debugging = Settings.Debugging
	local Layout = Settings.Layout
	local Threads = Settings.Threads
	local ThreadSettCycle = Settings.ClyclicThreadSettings
	
	local ThreadJobs = {}
	local Build = {}
	
	local Init = (Debugging and os.clock())
	
	for X = OperationalRange.X.Min, OperationalRange.X.Max do
		Build[X] = Build[X] or {}
		for Z = OperationalRange.Z.Min, OperationalRange.Z.Max do
			Build[X][Z] = (Layout and Layout[X] and Layout[X][Z]) or {true, true, true, true}
		end
	end

	if Debugging then
		local t = os.clock() - Init
		print("Finished template format in "..string.split(t,".")[1].."."..string.split(t, ".")[2]:sub(1, 2).." seconds.")
	end

	local GlobalRecur = {}
	local ThreadInfo = {}

	for Thread = 1, Threads do
		ThreadJobs[Thread] = true
		ThreadInfo[Thread] = Debugging and {
			Timing = {
				Init = os.clock(),
				End = nil,
			},
			UnitsProcessed = {}
		}
		
		task.spawn(
			function()
				local CurrentSettings:ThreadSetting
				if not ThreadSettings[Thread] then
					CurrentSettings = (ThreadSettCycle and ThreadSettings[math.clamp(((Thread+1)%(#ThreadSettings))+1, 1, #ThreadSettings)]) or self.Defaults.Build.ThreadSettings[1]
				else
					CurrentSettings = ThreadSettings[Thread]
				end
				
				local LocalRecur = (CurrentSettings["SharedRecursion"] and GlobalRecur) or {}

				if Thread ~= 1 and CurrentSettings["Sequential"] and ThreadJobs[Thread-1] then
					if Debugging then
						warn("Thread "..Thread.." delayed. Awaiting for thread "..(Thread-1).."...")
					end
					repeat task.wait() until not ThreadJobs[Thread-1]
				end

				local MinX, MaxX = OperationalRange.X.Min,OperationalRange.X.Max
				local MinZ, MaxZ = OperationalRange.Z.Min,OperationalRange.Z.Max

				local CurrPoint = CurrentSettings["StartCoordinates"] or {math.random(MinX, MaxX), math.random(MinZ, MaxZ)}
				local LinRecur = CurrentSettings["LinearRecursion"]

				local RecThread = CurrentSettings["Footprint"]
				local ExDlay = CurrentSettings["RapidExecutionCap"] or 20

				local PathPrefChnc = CurrentSettings["PreferenceProbablity"]
				local PathPrefConf = CurrentSettings["WallPreference"]

				if Debugging then
					print("Thread "..Thread.." began processing.")
				end
				
				local ThreadInit = (Debugging and os.clock())

				local Loop = true

				table.insert(LocalRecur, CurrPoint)
				
				if RecThread then
					Build[CurrPoint[1] ][CurrPoint[2] ][5] = Thread
				end

				local Cells = 1
				while Loop do
					for _ = 1, ExDlay do
						if not LocalRecur[1] and not CurrPoint then
							Loop = nil
							break
						end
						
						local Valid = {}
						for idx, obj in Navigate(CurrPoint, MaxX, MaxZ, MinX, MinZ) do
							if not table.find(Build[obj[1]][obj[2]], false) then
								table.insert(Valid, {idx, obj})
							end
						end

						if #Valid == 0 then
							local sw = (LinRecur and #LocalRecur) or math.random(1, #LocalRecur)
							CurrPoint = LocalRecur[sw]
							table.remove(LocalRecur, sw)
							continue
						elseif #Valid > 1 then
							table.insert(LocalRecur, CurrPoint)
						end

						local Chosen = Valid[math.random(1, #Valid)]

						if PathPrefConf and table.find(PathPrefConf, Chosen[1]) and math.random(1, PathPrefChnc) == 1 then
							local F = nil
							for _, v in Valid do
								if not table.find(PathPrefConf, v[1]) then
									F = v
									break
								end
							end
							Chosen = F or Chosen
						end
						Build[CurrPoint[1]][CurrPoint[2]][Chosen[1]] = false
						Build[Chosen[2][1]][Chosen[2][2]][PathCoversion[Chosen[1]]] = false
						
						if Debugging then
							ThreadInfo[Thread]["UnitsProcessed"][#ThreadInfo[Thread]["UnitsProcessed"]+1] = {Chosen[2][1], Chosen[2][2], Build[Chosen[2][1]][Chosen[2][2]][5]}
						end
						
						if RecThread then
							Build[Chosen[2][1]][Chosen[2][2]][5] = Thread
						end
						CurrPoint = Chosen[2]
						Cells += 1
					end
					task.wait()
				end

				ThreadJobs[Thread] = false
				if Debugging then
					ThreadInfo[Thread]["Timing"]["End"] = os.clock()
					
					local t = ThreadInfo[Thread]["Timing"]["End"]-ThreadInit
					print("Thread "..Thread.." finished processing in "..string.split(t, ".")[1].."."..string.split(t, ".")[2]:sub(1, 2).." seconds with "..Cells.." nodes built.")
				end
			end
		)
	end

	repeat task.wait() until not table.find(ThreadJobs, true)
	Build = CleanUp(Build, math.ceil(math.clamp((OperationalRange.X.Max+OperationalRange.Z.Max)/4, 30, 250)))
	if Debugging then
		local t = os.clock()-Init
		print("Finished build. ("..string.split(t, ".")[1].."."..string.split(t, ".")[2]:sub(1, 2).."s)\n")
	end
	return {Result = Build, Debugging = ThreadInfo}
end

function r:Construct(Settings:ConstructSettings): Folder
	local Init = Settings.Folder ~= nil
	if not Settings then
		Settings = self.Defaults.Construct
	else
		for Idx, Obj in self.Defaults.Construct do
			if Settings[Idx] == nil then
				Settings[Idx] = Obj
			end
		end
	end

	local Parent = Settings.Folder
	
	local Init = Parent ~= nil
	Parent = Parent or Instance.new("Folder")
	
	local BApp = Settings.Layout
	local Floor = Settings.GenerateFloor
	local NSepD = Settings.NodeArea
	local NS = Settings.Extension
	local BP = Settings.StartingPosition
	local Width = Settings.WallWidth
	local Height = Settings.WallHeight
	local Shadow = Settings.ThreadNodeShadowing
	local Color = Settings.ThreadNodeColors
	local Transp = Settings.ThreadNodeTransparency
	local Coll = Settings.ThreadNodeCollision
	local CollG = Settings.ThreadNodeCollisionGroup
	local Mat = Settings.ThreadNodeMaterials
	local PinThreads = Settings.PinIndicator

	if game:GetService("RunService"):IsStudio() then
		Parent.Parent = workspace
	end
	--

	if not BApp and Init then
		Parent:Destroy()
		Parent = Instance.new("Folder")
	end

	if Floor and (not Init or (Init and not Parent:FindFirstChild("Floor"))) then
		local F = Instance.new("Part")
		F.Name = "Floor"
		F.Anchored = true
		F.Size = Vector3.new(NS.X*NSepD,.4,NS.Z*NSepD)
		F.Material = Enum.Material.Slate -- Texture is more evident between all of the colors
		F.Position = Vector3.new(BP.X*2+(NS.X*NSepD)/2+NSepD/2, BP.Y+Height/2, BP.Z+(NS.Z*NSepD)/2+NSepD/2)
		F.Parent = Parent
	end

	for X = 1, NS.X do
		for Z = 1, NS.Z do
			if Z%20 == 0 and X%2 == 0 then task.wait() end
			local Unit = (Init and BApp and Parent[X.."."..Z])
			if not Unit then
				Unit = Instance.new("Folder")
				Unit.Name = X.."."..Z
			end
			local t1 = BP.X+(NSepD*X)
			local t2 = Height+BP.Y
			local t3 = BP.Z+(NSepD*Z)
			local sub1 = NSepD/2
			local sub2 = -NSepD/2

			local su = Parent:FindFirstChild(X.."."..Z) ~= nil
			local Indic = Unit:FindFirstChild("Pin")
			if BApp and BApp[X][Z][5] and PinThreads then
				local temp = NSepD/2
				if not Indic then
					Indic = Instance.new("Part")
					Indic.Anchored = true
					Indic.Color = Color[(BApp and BApp[X][Z][5] and BApp[X][Z][5]%#Color+1)] or Color3.new(1,0,0)
					Indic.Size = Vector3.new(.05, temp, temp)
					Indic.Shape = Enum.PartType.Cylinder
					Indic.Material = Enum.Material.Neon
					Indic.Position = Vector3.new(t1, BP.Y+Height/2+.45, t3)
					Indic.Transparency = .4
					Indic.Rotation = Vector3.new(0,0,90)
					Indic.Parent = Unit
					Indic.Name = "Pin"
				else
					Indic.Color = Color[(BApp and BApp[X][Z][5] and BApp[X][Z][5]%#Color+1)] or Color3.new(1,0,0)
					Indic.Size = Vector3.new(.05, temp, temp)
					Indic.Position = Vector3.new(t1, BP.Y+Height/2+.45, t3)
				end
			elseif Indic then
				Indic:Destroy()
			end

			for wall = 1, 4 do
				local qc = BApp and BApp[X][Z][wall]
				local gb = Init and su and Parent[X.."."..Z]:FindFirstChild(wall)

				local Swi = ((not BApp or (qc and not gb)) and 1) or (not qc and gb and 2) or (gb and qc and 3)

				if Swi == 1 then
					local Wall = Instance.new("Part")
					Wall.Anchored = true
					Wall.CastShadow = Shadow[((BApp and BApp[X][Z][5])or 0)%#Shadow+1]
					Wall.Color = Color[(not PinThreads and BApp and BApp[X][Z][5] and BApp[X][Z][5]%#Color+1)] or Color3.new(1,1,1)
					Wall.Material = Mat[((BApp and BApp[X][Z][5])or 0)%#Mat+1]
					Wall.Rotation = (wall > 2 and Vector3.new(0,-90,0)) or Vector3.zero
					Wall.CanCollide = Coll[((BApp and BApp[X][Z][5])or 0)%#Coll+1]
					Wall.Transparency = Transp[((BApp and BApp[X][Z][5])or 0)%#Transp+1]
					Wall.CollisionGroup = CollG[((BApp and BApp[X][Z][5])or 0)%#CollG+1]
					Wall.Size = Vector3.new(Width, Height, NSepD)
					Wall.Name = wall
					if wall < 3 then
						Wall.Position = Vector3.new(t1+((wall==1 and sub1)or sub2), t2, t3)
					else
						Wall.Position = Vector3.new(t1, t2, t3+((wall==3 and sub1)or sub2))
					end
					Wall.Parent = Unit
				elseif Swi == 2 then
					Parent[X.."."..Z][wall]:Destroy()
				elseif Swi == 3 then
					local t = Parent[X.."."..Z][wall]
					t.CastShadow = Shadow[((BApp and BApp[X][Z][5])or 0)%#Shadow+1]
					t.Color = Color[(not PinThreads and BApp and BApp[X][Z][5] and BApp[X][Z][5]%#Color+1)] or Color3.new(1,1,1)
					t.Material = Mat[((BApp and BApp[X][Z][5])or 0)%#Mat+1]
					t.Transparency = Transp[((BApp and BApp[X][Z][5])or 0)%#Transp+1]
					t.CanCollide = Coll[((BApp and BApp[X][Z][5])or 0)%#Coll+1]
					t.CollisionGroup = CollG[((BApp and BApp[X][Z][5])or 0)%#CollG+1]
					t.Size = Vector3.new(Width, Height, NSepD)
				end
			end
			Unit.Parent = Parent
		end
	end
	Parent.Parent = Parent.Parent or workspace
	return Parent
end

return r