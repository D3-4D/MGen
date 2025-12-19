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
	SequentialInitiation: boolean,
	
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
	StreamFunction:(X:number, Z:number, NodeInfo:{boolean|number|nil}, Context:string)->(any),
	CleanUp:boolean,
	ClyclicThreadSettings:boolean,
	ThreadSettings:{ThreadSetting}?
}

local PathCoversion = {2, 1, 4, 3}

local function Navigate(Current:{number--[[X,Z]]}, MaxX: number, MaxZ: number, MinX: number, MinZ: number)
	local c1,c2 = Current[1], Current[2]
	return {
		c1+1<=MaxX and {c1+1, c2} or nil; -- X+
		c1-1>=MinX and {c1-1, c2} or nil; -- X-
		c2+1<=MaxZ and {c1, c2+1} or nil; -- Z+
		c2-1>=MinZ and {c1, c2-1} or nil; -- Z-
	}
end

function r.new(Defaults: BuildSettings?)
	local Self: {Defaults: {Build: BuildSettings, Construct:ConstructSettings}} = {
		Defaults = Defaults or {
			Build = {
				Threads = 1,
				Layout = nil,
				Debugging = true,
				CleanUp = true,
				ClyclicThreadSettings = false,

				ThreadSettings = {
					{
						LocalOperationalRange = nil,
						StartCoordinates = nil,
						LinearRecursion = true,
						SequentialInitiation = false,
						SharedRecursion = true,
						Footprint = true,
						RapidExecutionCap = 30,
						WallPreference = nil,
						PreferenceProbablity = nil,
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
	local StreamFunction = Settings.StreamFunction
	local Threads = Settings.Threads
	local ThreadSettCycle = Settings.ClyclicThreadSettings

	local ThreadJobs = {}
	local Build = {}

	local Init = (Debugging and os.clock())

	for X = OperationalRange.X.Min, OperationalRange.X.Max do
		Build[X] = Build[X] or {}
		for Z = OperationalRange.Z.Min, OperationalRange.Z.Max do
			local l = Layout and Layout[X]
			Build[X][Z] = (l and l[Z]) or {true,true,true,true}
		end
	end

	if Debugging then
		local t = os.clock() - Init
		print("Finished template format in "..string.split(t,".")[1].."."..string.split(t, ".")[2]:sub(1, 3).." seconds.")
	end

	local GlobalRecur = {}
	local ThreadInfo = {}

	local RunningThreads = 0

	for Thread = 1, Threads do
		ThreadJobs[Thread] = true
		RunningThreads += 1
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
					CurrentSettings = ThreadSettCycle and (ThreadSettings[Thread%Threads == 0 and Threads or Thread%Threads]) or self.Defaults.Build.ThreadSettings[1]
				else
					CurrentSettings = ThreadSettings[Thread]
				end

				local LocalRecur = (CurrentSettings["SharedRecursion"] and GlobalRecur) or {}
				local CurrOperationalRange = CurrentSettings.LocalOperationalRange or OperationalRange

				if Thread ~= 1 and CurrentSettings["SequentialInitiation"] and ThreadJobs[Thread-1] then
					if Debugging then
						warn("Thread "..Thread.." delayed. Awaiting for thread "..(Thread-1).."...")
					end
					repeat task.wait() until not ThreadJobs[Thread-1]
				end

				local MinX, MaxX = CurrOperationalRange.X.Min,CurrOperationalRange.X.Max
				local MinZ, MaxZ = CurrOperationalRange.Z.Min,CurrOperationalRange.Z.Max

				local CurrPoint = CurrentSettings["StartCoordinates"]
				if not CurrPoint then
					for _ = 1, 10 do
						CurrPoint = {math.random(MinX, MaxX), math.random(MinZ, MaxZ)}
						local L = Layout and Layout[1] or {}
						if not L[2] then
							break
						end
					end
				end
				local LinRecur = CurrentSettings["LinearRecursion"]

				local RecThread = CurrentSettings["Footprint"]
				local ExDlay = CurrentSettings["RapidExecutionCap"] or 20

				local PathPrefChnc = CurrentSettings["PreferenceProbablity"]
				local CleanUp = Settings["CleanUp"]
				local PathPrefConf = CurrentSettings["WallPreference"]

				if Debugging then
					print("Thread "..Thread.." began processing.")
				end

				local ThreadInit = (Debugging and os.clock())

				local Loop = true

				local Cells = 1
				while Loop do
					for _ = 1, ExDlay do
						if not LocalRecur[1] and not CurrPoint then
							Loop = nil
							break
						end

						local Valid = {}
						local Invalid = CleanUp and {}
						
						if RecThread then
							Build[CurrPoint[1]][CurrPoint[2]][5] = Thread
						end
						
						local Sur = Navigate(CurrPoint, MaxX, MaxZ, MinX, MinZ)
						for Idx, Obj in Sur do
							local b = Build[Obj[1]][Obj[2]]
							-- to optimize footprint heavy usage implement:
							-- not b[5] and (b[1] and b[2] and b[3] and b[4])
							
							table.insert((b[1] and b[2] and b[3] and b[4] and not b[6]) and Valid or (CleanUp and Invalid or {}), {Idx, Obj[1], Obj[2]})
						end
						
						if Valid[2] then
							for i = 1, #Valid do
								local rand = math.random(1,#Valid)
								Valid[i],Valid[rand] = Valid[rand],Valid[i]
							end
						end
						
						if CleanUp then
							for _,Obj in Invalid do
								if not Obj[6] then
									local Wall = Obj[1]
									if Build[Obj[2]][Obj[3]][PathCoversion[Wall]] and Build[CurrPoint[1]][CurrPoint[2]][Wall] then
										Build[CurrPoint[1]][CurrPoint[2]][Wall] = false
										if StreamFunction then
											StreamFunction({{CurrPoint[1], CurrPoint[2], Build[CurrPoint[1]][CurrPoint[2]]}}, "CleanUp")
										end
									end
								end
							end
						end
						
						if #Valid == 0 then
							local sw = LinRecur and #LocalRecur or math.random(1, #LocalRecur)
							
							CurrPoint = LocalRecur[sw]
							table.remove(LocalRecur, sw)
							continue
						elseif #Valid > 1 then
							table.insert(LocalRecur, CurrPoint)
						end
						
						local c,cx,cz = unpack(Valid[not Valid[2] and 1 or math.random(1, #Valid)])
						local Dice = PathPrefConf and (PathPrefChnc == 1 or math.random(1, PathPrefChnc) == 1) or nil
						if Dice ~= nil then
							if Dice and (c~=PathPrefConf[1] and c~=PathPrefConf[2] and c~=PathPrefConf[3] and c~=PathPrefConf[4]) then
								for _, v in Valid do
									local ch = v[1]
									if ch == c then
										continue
									end
									if (ch==PathPrefConf[1] or ch==PathPrefConf[2] or ch==PathPrefConf[3] or ch==PathPrefConf[4]) then
										c,cx,cz = v[1],v[2],v[3]
										break
									end
								end
							elseif not Dice and (c==PathPrefConf[1] or c==PathPrefConf[2] or c==PathPrefConf[3] or c==PathPrefConf[4]) then 
								for _, v in Valid do
									local ch = v[1]
									if ch == c then
										continue
									end
									if (ch~=PathPrefConf[1] and ch~=PathPrefConf[2] and ch~=PathPrefConf[3] and ch~=PathPrefConf[4]) then
										c,cx,cz = v[1],v[2],v[3]
										break
									end
								end
							end
						end
						
						Build[CurrPoint[1]][CurrPoint[2]][c] = false
						Build[cx][cz][PathCoversion[c]] = false
						if StreamFunction then
							StreamFunction({{
								CurrPoint[1], CurrPoint[2], Build[CurrPoint[1]][CurrPoint[2]]
							},
							{
								cx, cz, Build[cx][cz]
							}}, "Main")
						end

						if Debugging then
							ThreadInfo[Thread]["UnitsProcessed"][#ThreadInfo[Thread]["UnitsProcessed"]+1] = {cx, cz, Build[cx][cz][5]}
						end

						CurrPoint = {cx,cz}
						Cells += 1
					end
					task.wait()
				end

				if RunningThreads == 1 then
					for X,_ in Settings["Layout"] or {} do
						for Z,_ in Settings["Layout"][X] do
							local Valid = {}
							for Idx, Obj in Navigate({X,Z}, OperationalRange.X.Max, OperationalRange.Z.Max, OperationalRange.X.Min, OperationalRange.Z.Min) do
								if not Build[Obj[1]][Obj[2]][6] and Build[Obj[1]][Obj[2]][PathCoversion[Idx]] and not Build[X][Z][Idx] then
									table.insert(Valid, {Idx,Obj})
								end
							end
							
							if not Valid[1] then continue end
							
							if Valid[2] then
								for i = 1, #Valid do
									local rand = math.random(1,#Valid)
									Valid[i],Valid[rand] = Valid[rand],Valid[i]
								end
							end

							local Chosen = 1
							local Choosing = 1
							
							while true do
								local Choice = Valid[Choosing]
								if not Choice then
									break
								end
								local Idx = PathCoversion[Choice[1]]
								
								local T = Build[Choice[2][1]][Choice[2][2]][5]
								local AppliedSettings:ThreadSetting = ThreadSettings[T or 0]

								if not AppliedSettings then
									if not ThreadSettCycle then
										AppliedSettings = self.Defaults.Build.ThreadSettings
									elseif T then
										AppliedSettings = ThreadSettings[T%Threads == 0 and Threads or T%Threads] or self.Defaults.Build.ThreadSettings
									else
										AppliedSettings = self.Defaults.Build.ThreadSettings
									end
								end
								
								local WP = AppliedSettings.WallPreference
								if WP or (AppliedSettings.PreferenceProbablity == 1 and (WP[1] ~= Idx and WP[2] ~= Idx and WP[3] ~= Idx and WP[4] ~= Idx) ) then
									Choosing += 1
								else
									Chosen = Choosing
									break
								end
							end
							
							Chosen = Valid[Chosen]
							
							Build[Chosen[2][1]][Chosen[2][2]][PathCoversion[Chosen[1]]] = false
							if StreamFunction then
								StreamFunction({{Chosen[2][1], Chosen[2][2], Build[Chosen[2][1]][Chosen[2][2]]}}, "Restoration")
							end
						end
					end
				end

				if Debugging then
					ThreadInfo[Thread]["Timing"]["End"] = os.clock()
					local t = ThreadInfo[Thread]["Timing"]["End"]-ThreadInit
					print("Thread "..Thread.." finished processing in "..string.split(t, ".")[1].."."..string.split(t, ".")[2]:sub(1, 3).." seconds with "..Cells.." nodes built.")
				end

				ThreadJobs[Thread] = false
				RunningThreads -= 1
			end
		)
	end

	repeat task.wait() until RunningThreads == 0
	--Build = CleanUp(Build, math.ceil(math.clamp((OperationalRange.X.Max+OperationalRange.Z.Max)/4, 30, 250)))
	if Debugging then
		local t = os.clock()-Init
		print("Finished build. ("..string.split(t, ".")[1].."."..string.split(t, ".")[2]:sub(1, 3).."s)\n")
	end
	return {Result = Build, Debugging = ThreadInfo}
end

function r:Construct(Settings:ConstructSettings): Folder
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
	local BP = Settings.StartingPosition
	local NS = Settings.Extension
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

	if Floor and (not Init or (Init and not Parent:FindFirstChild("Floor"))) then
		local F = Instance.new("Part")
		F.Name = "Floor"
		F.Anchored = true
		F.Size = Vector3.new(NS.X*NSepD,.4,NS.Z*NSepD)
		F.Material = Enum.Material.Slate -- Texture is more evident between all of the colors
		F.Position = Vector3.new(BP.X*2+(NS.X*NSepD)/2+NSepD/2, BP.Y+Height/2, BP.Z+(NS.Z*NSepD)/2+NSepD/2)
		F.Parent = Parent
	end
	if not BApp then
		BApp = {}
		for X = 1, NS.X do
			BApp[X] = BApp[X] or {}
			for Z = 1, NS.Z do
				BApp[X][Z] = {true,true,true,true}
			end
		end
	end
	for X,_ in BApp do
		for Z,_ in BApp[X] do
			if Z%20 == 0 and X%2 == 0 then task.wait() end
			local Unit = (Init and BApp and Parent:FindFirstChild(X.."."..Z))
			if not Unit then
				if Init then
					continue
				end
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
					Indic.Transparency = .7
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