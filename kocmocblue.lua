---- solara temp fix -------------
-- local HttpService = game:GetService("HttpService")
-- local encode = function(thing) return HttpService:UrlEncode(thing) end
-- function communicate(method, path, body)
-- 	local success, result = pcall((syn and syn.request or http_request), {
-- 		Url = "http://127.0.0.1:22125"..path,
-- 		Method = method,
-- 		Body = body,
-- 	})
-- 	if not success then
-- 		print("Error communicating with filesystem proxy: "..result)
-- 		messagebox("Error communicating with filesystem proxy: "..result, "Error", 0) -- i know this hangs the thread
-- 	end
-- 	return result.Body
-- end

-- function proxyfilewrite(file, data)
-- 	return communicate("POST", "/write?file="..encode(file), data)
-- end
-- function proxyfileappend(file, data)
-- 	return communicate("POST", "/append?file="..encode(file), data)
-- end
-- function proxyfileread(file)
-- 	return communicate("GET", "/read?file="..encode(file))
-- end
-- function proxyfileexists(file)
-- 	return communicate("GET", "/exists?file="..encode(file)) == "1"
-- end

-- readfile = proxyfileread
-- isfile = proxyfileexists
-- writefile = proxyfilewrite

-- require = function(robloxmodule)
--     warn("require is disabled, module: ", robloxmodule:GetFullName())
--     return {}
-- end


-----------------------


shared.autoload = "afk"
shared.no_filesystem = false
shared.lightweight = false -- nothing external installed. this option does nothing but forcibly change the two options below
shared.no_fs_proxy = false--                                  or shared.lightweight
shared.no_AHK = true                or shared.lightweight

------------------------------------------------------------------------

repeat task.wait(0.1) until game:IsLoaded()

if not shared.no_filesystem then
    -- check if the executor supports filesystem functions, if not, forcefully enable shared.no_filesystem
    shared.no_filesystem = not writefile or not readfile or not isfile or not isfolder or not makefolder
    if shared.no_filesystem then
        warn("Your exploit does not have filesystem support, the script will \n"..
            "simulate a filesystem. Consider getting an exploit with filesystem \n"..
            "support as the script will take longer to load. \n"..
            "(Script will also be unable to remember field degredation timers)")
    end
end

-- simulate filesystem
if shared.no_filesystem then
    print("Filesystem will be simulated. Please note this may lead to longer load times. (Script will also be unable to remember field degredation timers)")
    loadstring(game:HttpGet("https://raw.githubusercontent.com/Wha-The/kocmoc/main/umodules/filesystem_simulation.lua"))()
end

-- filesystem management
local HttpService = game:GetService("HttpService")
if not isfolder("kocmoc") then makefolder("kocmoc") end
if not isfile("kocmoc/planter_degradation.planters") then
    writefile("kocmoc/planter_degradation.planters", "{}")
end
if not isfolder("kocmoc/cache") then makefolder("kocmoc/cache") end
if not isfolder("kocmoc/cache/umodules") then makefolder("kocmoc/cache/umodules") end
if not isfolder("kocmoc/cache/modules") then makefolder("kocmoc/cache/modules") end

shared.LoadedModules = nil
if not isfile("kocmoc/cache/umodules/import.lua") then writefile("kocmoc/cache/umodules/import.lua", game:HttpGet("https://raw.githubusercontent.com/Wha-The/kocmoc/main/umodules/import.lua")) end
local uimport, import = loadstring(readfile("kocmoc/cache/umodules/import.lua"))()

-- load utility modules
local library                                                                                   = uimport("bracketv4.lua")
local api                                                                                       = uimport("api.lua", "https://raw.githubusercontent.com/Boxking776/kocmoc/main/api.lua")
local pathfind, playbackRoute                                                                   = uimport("pathfind.lua")
local proxyfilewrite, proxyfileappend, proxyfileread, proxyfileexists, proxywipecache           = uimport("proxyfileinterface.lua")

-- load modules
local count_stray_balloons, gethiveballoon, get_hive_balloon_size                               = import("balloons.lua")
local find_field                                                                                = import("find_field.lua")
local playRoute, routeToField                                                                   = import("routes.lua")
local compile_planters, place_new_planters, collectplanters, allnectars, nectarprioritypresets  = import("planters.lua")

local Pipes                                                                                     = import("Pipes.lua")
local get_buff_combo, get_buff_active_duration, get_buff_percentage, compile_buff_list          = import("buffs.lua")
local farm, gettoken, identifyToken                                                             = import("tokens.lua")

-- test filesystem proxy {
if not proxyfileexists("kocmoc") then
    print("unable to communicate with filesystem proxy. Please set it up.")
    return messagebox("Unable to communicate with filesystem proxy. Please set it up.", "Script Stopped", 0)
end
-- }

local playerstatsevent = game:GetService("ReplicatedStorage").Events.RetrievePlayerStats
local statstable = playerstatsevent:InvokeServer()
local function get_latest_player_stats() return playerstatsevent:InvokeServer() end
local function equip_mask(mask) return game:GetService("ReplicatedStorage").Events.ItemPackageEvent:InvokeServer("Equip", { ["Mute"] = false, ["Type"] = mask, ["Category"] = "Accessory"}) end

local MainThread = {
    tasks = {}
}

MainThread.resolve = function(fn)
    MainThread.tasks[fn] = true
end

game:GetService("RunService").Heartbeat:Connect(function()
    local onetask = next(MainThread.tasks)
    if onetask then
        MainThread.tasks[onetask] = nil
        onetask()
    end
end)

do
    local apitween = api.tween
    api.tween = function(t, pos)
        local MAXSPEED = 60 -- studs per second
        if t == nil then
            t = (game.Players.LocalPlayer.Character.PrimaryPart.Position - pos.Position).magnitude / MAXSPEED
        end
        if t > 50 then
            -- something is wrong
            return
        end
        return apitween(t, pos)
    end
    local apiwalkto = api.walkto
    api.walkto = function(pos)
        if not game.Players.LocalPlayer.Character:FindFirstChild("Humanoid") then return end
        return api.walkto(pos)
    end

    api.humanoid = function()
        return game.Players.LocalPlayer.Character:WaitForChild("Humanoid")
    end
end

local function customChildAdded(folder, childAdded, childRemoved)
	folder.ChildAdded:Connect(childAdded)
    folder.ChildRemoved:Connect(childRemoved)
    return folder
    
    -- local PARTICLES = {}
	-- local count = 0
	-- local RESET = 1/15
	-- particle = game:GetService("RunService").Heartbeat:Connect(function(dt)
	-- 	count += dt
	-- 	if count < RESET then return end
	-- 	count %= RESET
	-- 	local t = folder:GetChildren()
	-- 	local exists = {}
	-- 	for _, p in t do
	-- 		if not PARTICLES[p] then
	-- 			PARTICLES[p] = true
	-- 			childAdded(p)
	-- 		end
	-- 		exists[p] = true
	-- 	end
	-- 	for p, _ in PARTICLES do
	-- 		if not t[p] then
	-- 			PARTICLES[p] = nil
	-- 			childRemoved(p)
	-- 		end
	-- 	end
	-- end)
	-- return particle
end

local getupvalues = debug.getupvalues or getupvalues

local queued = {}
local HoneyStat = game.Players.LocalPlayer:WaitForChild("CoreStats"):WaitForChild("Honey")
local temptable = {
    version = "2.22.0m",
    blackfield = "Ant Field",
    redfields = {},
    bluefields = {},
    whitefields = {},
    puffshroomdetected = false,
    magnitude = 70,
    running = false,
    configname = "",
    started = {
        vicious = false,
        mondo = false,
        windy = false,
        ant = false,
        monsters = false
    },
    detected = {
        vicious = false,
        windy = false
    },
    farm_tokens = false,
    converting = false,
    honeystart = HoneyStat.Value,
    honeycurrent = HoneyStat.Value,
    dead = false,
    float = false,
    windy = nil,
    sprouts = {
        detected = false,
        coords = nil,
    },
    cache = {
        autofarm = false,
        killmondo = false,
        vicious = false,
        windy = false
    },
    planters = {
        planter = {},
        cframe = {},
        activeplanters = {
            type = {},
            id = {}
        }
    },
    monstertypes = {"Ladybug", "Rhino", "Spider", "Scorpion", "Mantis", "Werewolf"},
    coconuts = {},
    crosshairs = {},
    crosshair = false,
    coconut = false,
    act = 0,
    runningfor = 0,
    oldtool = statstable["EquippedCollector"],
    ['gacf'] = function(part, offset)
        local coordd = CFrame.new(part.Position.X, part.Position.Y+offset, part.Position.Z)
        return coordd
    end
}

for i,v in pairs(workspace.MonsterSpawners:GetDescendants()) do if v.Name == "TimerAttachment" then v.Name = "Attachment" end end
for i,v in pairs(workspace.MonsterSpawners:GetChildren()) do if v.Name == "RoseBush" then v.Name = "ScorpionBush" elseif v.Name == "RoseBush2" then v.Name = "ScorpionBush2" end end
for i,v in pairs(workspace.FlowerZones:GetChildren()) do if v:FindFirstChild("ColorGroup") then if v:FindFirstChild("ColorGroup").Value == "Red" then table.insert(temptable.redfields, v.Name) elseif v:FindFirstChild("ColorGroup").Value == "Blue" then table.insert(temptable.bluefields, v.Name) end else table.insert(temptable.whitefields, v.Name) end end

local masktable = {}
for _, v in pairs(game:GetService("ReplicatedStorage").Accessories:GetChildren()) do if string.match(v.Name, "Mask") then table.insert(masktable, v.Name) end end
local collectorstable = {}
-- SOLARA FIX
for _, v in pairs(getupvalues(require(game:GetService("ReplicatedStorage").Collectors).Exists)) do for e,r in pairs(v) do table.insert(collectorstable, e) end end
local fieldstable = {}
for _, v in pairs(workspace.FlowerZones:GetChildren()) do table.insert(fieldstable, v.Name) end
local toystable = {}
for _, v in pairs(workspace.Toys:GetChildren()) do table.insert(toystable, v.Name) end
local spawnerstable = {}
for _, v in pairs(workspace.MonsterSpawners:GetChildren()) do table.insert(spawnerstable, v.Name) end
local accesoriestable = {}
for _, v in pairs(game:GetService("ReplicatedStorage").Accessories:GetChildren()) do if v.Name ~= "UpdateMeter" then table.insert(accesoriestable, v.Name) end end
table.sort(fieldstable)
table.sort(accesoriestable)
table.sort(toystable)
table.sort(spawnerstable)
table.sort(masktable)
-- table.sort(collectorstable)

-- float pad
local floatpad = Instance.new("Part", workspace)
floatpad.CanCollide = false
floatpad.Anchored = true
floatpad.Transparency = 1
floatpad.Name = ""

-- cococrab
local cocopad = Instance.new("Part", workspace)
cocopad.Name = ""
cocopad.Anchored = true
cocopad.Transparency = 1
cocopad.Size = Vector3.new(10, 1, 10)
cocopad.Position = Vector3.new(-307.52117919922, 105.91863250732, 467.86791992188)

-- antfarm
local antpart = Instance.new("Part", workspace)
antpart.Name = ""
antpart.Position = Vector3.new(96, 47, 553)
antpart.Anchored = true
antpart.Size = Vector3.new(128, 1, 50)
antpart.Transparency = 1
antpart.CanCollide = false

-- config

kocmoc = {
    rares = {},
    bestfields = {
        red = "Pepper Patch",
        white = "Coconut Field",
        blue = "Pine Tree Forest"
    },
    blacklistedfields = {},
    bltokens = {},
    toggles = {
        boosting = {},
        autofarm = false,
        farmbubbles = false,
        autodig = false,
        farmrares = false,
        farmfuzzy = false,
        farmcoco = false,
        farmflame = false,
        farmclouds = false,
        killmondo = false,
        touchmondo = false,
        killvicious = false,
        loopspeed = false,
        loopjump = false,
        autoquest = false,
        automask = false,
        autoboosters = false,
        autodispense = false,
        clock = false,
        freeantpass = false,
        freerobopass = false,
        honeystorm = false,
        autodoquest = false,
        disableseperators = false,
        npctoggle = false,
        mobquests = false,
        traincrab = false,
        avoidmobs = false,
        farmsprouts = false,
        farmunderballoons = false,
        farmsnowflakes = false,
        collectgingerbreads = false,
        collectcrosshairs = false,
        farmpuffshrooms = false,
        tptonpc = false,
        donotfarmtokens = false,
        convertballoons = false,
        autostockings = false,
        autosamovar = false,
        autosnowmachine = false,
        autoonettart = false,
        autocandles = false,
        autosnowbear = false,
        autofeast = false,
        autoplanters = false,
        autokillmobs = false,
        autoant = false,
        killwindy = false,
        godmode = false
    },
    vars = {
        field = "Ant Field",
        convertat = 100,
        convertatballoon = 15000000000,
        prefer = "Tokens",
        walkspeed = 70,
        jumppower = 70,
        npcprefer = {
            ["Bucko Bee"] = false,
            ["Riley Bee"] = false,
            ["Black Bear"] = false,
            ["Brown Bear"] = false,
            ["Polar Bear"] = false,
        },
        farmtype = "Walk",
        monstertimer = 3
    },
    dispensesettings = {
        blub = false,
        straw = false,
        treat = false,
        coconut = false,
        glue = false,
        rj = false,
        white = false,
        red = false,
        blue = false
    },
    planters = {
        priority = "Blue",
        farmnectars = {},
    },
}
shared.kocmoc = kocmoc
shared.temptable = temptable
shared.queued = queued
-- SOLARA FIX
for _, nectar in pairs(allnectars) do kocmoc.planters.farmnectars[nectar] = true end
local function addToQueue(id, fn, options)
    options = options or {}
    if not options.ignore_legit and not kocmoc.toggles.legit then return end
    if not kocmoc.toggles.autofarm then return false end
    if queued[id] then return true end
    queued[id] = fn
    return true
end

local defaultkocmoc = kocmoc
local fieldposition
-- functions

-- Global on purpose
local STATSCACHE = table.clone(statstable)

game.ReplicatedStorage.Events.ServerSystemEvent.OnClientEvent:Connect(function(k, t)
    if k == "CacheReset" then
        STATSCACHE = t
        print("stats have been refreshed from server")
    end
end)


function statsget() return STATSCACHE end
function refresh_stats() STATSCACHE = get_latest_player_stats() end


local function getTimeSinceToyActivation(name)
    local t = statsget().ToyTimes[name]
    if not t then return 9999999 end
    return workspace.OsTime.Value - t
end

local function getTimeUntilToyAvailable(n)
    local toy = workspace.Toys[n]
    local cooldown = toy:FindFirstChild("PlaytimeCooldown") and toy.PlaytimeCooldown.Value or toy.Cooldown.Value
    return cooldown - getTimeSinceToyActivation(n)
end

local function canToyBeUsed(toy)
    local timeleft = getTimeUntilToyAvailable(toy)
    return timeleft <= 0
end



local function disableall()
    if kocmoc.toggles.autofarm and not temptable.converting then
        temptable.cache.autofarm = true
        kocmoc.toggles.autofarm = false
    end
    if kocmoc.toggles.killmondo and not temptable.started.mondo then
        kocmoc.toggles.killmondo = false
        temptable.cache.killmondo = true
    end
    if kocmoc.toggles.killvicious and not temptable.started.vicious then
        kocmoc.toggles.killvicious = false
        temptable.cache.vicious = true
    end
    if kocmoc.toggles.killwindy and not temptable.started.windy then
        kocmoc.toggles.killwindy = false
        temptable.cache.windy = true
    end
end

local function enableall()
    if temptable.cache.autofarm then
        kocmoc.toggles.autofarm = true
        temptable.cache.autofarm = false
    end
    if temptable.cache.killmondo then
        kocmoc.toggles.killmondo = true
        temptable.cache.killmondo = false
    end
    if temptable.cache.vicious then
        kocmoc.toggles.killvicious = true
        temptable.cache.vicious = false
    end
    if temptable.cache.windy then
        kocmoc.toggles.killwindy = true
        temptable.cache.windy = false
    end
end

local function makesprinklers()
    local sprinkler = statsget().EquippedSprinkler
    local e = 1
    if sprinkler == "Basic Sprinkler" or sprinkler == "The Supreme Saturator" then
        e = 1
    elseif sprinkler == "Silver Soakers" then
        e = 2
    elseif sprinkler == "Golden Gushers" then
        e = 3
    elseif sprinkler == "Diamond Drenchers" then
        e = 4
    end
    for i = 1, e do
        k = api.humanoid().JumpPower
        if e ~= 1 then api.humanoid().JumpPower = 70 api.humanoid().Jump = true task.wait(.2) end
        game.ReplicatedStorage.Events.PlayerActivesCommand:FireServer({["Name"] = "Sprinkler Builder"})
        if e ~= 1 then api.humanoid().JumpPower = k task.wait(1) end
    end
end

task.spawn(function()
    while task.wait() do
        local suc, err = pcall(function()
            Pipes.processCommands(function(command)
                if command == "send_honey" then
                    Pipes.toAHK({
                        Type = "update_honey",
                        Honey = HoneyStat.Value
                    })
                elseif command == "send_buffs" then
                    compile_buff_list()
                elseif command == "send_planters" then
                    compile_planters()
                elseif command == "ping" then
                    Pipes.toAHK({
                        Type = "pong",
                    })
                end
            end)
        end)
        if not suc then
            print("Error processing commands: ", err)
        end
    end
end)

local function balloonBlessingTimerLow()
    return get_buff_active_duration("Balloon Blessing") > (45*60)
end

local function avoidmobs()
    if not game.Players.LocalPlayer.Character:FindFirstChild("Humanoid") then return end
    for i, v in pairs(workspace.Monsters:GetChildren()) do
        if v:FindFirstChild("Head") then
            if (v.Head.Position-game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude < 30 and api.humanoid():GetState() ~= Enum.HumanoidStateType.Freefall then
                game.Players.LocalPlayer.Character.Humanoid.Jump = true
            end
        end
    end
end

local get_my_monsters
do
    local monsters = {}
    workspace.Monsters.ChildAdded:Connect(function(x)
        local target = x:WaitForChild("Target", 3)
        if target and target.Value == game.Players.LocalPlayer.Character then
            table.insert(monsters, x)
            x.AncestryChanged:Connect(function(_, parent)
                if not parent then
                    table.remove(monsters, table.find(monsters, x))
                end
            end)
        end
    end)
    get_my_monsters = function()
        return monsters
    end
end

local function killmobs()
    Pipes.toAHK({
        Type = "set_script_status",
        Status = 0,
    })
    local mob_spawns = {}
    for i,v in pairs(workspace.MonsterSpawners:GetChildren()) do
        if v:FindFirstChild("Territory") then
            if v.Name ~= "Commando Chick" and v.Name ~= "CoconutCrab" and v.Name ~= "StumpSnail" and v.Name ~= "TunnelBear" and v.Name ~= "King Beetle Cave" and not v.Name:match("CaveMonster") and not v:FindFirstChild("TimerLabel", true).Visible then
                if v:FindFirstChild("TimerLabel", true).Visible then continue end
                local monsterpart
                if v.Name:match("Werewolf") then
                    monsterpart = workspace.Territories.WerewolfPlateau.w
                elseif v.Name:match("Mushroom") then
                    monsterpart = workspace.Territories.MushroomZone.Part
                else
                    monsterpart = v.Territory.Value
                end
                table.insert(mob_spawns, {
                    Part = monsterpart,
                    v = v,
                })
                
            end
        end
    end

    while #mob_spawns > 0 do
        local index, d = (function()
            local closest, closestMag = nil, math.huge
            for index, d in pairs(mob_spawns) do
                local mag = (game.Players.LocalPlayer.Character:GetPrimaryPartCFrame().Position - d.Part.Position).Magnitude
                if mag < closestMag then
                    closest, closestMag = {index, d}, mag
                end
            end
            if not closest then return nil, nil end
            return closest[1], closest[2]
        end)()
        if not d then break end
        local monsterpart, v = d.Part, d.v
        if v:FindFirstChild("TimerLabel", true).Visible then
            table.remove(mob_spawns, index)
            continue
        end

        local mob_count = #get_my_monsters()
        if kocmoc.toggles.legit then
            routeToField(find_field(monsterpart.Position))
            if find_field((game.Players.LocalPlayer.Character.PrimaryPart.Position)) == find_field(monsterpart.Position) then
                if game.Players.LocalPlayer.Character:FindFirstChild("Humanoid") then
                    game.Players.LocalPlayer.Character.Humanoid:MoveTo(monsterpart.Position)
                    task.wait(2)
                end
            end
        end

        -- move on if no new mobs are detected after 3 seconds.
        local timeout = false
        task.spawn(function()
            local ltimeout = false
            task.spawn(function()
                task.wait(2)
                ltimeout = true
            end)
            repeat task.wait() until #get_my_monsters() ~= mob_count or ltimeout
            timeout = ltimeout
        end)
        
        api.humanoidrootpart().CFrame = monsterpart.CFrame
        local died = false
        local conndied = game.Players.LocalPlayer.Character:WaitForChild("Humanoid").Died:Once(function()
            print("died.")
            died = true
            timeout = true
        end)
        repeat avoidmobs(); task.wait(1) until v:FindFirstChild("TimerLabel", true).Visible or timeout or died
        if conndied then conndied:Disconnect() end

        if timeout then
            table.remove(mob_spawns, index)
            if died then print("died heard. breaking.") break end
            continue
        end
        task.wait(2)
        for i = 1, 3 do gettoken(monsterpart.Position) end
        Pipes.toAHK({
            Type = "increment_stat",
            Stat = "Total Bug Kills",
        })
    end
    Pipes.toAHK({
        Type = "set_script_status",
        Status = 1,
    })
end

local function farmant()
    if kocmoc.toggles.legit then
        routeToField("Toys/Ant Challenge")
        task.wait(1)
    end

    antpart.CanCollide = true
    temptable.started.ant = true
    anttable = {left = true, right = false}
    local stats = get_latest_player_stats()
    temptable.oldtool = stats['EquippedCollector']
    temptable.oldmask = stats["SessionAccessories"]["Hat"]
    temptable.float = true
    equip_mask("Demon Mask")
    game.ReplicatedStorage.Events.ItemPackageEvent:InvokeServer("Equip",{["Mute"] = true,["Type"] = "Spark Staff",["Category"] = "Collector"})
    game.ReplicatedStorage.Events.ToyEvent:FireServer("Ant Challenge")
    kocmoc.toggles.autodig = true
    acl = CFrame.new(133, 48, 591)
    acr = CFrame.new(43, 48, 592)
    task.wait(1)
    game.ReplicatedStorage.Events.PlayerActivesCommand:FireServer({["Name"] = "Sprinkler Builder"})
    api.humanoidrootpart().CFrame = api.humanoidrootpart().CFrame + Vector3.new(0, 15, 0)
    floatpad.CanCollide = true floatpad.CFrame = CFrame.new(game.Players.LocalPlayer.Character.HumanoidRootPart.Position.X, game.Players.LocalPlayer.Character.HumanoidRootPart.Position.Y-3.5, game.Players.LocalPlayer.Character.HumanoidRootPart.Position.Z)
    task.wait(3)
    repeat
        task.wait()
        for i,v in next, workspace.Toys["Ant Challenge"].Obstacles:GetChildren() do
            if v:FindFirstChild("Root") then
                if (v.Root.Position-api.humanoidrootpart().Position).magnitude <= 40 and anttable.left then
                    api.humanoidrootpart().CFrame = acr
                    floatpad.CanCollide = true floatpad.CFrame = CFrame.new(game.Players.LocalPlayer.Character.HumanoidRootPart.Position.X, game.Players.LocalPlayer.Character.HumanoidRootPart.Position.Y-3.5, game.Players.LocalPlayer.Character.HumanoidRootPart.Position.Z)
                    anttable.left = false anttable.right = true
                    wait(.1)
                elseif (v.Root.Position-api.humanoidrootpart().Position).magnitude <= 40 and anttable.right then
                    api.humanoidrootpart().CFrame = acl
                    floatpad.CanCollide = true floatpad.CFrame = CFrame.new(game.Players.LocalPlayer.Character.HumanoidRootPart.Position.X, game.Players.LocalPlayer.Character.HumanoidRootPart.Position.Y-3.5, game.Players.LocalPlayer.Character.HumanoidRootPart.Position.Z)
                    anttable.left = true anttable.right = false
                    wait(.1)
                end
            end
        end
    until not workspace.Toys["Ant Challenge"].Busy.Value
    task.wait(1)
    game.ReplicatedStorage.Events.ItemPackageEvent:InvokeServer("Equip", {
        Type = temptable.oldtool,
        Category = "Collector",
    })
    -- route BACK
    playRoute("Toys/Free Ant Pass Dispenser", "Dandelion Field")
    equip_mask(temptable.oldmask)
    temptable.started.ant = false
    temptable.float = false
    antpart.CanCollide = false
    floatpad.CanCollide = false
end





local rotationalForce
local function characterAdded(character)
	rotationalForce = Instance.new("AlignOrientation")
	rotationalForce.RigidityEnabled = true
	rotationalForce.Mode = Enum.OrientationAlignmentMode.OneAttachment
	rotationalForce.Attachment0 = character.PrimaryPart:WaitForChild("RootRigAttachment")
	rotationalForce.Parent = character.PrimaryPart
    rotationalForce.Enabled = false
end
if game.Players.LocalPlayer.Character then characterAdded(game.Players.LocalPlayer.Character) end
game.Players.LocalPlayer.CharacterAdded:Connect(characterAdded)

local function shortestDistance(lineStart, lineDir, point)
    local v = point - lineStart
    local lenSq = lineDir:Dot(lineDir)
    local t = lineDir:Dot(v) / lenSq
    local nearestPoint = lineStart + lineDir * t
    return (point - nearestPoint).Magnitude
end
local BuffTile = require(game:GetService("ReplicatedStorage"):WaitForChild("Gui"):WaitForChild("TileDisplay"):WaitForChild("BuffTile"))

local tidalsurge_rotate = function()
    local character = game.Players.LocalPlayer and game.Players.LocalPlayer.Character
    local humanoid = character and character:FindFirstChild("Humanoid")
    if not character or not humanoid then return end
    local is_surging = select(1, BuffTile.GetBuffInfo("Tidal Surge"))
    if is_surging then
        humanoid.AutoRotate = false
        rotationalForce.Enabled = true
        
        -- we can manually rotate now
        -- scan a full 2pi rotations around the player, creating a ray every iteration and checking how many balloons is within [THRESHOLD] distance of the ray.
        
        local valid_balloons = {}
        for i, v in pairs(workspace.Balloons.FieldBalloons:GetChildren()) do
            if v:FindFirstChild("BalloonRoot") and v:FindFirstChild("PlayerName") then
                if v:FindFirstChild("PlayerName").Value == game.Players.LocalPlayer.Name then
                    if tonumber((v.BalloonRoot.Position-game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude) < temptable.magnitude/1.4 then
                        table.insert(valid_balloons, v.BalloonRoot.Position)
                    end
                end
            end
        end
        
        local theta = 0 
        local two_pi = 2*math.pi
        local delta_theta = two_pi / 16
        local results = {}
        while theta < two_pi do
            local direction_vector = Vector3.new(math.sin(theta), 0, math.cos(theta))
            local score = 0
            for _, balloonpos in pairs(valid_balloons) do
                local dist = shortestDistance(
                    character.PrimaryPart.Position,
                    direction_vector,
                    balloonpos
                )

                if dist < 15 then
                    score += 1
                end
            end

            results[theta] = score
            theta += delta_theta
        end

        -- find the highest score, and face that direction.
        local highestscore = 0
        local highest_score_theta = 0
        for theta, score in results do
            if score > highestscore then
                highestscore = score
                highest_score_theta = theta
            end
        end
        if highestscore > 0 then
            local pos = character:GetPrimaryPartCFrame().Position
            rotationalForce.CFrame = 
                CFrame.new(pos, pos + Vector3.new(math.sin(highest_score_theta), 0, math.cos(highest_score_theta)))
            print("theta = ", highest_score_theta * (180/math.pi))
            print("score = ", highestscore)
        else
            print("highest score = 0! no balloons!!!")
        end
    else
        humanoid.AutoRotate = true
        rotationalForce.Enabled = false
    end
end

game:GetService("RunService").RenderStepped:Connect(function(dt)
    tidalsurge_rotate()
end)

local attempt_snowbear = function()
    temptable.oldmask = get_latest_player_stats()["SessionAccessories"]["Hat"]
    equip_mask("Demon Mask")
    -- attempt to find snowbear

    local callback = function()
        local snowbear
        for _, monster in pairs(get_my_monsters()) do
            if string.find(monster.Name, "Snowbear") then
                snowbear = monster
                break
            end
        end
        if not snowbear then
            return warn("Can't find snowbear!")
        end

        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Whitelist
        raycastParams.FilterDescendantsInstances = {workspace.Gates, workspace["Invisible Walls"], workspace.Map, snowbear}
        local running = true
        local mode = "avoid"
        local cycle = 1
        task.spawn(function()
            while running do
                if mode == "avoid" then
                    local offsets = {
                        Vector3.new(1, 0, 0),
                        Vector3.new(1, 0, 1),
                        Vector3.new(-1, 0, 1),
                        Vector3.new(-1, 0, -1),
                    }
                    local compute_destination
                    compute_destination = function()
                        if not snowbear.Parent then return game.Players.LocalPlayer.Character:WaitForChild("HumanoidRootPart").Position end
                        local ppp = game.Players.LocalPlayer.Character.PrimaryPart.Position
                        local offset = offsets[1 + cycle % 4]
                        local dest = snowbear.PrimaryPart.Position + offset * 30
                        local raycast = workspace:Raycast(ppp, CFrame.new(ppp, dest * Vector3.new(1, 0, 1) + ppp * Vector3.new(0, 1, 0)).LookVector * 20, raycastParams)
                        if raycast then
                            if raycast.Instance:IsDescendantOf(snowbear) then
                                -- uh oh! this position is blocked by snow bear. running to this destination will hurt us. Try a different position.
                                cycle += 1
                                task.wait() -- prevent crashing
                                return compute_destination()
                            end
                            dest = raycast.Position -- the position is blocked by a fence or something. Just walk there.
                        end
                        return dest * Vector3.new(1, 0, 1) + ppp * Vector3.new(0, 1, 0)
                    end
                    repeat
                        task.wait()
                        if game.Players.LocalPlayer.Character:FindFirstChild("Humanoid") then
                            game.Players.LocalPlayer.Character.Humanoid:MoveTo(compute_destination())
                        end
                        while get_buff_combo("Frozen") do task.wait() end
                    until (game.Players.LocalPlayer.Character.PrimaryPart.Position - compute_destination()).Magnitude < 4 or not running or mode ~= "avoid"
                    cycle += 1
                end
                task.wait()
            end
        end) -- worker
        local primary = snowbear.PrimaryPart
        local died = false
        while running do
            for _, token in pairs(workspace.Collectibles:GetChildren()) do
                local tokenType = identifyToken(token)
                if find_field(token.Position) == "Spider Field" and tokenType and table.find({"Snowflake", "Token Link", "Mind Hack"}, tokenType) and ((token.Position - snowbear.PrimaryPart.Position) * Vector3.new(1, 0, 1)).Magnitude > 15 then
                    mode = "token"
                    farm(token)
                    mode = "avoid"
                end
            end
            if not snowbear.Parent then
                break
            end
            if not game.Players.LocalPlayer.Character:FindFirstChild("Humanoid") or game.Players.LocalPlayer.Character.Humanoid.Health <= 0 then
                -- died, exit.
                died = true
                break
            end
            task.wait()
        end -- status updater
        running = false
        if not died then
            for i=1, 5 do gettoken(primary.Position) end
        else
            task.wait(10)
        end
    end

    callback()

    task.wait(1)
    equip_mask(temptable.oldmask)
end

local function converthoney()
    if temptable.converting then
        if game.Players.LocalPlayer.PlayerGui.ScreenGui.ActivateButton.TextBox.Text ~= "Stop Making Honey" and game.Players.LocalPlayer.PlayerGui.ScreenGui.ActivateButton.BackgroundColor3 ~= Color3.new(201, 39, 28) or (game:GetService("Players").LocalPlayer.SpawnPos.Value.Position-game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude > 10 then
            api.tween(nil, game:GetService("Players").LocalPlayer.SpawnPos.Value * CFrame.fromEulerAnglesXYZ(0, 110, 0) + Vector3.new(0, 0, 9))
            task.wait(.9)
            if game.Players.LocalPlayer.PlayerGui.ScreenGui.ActivateButton.TextBox.Text ~= "Stop Making Honey" and game.Players.LocalPlayer.PlayerGui.ScreenGui.ActivateButton.BackgroundColor3 ~= Color3.new(201, 39, 28) or (game:GetService("Players").LocalPlayer.SpawnPos.Value.Position-game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude > 10 then game:GetService("ReplicatedStorage").Events.PlayerHiveCommand:FireServer("ToggleHoneyMaking") end
            task.wait(.1)
        end
    end
end

local function walk_to_bubble()
    for i, v in pairs(workspace.Particles:GetChildren()) do
        if string.find(v.Name, "Bubble") and temptable.running == false and tonumber((v.Position-game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude) < temptable.magnitude/1.4 then
            api.humanoid():MoveTo(v.Position)
            repeat task.wait() until (game.Players.LocalPlayer.Character.PrimaryPart.Position * Vector3.new(1,0,1) - v.Position * Vector3.new(1,0,1)).Magnitude < 11 or not v.Parent
        end
    end
end

local function walk_under_balloons()
    for i, v in pairs(workspace.Balloons.FieldBalloons:GetChildren()) do
        if v:FindFirstChild("BalloonRoot") and v:FindFirstChild("PlayerName") then
            if v:FindFirstChild("PlayerName").Value == game.Players.LocalPlayer.Name then
                if tonumber((v.BalloonRoot.Position-game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude) < temptable.magnitude/1.4 then
                    api.walkTo(v.BalloonRoot.Position)
                end
            end
        end
    end
end

local function walk_under_clouds()
    for i, v in pairs(workspace.Clouds:GetChildren()) do
        e = v:FindFirstChild("Plane")
        if e and tonumber((e.Position-game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude) < temptable.magnitude/1.4 then
            api.walkTo(e.Position)
        end
    end
end

local function getcoco(v)
    if temptable.coconut then repeat task.wait() until not temptable.coconut end
    temptable.coconut = true
    api.tween(.1, v.CFrame)
    repeat task.wait() api.walkTo(v.Position) until not v.Parent
    task.wait(.1)
    temptable.coconut = false
    table.remove(temptable.coconuts, table.find(temptable.coconuts, v))
end

local function walk_to_fuzzies()
    pcall(function()
        for i, v in pairs(workspace.Particles:GetChildren()) do
            if v.Name == "DustBunnyInstance" and temptable.running == false and tonumber((v.Plane.Position-game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude) < temptable.magnitude/1.4 then
                if v:FindFirstChild("Plane") then
                    farm(v:FindFirstChild("Plane"))
                    break
                end
            end
        end
    end)
end

local darkFlameColor = game:GetService("ReplicatedStorage"):WaitForChild("LocalFX"):WaitForChild("LocalFlames"):WaitForChild("DarkFlame"):WaitForChild("PF").Color

local function getflame()
    for i, v in pairs(workspace.PlayerFlames:GetChildren()) do
        local isFlameDark = v:WaitForChild("PF").Color == darkFlameColor
        if not isFlameDark then
            local mag = tonumber((v.Position-game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude)
            if mag < 3 or mag > 250 then continue end
            if mag < 25 then
                local lc = game.Players.LocalPlayer.Character:GetPrimaryPartCFrame()
                local lp = lc.Position
                game.Players.LocalPlayer.Character:SetPrimaryPartCFrame(CFrame.new(lp * Vector3.new(1, 0, 1), v.Position * Vector3.new(1, 0, 1) - lc.LookVector * 0.1) + lp * Vector3.new(0, 1, 0))
                v:SetAttribute("_collected", true)
            elseif not v:GetAttribute("_collected") then
                local lc = game.Players.LocalPlayer.Character:GetPrimaryPartCFrame()
                local lp = lc.Position
                local cf = CFrame.new(lp * Vector3.new(1, 0, 1), v.Position * Vector3.new(1, 0, 1) - lc.LookVector * 0.1) + lp * Vector3.new(0, 1, 0)
                farm({
                    Position = v.Position - cf.LookVector * 15
                })
            end
            break
        end
    end
end

local function hasboosttokenquest()
    if game:GetService("Players").LocalPlayer.PlayerGui.ScreenGui.Menus.Children.Quests.Content:FindFirstChild("Frame") then
        for i, v in pairs(game:GetService("Players").LocalPlayer.PlayerGui.ScreenGui.Menus.Children.Quests:GetDescendants()) do
            if v.Name == "Description" then
                local npcconsidered = false
                for npc, _ in pairs(kocmoc.vars.npcprefer) do
                    if string.match(v.Parent.Parent.TitleBarBG.TitleBar.Text, npc) then
                        npcconsidered = true
                        break
                    end
                end
                if not npcconsidered then continue end
                if not string.find(v.Text, "Puffshroom") then
                    if (string.find(v.Text, "Red Boost") or string.find(v.Text, "Blue Boost")) and not string.find(v.Text, "Complete!") then
                        return true
                    end
                end
            end
        end
    end
end

local function hasBoosterQuest()
    if game:GetService("Players").LocalPlayer.PlayerGui.ScreenGui.Menus.Children.Quests.Content:FindFirstChild("Frame") then
        for i, v in pairs(game:GetService("Players").LocalPlayer.PlayerGui.ScreenGui.Menus.Children.Quests:GetDescendants()) do
            if v.Name == "Description" then
                local npcconsidered = false
                for npc, _ in pairs(kocmoc.vars.npcprefer) do
                    if string.match(v.Parent.Parent.TitleBarBG.TitleBar.Text, npc) then
                        npcconsidered = true
                        break
                    end
                end
                if not npcconsidered then continue end
                if not string.find(v.Text, "Puffshroom") then
                    if string.find(v.Text, "Field Booster") and not string.find(v.Text, "Complete!") then
                        return true
                    end
                end
            end
        end
    end
end

local function hasFruitTokenQuest()
    if game:GetService("Players").LocalPlayer.PlayerGui.ScreenGui.Menus.Children.Quests.Content:FindFirstChild("Frame") then
        for i, v in pairs(game:GetService("Players").LocalPlayer.PlayerGui.ScreenGui.Menus.Children.Quests:GetDescendants()) do
            if v.Name == "Description" then
                local npcconsidered = false
                for npc, _ in pairs(kocmoc.vars.npcprefer) do
                    if string.match(v.Parent.Parent.TitleBarBG.TitleBar.Text, npc) then
                        npcconsidered = true
                        break
                    end
                end
                if not npcconsidered then continue end
                if not string.find(v.Text, "Puffshroom") then
                    if (string.find(v.Text, "Strawberry Tokens") or string.find(v.Text, "Blueberry Tokens")) and not string.find(v.Text, "Complete!") then
                        return true
                    end
                end
            end
        end
    end
end

task.spawn(function()
    while task.wait(40) do
        if kocmoc.toggles.autofarm and kocmoc.toggles.autodoquest then
            if hasFruitTokenQuest() and table.find({"Pepper Patch", "Stump Field", "Pine Tree Forest"}, kocmoc.vars.field) then
                fieldselected = workspace.FlowerZones[kocmoc.vars.field]
                fieldposition = fieldselected.Position
                if (fieldposition-game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude <= temptable.magnitude then -- if the player's on their best blue/red field
                    game:GetService("ReplicatedStorage").Events.PlayerActivesCommand:FireServer({
                        ["Name"] = "Magic Bean"
                    })
                end
            end
        end
    end
end)

local function getcrosshairs(v)
    if v.BrickColor ~= BrickColor.new("Lime green") and v.BrickColor ~= BrickColor.new("Flint") then
        if temptable.crosshair then repeat task.wait() until not temptable.crosshair end
        temptable.crosshair = true
        api.walkTo(v.Position)
        repeat task.wait() api.walkTo(v.Position) until not v.Parent or v.BrickColor == BrickColor.new("Forest green")
        task.wait(.1)
        temptable.crosshair = false
        table.remove(temptable.crosshairs, table.find(temptable.crosshairs, v))
    else
        table.remove(temptable.crosshairs, table.find(temptable.crosshairs, v))
    end
end

local function makequests()
    for i, v in pairs(workspace.NPCs:GetChildren()) do
        local considered = false
        for npc, _ in pairs(kocmoc.vars.npcprefer) do
            if npc == v.Name then
                considered = true
                break
            end
        end
        if considered then if v:FindFirstChild("Platform") then if v.Platform:FindFirstChild("AlertPos") then if v.Platform.AlertPos:FindFirstChild("AlertGui") then if v.Platform.AlertPos.AlertGui:FindFirstChild("ImageLabel") then
            local image = v.Platform.AlertPos.AlertGui.ImageLabel
            if image.ImageTransparency == 0 then
                addToQueue("claim_quest:"..v.Name, function()
                    local hasRoute = table.find({"Black Bear", "Bucko Bee", "Polar Bear", "Brown Bear", "Riley Bee"}, v.Name)
                    if kocmoc.toggles.legit and hasRoute then
                        if v.Name == "Polar Bear" then
                            routeToField("Pumpkin Patch")
                            playRoute("Pumpkin Patch", "NPC/Polar Bear")
                        elseif v.Name == "Black Bear" then
                            routeToField("hive")
                            playRoute("hive", "NPC/Black Bear")
                        elseif v.Name == "Bucko Bee" then
                            routeToField("Blue Flower Field")
                            playRoute("Blue Flower Field", "NPC/Bucko Bee")
                        elseif v.Name == "Brown Bear" then
                            routeToField("Clover Field")
                            playRoute("Clover Field", "NPC/Brown Bear")
                        elseif v.Name == "Riley Bee" then
                            routeToField("Rose Field")
                            playRoute("Rose Field", "NPC/Riley Bee")
                        end
                    else
                        if kocmoc.toggles.tptonpc then
                            game.Players.LocalPlayer.Character:WaitForChild("Humanoid"):Move(Vector3.zero)
                            game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(v.Platform.Position.X, v.Platform.Position.Y+3, v.Platform.Position.Z)
                            task.wait(1)
                            game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(v.Platform.Position.X, v.Platform.Position.Y+3, v.Platform.Position.Z)
                        else
                            api.tween(nil,CFrame.new(v.Platform.Position.X, v.Platform.Position.Y+3, v.Platform.Position.Z))
                            task.wait(3)
                        end
                    end
                    -- send "E"
                    task.wait(1)
                    game:GetService("VirtualInputManager"):SendKeyEvent(true, Enum.KeyCode.E, false, game)
                    task.wait(.1)
                    game:GetService("VirtualInputManager"):SendKeyEvent(false, Enum.KeyCode.E, false, game)
                    Pipes.toAHK({
                        Type = "increment_stat",
                        Stat = "Quests Done",
                    })
                    task.wait(8)
                    if image.ImageTransparency == 0 then
                        game:GetService("VirtualInputManager"):SendKeyEvent(true, Enum.KeyCode.E, false, game)
                        task.wait(.1)
                        game:GetService("VirtualInputManager"):SendKeyEvent(false, Enum.KeyCode.E, false, game)
                    end
                    task.wait(2)
                    if kocmoc.toggles.legit and hasRoute then
                        if v.Name == "Polar Bear" then
                            playRoute("NPC/Polar Bear", "Pumpkin Patch")
                        elseif v.Name == "Black Bear" then
                            playRoute("NPC/Black Bear", "hive")
                        elseif v.Name == "Bucko Bee" then
                            playRoute("NPC/Bucko Bee", "Blue Flower Field")
                        elseif v.Name == "Brown Bear" then
                            playRoute("NPC/Brown Bear", "Clover Field")
                        elseif v.Name == "Riley Bee" then
                            playRoute("NPC/Riley Bee", "Rose Field")
                        end
                    end
                end)
            end
        end     
    end end end end end
end

local function convert_all()
    local stats = statsget()
    if stats.Eggs["Micro-Converter"] > 12 then
        game:GetService("ReplicatedStorage").Events.PlayerActivesCommand:FireServer({
            ["Name"] = "Micro-Converter"
        })
        return true
    end
    local availability = {getTimeUntilToyAvailable("Instant Converter"), getTimeUntilToyAvailable("Instant Converter B"), getTimeUntilToyAvailable("Instant Converter C")}
    for i = 1, 3 do
        if availability[i] <= 0 then
            game:GetService("ReplicatedStorage").Events.ToyEvent:FireServer("Instant Converter"..(({"", " B", " C"})[i]))
            return true
        end
    end
    if stats.Eggs["Micro-Converter"] > 0 then
        game:GetService("ReplicatedStorage").Events.PlayerActivesCommand:FireServer({
            ["Name"] = "Micro-Converter"
        })
        return true
    end
end

local Config = { WindowName = "🌘 kocmoc | "..temptable.version, Color = Color3.fromRGB(164, 84, 255), Keybind = Enum.KeyCode.Semicolon}
local Window = library:CreateWindow(Config, game:GetService("CoreGui"))

local _buttons = {}
local hometab = Window:CreateTab("Home")
local farmtab = Window:CreateTab("Farming")
local combtab = Window:CreateTab("Combat")
local wayptab = Window:CreateTab("Waypoints")
local misctab = Window:CreateTab("Misc")
local extrtab = Window:CreateTab("Extra")
local setttab = Window:CreateTab("Settings")

local information = hometab:CreateSection("Information")
information:CreateLabel("Thanks you for using my script :)")
information:CreateLabel("Script version: "..temptable.version)
information:CreateLabel("Place version: "..game.PlaceVersion)
information:CreateLabel("⚠️ - Risky")
information:CreateLabel("⚙ - Configurable")
information:CreateLabel("Script rewritten by WhutThe")
information:CreateLabel("Fork of kocmoc by weuz_ and mrdevl")

local gainedSection = hometab:CreateSection("Gained")
gainedSection:CreateButton("Reset Timer/Gained Honey", function()
    temptable.runningfor = 0
    temptable.honeystart = HoneyStat.Value
end)
gainedSection:CreateButton("Force Refresh Stats", function()
    refresh_stats()
end)
local timepassedlabel = gainedSection:CreateLabel("Time Elapsed: 0:0:0")
local gainedhoneylabel = gainedSection:CreateLabel("Gained Honey: 0")
local balloonSize = gainedSection:CreateLabel("Balloon")
local avghoney_s = gainedSection:CreateLabel("Average Honey / Second: 0")
local avghoney_m = gainedSection:CreateLabel("Average Honey / Minute: 0")
local avghoney_h = gainedSection:CreateLabel("Average Honey / Hour: 0")
local avghoney_d = gainedSection:CreateLabel("Average Honey / Day: 0")
local gainedEggToLabel = {}

local start_eggs = statsget().Totals.EggsReceived

local misccv = hometab:CreateSection("Instant Converters")
local misccva = misccv:CreateButton("Instant Converter A", function() game:GetService("ReplicatedStorage").Events.ToyEvent:FireServer("Instant Converter") end)
local misccvb = misccv:CreateButton("Instant Converter B", function() game:GetService("ReplicatedStorage").Events.ToyEvent:FireServer("Instant Converter B") end)
local misccvc = misccv:CreateButton("Instant Converter C", function() game:GetService("ReplicatedStorage").Events.ToyEvent:FireServer("Instant Converter C") end)
local misccvauto = misccv:CreateButton("Instant Convert", convert_all)
game:GetService("UserInputService").InputBegan:Connect(function(input, gp)if not gp and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.T then convert_all() end end)

local farmo = farmtab:CreateSection("Farming")
local fielddropdown = farmo:CreateDropdown("Field", fieldstable, function(String) kocmoc.vars.field = String end) fielddropdown:SetOption(fieldstable[1])
convertatslider = farmo:CreateSlider("Convert At", 0, 100, 100, false, function(Value) kocmoc.vars.convertat = Value end)
_buttons["convertat"] = convertatslider
local convertatslider_balloon = farmo:CreateSlider("Convert Balloon At", 10000000000, 250000000000, 15000000000, false, function(Value) kocmoc.vars.convertatballoon = Value end)
_buttons["convertatballoon"] = convertatslider_balloon
local autofarmtoggle = farmo:CreateToggle("Autofarm ⚙", nil, function(State) kocmoc.toggles.autofarm = State end) autofarmtoggle:CreateKeybind("U", function(Key) end)
_buttons["autofarm"] = autofarmtoggle
_buttons["autodig"] = farmo:CreateToggle("Autodig", nil, function(State) kocmoc.toggles.autodig = State end)
_buttons["autosprinkler"] = farmo:CreateToggle("Auto Sprinkler", nil, function(State) kocmoc.toggles.autosprinkler = State end)
_buttons["farmbubbles"] = farmo:CreateToggle("Farm Bubbles", nil, function(State) kocmoc.toggles.farmbubbles = State end)
_buttons["farmflame"] = farmo:CreateToggle("Farm Flames", nil, function(State) kocmoc.toggles.farmflame = State end)
_buttons["farmcoco"] = farmo:CreateToggle("Farm Coconuts & Shower", nil, function(State) kocmoc.toggles.farmcoco = State end)
_buttons["collectcrosshairs"] = farmo:CreateToggle("Farm Precise Crosshairs", nil, function(State) kocmoc.toggles.collectcrosshairs = State end)
_buttons["farmfuzzy"] = farmo:CreateToggle("Farm Fuzzy Bombs", nil, function(State) kocmoc.toggles.farmfuzzy = State end)
_buttons["farmunderballoons"] = farmo:CreateToggle("Farm Under Balloons", nil, function(State) kocmoc.toggles.farmunderballoons = State end)
_buttons["farmclouds"] = farmo:CreateToggle("Farm Under Clouds", nil, function(State) kocmoc.toggles.farmclouds = State end)

local farmt = farmtab:CreateSection("Farming")
_buttons["autodispense"] = farmt:CreateToggle("Auto Dispenser ⚙", nil, function(State) kocmoc.toggles.autodispense = State end)
_buttons["autoboosters"] = farmt:CreateToggle("Auto Field Boosters ⚙", nil, function(State) kocmoc.toggles.autoboosters = State end)
_buttons["clock"] = farmt:CreateToggle("Auto Wealth Clock", nil, function(State) kocmoc.toggles.clock = State end)
_buttons["collectgingerbreads"] = farmt:CreateToggle("Auto Gingerbread Bears", nil, function(State) kocmoc.toggles.collectgingerbreads = State end)
_buttons["autosamovar"] = farmt:CreateToggle("Auto Samovar", nil, function(State) kocmoc.toggles.autosamovar = State end)
_buttons["autosnowmachine"] = farmt:CreateToggle("Auto Snow Machine", nil, function(State) kocmoc.toggles.autosnowmachine = State end)
_buttons["autostockings"] = farmt:CreateToggle("Auto Stockings", nil, function(State) kocmoc.toggles.autostockings = State end)
_buttons["autoplanters"] = farmt:CreateToggle("Auto Planters ⚙", nil, function(State) kocmoc.toggles.autoplanters = State end):AddToolTip("Will re-plant your planters after converting, if they hit 100%")
_buttons["autocandles"] = farmt:CreateToggle("Auto Honey Candles", nil, function(State) kocmoc.toggles.autocandles = State end)
_buttons["autosnowbear"] = farmt:CreateToggle("Auto Snow Bear", nil, function(State) kocmoc.toggles.autosnowbear = State end):AddToolTip("This will only work if you have Legit Mode on!")
_buttons["autofeast"] = farmt:CreateToggle("Auto Beesmas Feast", nil, function(State) kocmoc.toggles.autofeast = State end)
_buttons["autoonettart"] = farmt:CreateToggle("Auto Onett's Lid Art", nil, function(State) kocmoc.toggles.autoonettart = State end)
_buttons["freeantpass"] = farmt:CreateToggle("Auto Free Antpasses", nil, function(State) kocmoc.toggles.freeantpass = State end)
_buttons["freerobopass"] = farmt:CreateToggle("Auto Free Robopasses", nil, function(State) kocmoc.toggles.freerobopass = State end)
_buttons["farmsprouts"] = farmt:CreateToggle("Farm Sprouts", nil, function(State) kocmoc.toggles.farmsprouts = State end)
_buttons["farmpuffshrooms"] = farmt:CreateToggle("Farm Puffshrooms", nil, function(State) kocmoc.toggles.farmpuffshrooms = State end)
_buttons["farmsnowflakes"] = farmt:CreateToggle("Farm Snowflakes ⚠️", nil, function(State) kocmoc.toggles.farmsnowflakes = State end)
_buttons["farmrares"] = farmt:CreateToggle("Teleport To Rares ⚠️", nil, function(State) kocmoc.toggles.farmrares = State end)
_buttons["autoquest"] = farmt:CreateToggle("Auto Accept/Confirm Quests ⚙", nil, function(State) kocmoc.toggles.autoquest = State end)
_buttons["autodoquest"] = farmt:CreateToggle("Auto Do Quests ⚙", nil, function(State) kocmoc.toggles.autodoquest = State end)
_buttons["automask"] = farmt:CreateToggle("Auto Mask", nil, function(State) kocmoc.toggles.automask = State end):AddToolTip("Equips the right mask for the field you're farming in (only when autofarm is on). Useful for quests.")
_buttons["honeystorm"] = farmt:CreateToggle("Auto Honeystorm", nil, function(State) kocmoc.toggles.honeystorm = State end)
_buttons["spamglitter"] = farmt:CreateToggle("Keep spaming Glitter!", nil, function(State) kocmoc.toggles.spamglitter = State end):AddToolTip("Spams GLITTER!")


local mobkill = combtab:CreateSection("Combat")
mobkill:CreateToggle("Train Crab", nil, function(State) if State then api.humanoidrootpart().CFrame = CFrame.new(-307.52117919922, 107.91863250732, 467.86791992188) end end)
mobkill:CreateToggle("Train Snail", nil, function(State)
    local fd = workspace.FlowerZones['Stump Field']
    if State then
        api.humanoidrootpart().CFrame = CFrame.new(fd.Position.X, fd.Position.Y-6, fd.Position.Z)
    else
        api.humanoidrootpart().CFrame = CFrame.new(fd.Position.X, fd.Position.Y+2, fd.Position.Z)
    end
end)
_buttons["killmondo"] = mobkill:CreateToggle("Kill Mondo", nil, function(State) kocmoc.toggles.killmondo = State end)
_buttons["touchmondo"] = mobkill:CreateToggle("Touch Mondo (kill for 30s)", nil, function(State) kocmoc.toggles.touchmondo = State end)
_buttons["killvicious"] = mobkill:CreateToggle("Kill Vicious", nil, function(State) kocmoc.toggles.killvicious = State end)
_buttons["killwindy"] = mobkill:CreateToggle("Kill Windy", nil, function(State) kocmoc.toggles.killwindy = State end)
_buttons["autokillmobs"] = mobkill:CreateToggle("Auto Kill Mobs", nil, function(State) kocmoc.toggles.autokillmobs = State end):AddToolTip("Kills mobs after x pollen converting")
_buttons["avoidmobs"] = mobkill:CreateToggle("Avoid Mobs", nil, function(State) kocmoc.toggles.avoidmobs = State end)
_buttons["autoant"] = mobkill:CreateToggle("Auto Ant", nil, function(State) kocmoc.toggles.autoant = State end):AddToolTip("You Need Spark Staff 😋; Goes to Ant Challenge after pollen converting IF you have a quest asking for ants")

local amks = combtab:CreateSection("Auto Kill Mobs Settings")
_buttons["monstertimer"] = amks:CreateTextBox('Kill Mobs After x Convertions', 'default = 3', true , function(Value) kocmoc.vars.monstertimer = tonumber(Value) end)

local wayp = wayptab:CreateSection("Waypoints")
wayp:CreateDropdown("Field Teleports", fieldstable, function(Option) game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = workspace.FlowerZones:FindFirstChild(Option).CFrame end)
wayp:CreateDropdown("Monster Teleports", spawnerstable, function(Option) d = workspace.MonsterSpawners:FindFirstChild(Option) game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(d.Position.X, d.Position.Y+3, d.Position.Z) end)
wayp:CreateDropdown("Toys Teleports", toystable, function(Option) d = workspace.Toys:FindFirstChild(Option).Platform game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(d.Position.X, d.Position.Y+3, d.Position.Z) end)
wayp:CreateButton("Teleport to hive", function() game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = game:GetService("Players").LocalPlayer.SpawnPos.Value end)

local miscc = misctab:CreateSection("Misc")
miscc:CreateButton("Ant Challenge Semi-Godmode", function() api.tween(nil, CFrame.new(93.4228, 32.3983, 553.128)) task.wait(1) game.ReplicatedStorage.Events.ToyEvent:FireServer("Ant Challenge") game.Players.LocalPlayer.Character.HumanoidRootPart.Position = Vector3.new(93.4228, 42.3983, 553.128) task.wait(2) game.Players.LocalPlayer.Character.Humanoid.Name = 1 local l = game.Players.LocalPlayer.Character["1"]:Clone() l.Parent = game.Players.LocalPlayer.Character l.Name = "Humanoid" task.wait() game.Players.LocalPlayer.Character["1"]:Destroy() api.tween(nil, CFrame.new(93.4228, 32.3983, 553.128)) task.wait(8) api.tween(nil, CFrame.new(93.4228, 32.3983, 553.128)) end)
local wstoggle = miscc:CreateToggle("Walk Speed", nil, function(State) kocmoc.toggles.loopspeed = State end) wstoggle:CreateKeybind("K", function(Key) end)
local jptoggle = miscc:CreateToggle("Jump Power", nil, function(State) kocmoc.toggles.loopjump = State end) jptoggle:CreateKeybind("L", function(Key) end)
_buttons["loopspeed"], _buttons["loopjump"] = wstoggle, jptoggle
local misco = misctab:CreateSection("Other")
misco:CreateDropdown("Equip Accesories", accesoriestable, function(Option) local ohString1 = "Equip" local ohTable2 = { ["Mute"] = false, ["Type"] = Option, ["Category"] = "Accessory" } game:GetService("ReplicatedStorage").Events.ItemPackageEvent:InvokeServer(ohString1, ohTable2) end)
misco:CreateDropdown("Equip Masks", masktable, function(Option) local ohString1 = "Equip" local ohTable2 = { ["Mute"] = false, ["Type"] = Option, ["Category"] = "Accessory" } game:GetService("ReplicatedStorage").Events.ItemPackageEvent:InvokeServer(ohString1, ohTable2) end)
-- misco:CreateDropdown("Equip Collectors", collectorstable, function(Option) local ohString1 = "Equip" local ohTable2 = { ["Mute"] = false, ["Type"] = Option, ["Category"] = "Collector" } game:GetService("ReplicatedStorage").Events.ItemPackageEvent:InvokeServer(ohString1, ohTable2) end)
misco:CreateDropdown("Generate Amulet", {"Supreme Star Amulet", "Diamond Star Amulet", "Gold Star Amulet","Silver Star Amulet","Bronze Star Amulet","Moon Amulet"}, function(Option) local A_1 = Option.." Generator" local Event = game:GetService("ReplicatedStorage").Events.ToyEvent Event:FireServer(A_1) end)
misco:CreateButton("Export Stats Table", function() MainThread.resolve(function()proxyfilewrite("Stats_"..api.nickname..".json", game:GetService("HttpService"):JSONEncode(statsget()))end) end)
misco:CreateButton("Do Ant Challenge", function() farmant() end)
misco:CreateButton("Activate 10m buffs", function()
    game:GetService("ReplicatedStorage").Events.PlayerActivesCommand:FireServer({["Name"] = "Red Extract"})
    game:GetService("ReplicatedStorage").Events.PlayerActivesCommand:FireServer({["Name"] = "Blue Extract"})
    game:GetService("ReplicatedStorage").Events.PlayerActivesCommand:FireServer({["Name"] = "Glue"})
    game:GetService("ReplicatedStorage").Events.PlayerActivesCommand:FireServer({["Name"] = "Oil"})
    game:GetService("ReplicatedStorage").Events.PlayerActivesCommand:FireServer({["Name"] = "Enzymes"})
    game:GetService("ReplicatedStorage").Events.PlayerActivesCommand:FireServer({["Name"] = "Tropical Drink"})
end)
misco:CreateButton("Collect & Replant All Planters", function() collectplanters(1); place_new_planters() end)

local extras = extrtab:CreateSection("Extras")
extras:CreateButton("Hide nickname", function() loadstring(game:HttpGet("https://raw.githubusercontent.com/n0t-weuz/Lua/main/nicknamespoofer.lua"))()end)
extras:CreateButton("Boost FPS", function()
    for _, thing in pairs(game:GetDescendants()) do
        local success, result = pcall(function() return thing:IsA("Decal") or thing:IsA("Texture") end)
        if success and result then
            thing.Texture = ""
        end

        local success, result = pcall(function() return thing:IsA("BasePart") end)
        if success and result then
            if thing ~= workspace.Terrain then
                thing.Material = Enum.Material.Plastic
            end
        end
    end
end)
extras:CreateTextBox("Glider Speed", "", true, function(Value) local StatCache = require(game.ReplicatedStorage.ClientStatCache) local stats = StatCache:Get() stats.EquippedParachute = "Glider" local module = require(game:GetService("ReplicatedStorage").Parachutes) local st = module.GetStat local glidersTable = getupvalues(st) glidersTable[1]["Glider"].Speed = Value end)
extras:CreateTextBox("Glider Float", "", true, function(Value) local StatCache = require(game.ReplicatedStorage.ClientStatCache) local stats = StatCache:Get() stats.EquippedParachute = "Glider" local module = require(game:GetService("ReplicatedStorage").Parachutes) local st = module.GetStat local glidersTable = getupvalues(st) glidersTable[1]["Glider"].Float = Value end)
extras:CreateButton("Double Glider Speed", function()
    local StatCache = require(game.ReplicatedStorage.ClientStatCache) local stats = StatCache:Get() stats.EquippedParachute = "Glider" local module = require(game:GetService("ReplicatedStorage").Parachutes) local st = module.GetStat local glidersTable = getupvalues(st) glidersTable[1]["Glider"].Speed *= 2;glidersTable[1]["Glider"].Float *= 2
end)
extras:CreateButton("Invisibility", function(State) api.teleport(CFrame.new(0,0,0)) wait(1) if game.Players.LocalPlayer.Character:FindFirstChild('LowerTorso') then Root = game.Players.LocalPlayer.Character.LowerTorso.Root:Clone() game.Players.LocalPlayer.Character.LowerTorso.Root:Destroy() Root.Parent = game.Players.LocalPlayer.Character.LowerTorso api.teleport(game:GetService("Players").LocalPlayer.SpawnPos.Value) end end)
extras:CreateToggle("Float", nil, function(State) temptable.float = State end)

_buttons["planters"] = {}
local planters = extrtab:CreateSection("Planters")
planters:CreateLabel("Keep nectars up (recommended: 4)")

-- SOLARA FIX
for _, nectar in pairs(allnectars) do
    local tog = planters:CreateToggle(nectar, nil, function(State) kocmoc.planters.farmnectars[nectar] = State end)
    _buttons["planters"][nectar] = tog
    tog:SetState(true)
end

_buttons["planters"]["priority"] = planters:CreateDropdown("Nectar Priority Presets", (function()local a = {}; for i, _ in pairs(nectarprioritypresets) do table.insert(a, i) end; return a end)(), function(presetName)
    kocmoc.planters.priority = presetName
end)
local farmsettings = setttab:CreateSection("Autofarm Settings")
_buttons["convertballoons"] = farmsettings:CreateToggle("Convert Hive Balloon",nil, function(State) kocmoc.toggles.convertballoons = State end)
_buttons["donotfarmtokens"] = farmsettings:CreateToggle("Don't Farm Tokens",nil, function(State) kocmoc.toggles.donotfarmtokens = State end)
_buttons["walkspeed"] = farmsettings:CreateSlider("Walk Speed", 0, 120, 70, false, function(Value) kocmoc.vars.walkspeed = Value end)
_buttons["jumppower"] = farmsettings:CreateSlider("Jump Power", 0, 120, 70, false, function(Value) kocmoc.vars.jumppower = Value end)

local dispsettings = setttab:CreateSection("Auto Dispenser & Auto Boosters Settings")
_buttons["dispense"] = {}
_buttons["dispense"]["rj"] = dispsettings:CreateToggle("Royal Jelly Dispenser", nil, function(State) kocmoc.dispensesettings.rj = not kocmoc.dispensesettings.rj end)
_buttons["dispense"]["blub"] = dispsettings:CreateToggle("Blueberry Dispenser", nil,  function(State) kocmoc.dispensesettings.blub = not kocmoc.dispensesettings.blub end)
_buttons["dispense"]["straw"] = dispsettings:CreateToggle("Strawberry Dispenser", nil,  function(State) kocmoc.dispensesettings.straw = not kocmoc.dispensesettings.straw end)
_buttons["dispense"]["treat"] = dispsettings:CreateToggle("Treat Dispenser", nil,  function(State) kocmoc.dispensesettings.treat = not kocmoc.dispensesettings.treat end)
_buttons["dispense"]["coconut"] = dispsettings:CreateToggle("Coconut Dispenser", nil,  function(State) kocmoc.dispensesettings.coconut = not kocmoc.dispensesettings.coconut end)
_buttons["dispense"]["glue"] = dispsettings:CreateToggle("Glue Dispenser", nil,  function(State) kocmoc.dispensesettings.glue = not kocmoc.dispensesettings.glue end)
_buttons["dispense"]["white"] = dispsettings:CreateToggle("Mountain Top Booster", nil,  function(State) kocmoc.dispensesettings.white = not kocmoc.dispensesettings.white end)
_buttons["dispense"]["blue"] = dispsettings:CreateToggle("Blue Field Booster", nil,  function(State) kocmoc.dispensesettings.blue = not kocmoc.dispensesettings.blue end)
_buttons["dispense"]["red"] = dispsettings:CreateToggle("Red Field Booster", nil,  function(State) kocmoc.dispensesettings.red = not kocmoc.dispensesettings.red end)
local guisettings = setttab:CreateSection("GUI Settings")
local uitoggle = guisettings:CreateToggle("UI Toggle", nil, function(State) Window:Toggle(State) end) uitoggle:CreateKeybind(tostring(Config.Keybind):gsub("Enum.KeyCode.", ""), function(Key) Config.Keybind = Enum.KeyCode[Key] end) uitoggle:SetState(true)
guisettings:CreateColorpicker("UI Color", function(Color) Window:ChangeColor(Color) end)
local themes = guisettings:CreateDropdown("Image", {"Default","Hearts","Abstract","Hexagon","Circles","Lace With Flowers","Floral"}, function(Name) if Name == "Default" then Window:SetBackground("2151741365") elseif Name == "Hearts" then Window:SetBackground("6073763717") elseif Name == "Abstract" then Window:SetBackground("6073743871") elseif Name == "Hexagon" then Window:SetBackground("6073628839") elseif Name == "Circles" then Window:SetBackground("6071579801") elseif Name == "Lace With Flowers" then Window:SetBackground("6071575925") elseif Name == "Floral" then Window:SetBackground("5553946656") end end)themes:SetOption("Default")
local kocmocs = setttab:CreateSection("Configs")
kocmocs:CreateTextBox("Config Name", 'ex: stumpconfig', false, function(Value) temptable.configname = Value end)
local load_config
kocmocs:CreateButton("Load Config", function() load_config(temptable.configname) end)
kocmocs:CreateButton("Save Config", function() writefile("kocmoc/BSS_"..temptable.configname..".json", HttpService:JSONEncode(kocmoc)) end)
kocmocs:CreateButton("Reset Config", function() kocmoc = defaultkocmoc; shared.kocmoc = kocmoc; load_config() end)
local fieldsettings = setttab:CreateSection("Fields Settings")
fieldsettings:CreateDropdown("Best White Field", temptable.whitefields, function(Option) kocmoc.bestfields.white = Option end)
fieldsettings:CreateDropdown("Best Red Field", temptable.redfields, function(Option) kocmoc.bestfields.red = Option end)
fieldsettings:CreateDropdown("Best Blue Field", temptable.bluefields, function(Option) kocmoc.bestfields.blue = Option end)
fieldsettings:CreateDropdown("Field", fieldstable, function(Option) temptable.blackfield = Option end)
fieldsettings:CreateButton("Add Field To Blacklist", function() table.insert(kocmoc.blacklistedfields, temptable.blackfield) game:GetService("CoreGui"):FindFirstChild(shared.windowname).Main:FindFirstChild("Blacklisted Fields D",true):Destroy() fieldsettings:CreateDropdown("Blacklisted Fields", kocmoc.blacklistedfields, function(Option) end) end)
fieldsettings:CreateButton("Remove Field From Blacklist", function() table.remove(kocmoc.blacklistedfields, api.tablefind(kocmoc.blacklistedfields, temptable.blackfield)) game:GetService("CoreGui"):FindFirstChild(shared.windowname).Main:FindFirstChild("Blacklisted Fields D",true):Destroy() fieldsettings:CreateDropdown("Blacklisted Fields", kocmoc.blacklistedfields, function(Option) end) end)
fieldsettings:CreateDropdown("Blacklisted Fields", kocmoc.blacklistedfields, function(Option) end)
local aqs = setttab:CreateSection("Auto Quest Settings")
_buttons["npcprefer"] = {}
for npc, _ in pairs(kocmoc.vars.npcprefer) do
    _buttons["npcprefer"][npc] = aqs:CreateToggle(npc, nil, function(State) kocmoc.vars.npcprefer[npc] = State end)
end
_buttons["tptonpc"] = aqs:CreateToggle("Teleport To NPC", nil, function(State) kocmoc.toggles.tptonpc = State end)

_buttons["boosting"] = {}
local aqs = setttab:CreateSection("Auto-Boosting")
_buttons["boosting"]["lockfield"] = aqs:CreateToggle("Lock Field", nil, function(State) kocmoc.toggles.boosting.lockfield = State end):AddToolTip("Will not perform any other activity while boosting. Only collecting & converting")
_buttons["boosting"]["pivottoboosted"] = aqs:CreateToggle("Pivot To Boosted Field", nil, function(State) kocmoc.toggles.boosting.pivottoboosted = State end):AddToolTip("Will pivot to the field the blue field booster boosted (EXCLUDES STUMP)")
_buttons["boosting"]["glitterrefresh"] = aqs:CreateToggle("Use Glitter to Refresh", nil, function(State) kocmoc.toggles.boosting.glitterrefresh = State end):AddToolTip("Will attempt to use glitter to refresh your boost just before it ends")
_buttons["boosting"]["jellybeans"] = aqs:CreateToggle("Use Jellybeans", nil, function(State) kocmoc.toggles.boosting.jellybeans = State end):AddToolTip("Only uses jellybeans if you have more than 85")
_buttons["boosting"]["increaseballooncap"] = aqs:CreateToggle("Multiply Balloon Cap", nil, function(State) kocmoc.toggles.boosting.increaseballooncap = State end):AddToolTip("Multiplies \"Convert Balloon At\" by the level of your field boost")


local aqs = setttab:CreateSection("Exploit")
_buttons["legit"] = aqs:CreateToggle("Legit Mode", nil, function(State) kocmoc.toggles.legit = State end)
-- THIS OPTION REQUIRES A LVL 8 EXPLOIT (require must return the actual script module.. etc)
_buttons["expsamescriptenv"] = aqs:CreateToggle("Exploit has low level script access?", nil, function(State) kocmoc.toggles.expsamescriptenv = State end)

task.spawn(function() while task.wait() do
    if kocmoc.toggles.autofarm then
        --if kocmoc.toggles.farmcoco then getcoco() end
        --if kocmoc.toggles.collectcrosshairs then getcrosshairs() end
        if kocmoc.toggles.farmfuzzy then walk_to_fuzzies() end
    end
end end)

customChildAdded(workspace.Particles, function(instance)
    local v = instance
    if string.find(instance.Name, "Vicious") then
        print("Vicious bee detected! Field: ", find_field(instance.Position))
        temptable.detected.vicious = true
    end
    if temptable.started.planters or temptable.started.monsters then return end
    if not temptable.started.vicious and not temptable.started.ant then
        if v.Name == "WarningDisk" and not temptable.started.vicious and kocmoc.toggles.autofarm and not temptable.started.ant and kocmoc.toggles.farmcoco and (v.Position-api.humanoidrootpart().Position).magnitude < temptable.magnitude and not temptable.converting then
            table.insert(temptable.coconuts, v)
            getcoco(v)
            gettoken(fieldposition)
        elseif not hasboosttokenquest() and v.Name == "Crosshair" and v ~= nil and v.BrickColor ~= BrickColor.new("Forest green") and not temptable.started.ant and v.BrickColor ~= BrickColor.new("Flint") and (v.Position-api.humanoidrootpart().Position).magnitude < temptable.magnitude and kocmoc.toggles.autofarm and kocmoc.toggles.collectcrosshairs and not temptable.converting then
            if #temptable.crosshairs <= 3 then
                table.insert(temptable.crosshairs, v)
                getcrosshairs(v)
            end
        end
    end
end, function(instance)
    if string.find(instance.Name, "Vicious") then
        temptable.detected.vicious = false
    end
end)

local function getfield()
    local kocmocfield = kocmoc.vars.field
    if kocmoc.toggles.boosting.pivottoboosted then
        local prio = {"Pine Tree Forest", "Bamboo Field", "Blue Flower Field"}
        for i, v in pairs(prio) do
            if get_buff_combo(v.." Boost") then
                kocmocfield = v
                break
            end
        end 
    end

    return kocmocfield
end


local cccinterval = 15*60
local nextmobruntz = tick() + cccinterval
local doBPChecks = function()
    if kocmoc.toggles.boosting.lockfield then
        local f = getfield()
        if f and get_buff_combo(f.." Boost") then return end -- boosting ; don't want to waste time
    end
    if kocmoc.toggles.autoquest then makequests() end
    if kocmoc.toggles.autoplanters then collectplanters() end

    -- send to main thread & ease queue
    local waitingForMain = true
    MainThread.resolve(function()
        for id, fn in pairs(queued) do
            print("Resolving queued task: ", id)
            fn()
            queued[id] = nil
        end
        waitingForMain = false
    end)
    while waitingForMain do task.wait() end

    if tonumber(kocmoc.vars.convertat) < 1 or kocmoc.toggles.autokillmobs then 
        local t = tick()
        if temptable.act >= kocmoc.vars.monstertimer then
            temptable.started.monsters = true
            temptable.act = 0
            killmobs() 
            temptable.started.monsters = false
        elseif t > nextmobruntz then
            nextmobruntz = t + cccinterval
            temptable.started.monsters = true
            temptable.act = 0
            killmobs()
            temptable.started.monsters = false
        end
    end
end
local lastPuff
local interval = 2*60
local counter = tick() - interval
local ccinterval = 2
local cccounter = tick() - ccinterval
task.spawn(function() while task.wait() do
    if kocmoc.toggles.autofarm then
        temptable.magnitude = 70
        if game.Players.LocalPlayer.Character:FindFirstChild("ProgressLabel", true) then
            local pollenprglbl = game.Players.LocalPlayer.Character:FindFirstChild("ProgressLabel",true)
            local maxpollen = tonumber(pollenprglbl.Text:match("%d+$"))
            local pollencount = game.Players.LocalPlayer.CoreStats.Pollen.Value
            
            local pollenpercentage = pollencount/maxpollen*100
            
            Pipes.toAHK({
                Type = "update_backpack",
                Percent = pollenpercentage,
            })

            local kocmocfield = getfield()
            

            if get_buff_combo(kocmocfield.." Boost") then
                if pollenpercentage >= 100 then
                    convert_all()
                    task.wait(3)
                    pollenpercentage = game.Players.LocalPlayer.CoreStats.Pollen.Value/maxpollen*100
                end

                if kocmoc.toggles.boosting.jellybeans then
                    if find_field(game.Players.LocalPlayer.Character.PrimaryPart.Position) == kocmocfield then
                        local stats = statsget()
                        if ((workspace.OsTime.Value - stats.PlayerActiveTimes["Jelly Beans"]) > 2*60) and (stats.Eggs.JellyBeans > 85) then
                            game:GetService("ReplicatedStorage").Events.PlayerActivesCommand:FireServer({["Name"] = "Jelly Beans"})
                        end
                    end
                end
            end

            local s = get_hive_balloon_size()
            local cap = kocmoc.vars.convertatballoon
            if kocmoc.toggles.boosting.increaseballooncap then
                cap *= (2.1)^(get_buff_combo(kocmocfield.." Boost") or 0) -- 1x field boost: 2x cap, 2x field boost: 4x cap, etc
            end
            if s and s > cap then
                pollenpercentage = 100
            end
        
            if tonumber(kocmoc.vars.convertat) < 1 then
                if tonumber(pollenpercentage) >= 99 then
                    if tick() > (cccounter + ccinterval) then
                        cccounter = tick()
                        game:GetService("ReplicatedStorage").Events.PlayerActivesCommand:FireServer({
                            ["Name"] = "Coconut"
                        })
                    end
                end
                if tick() > (counter + interval) then
                    counter = tick()
                    doBPChecks()
                end
            end
            if tick() > (counter + interval) then
                counter = tick()
                doBPChecks()
            end

            local fieldselected = workspace.FlowerZones[kocmocfield]
            local mask = "Diamond Mask"
            local fieldpos = CFrame.new(fieldselected.Position.X, fieldselected.Position.Y+3, fieldselected.Position.Z)
            fieldposition = fieldselected.Position
            if not get_buff_combo(kocmocfield.." Boost") then
                if kocmoc.toggles.autodoquest and game:GetService("Players").LocalPlayer.PlayerGui.ScreenGui.Menus.Children.Quests.Content:FindFirstChild("Frame") then
                    for i, v in pairs(game:GetService("Players").LocalPlayer.PlayerGui.ScreenGui.Menus.Children.Quests:GetDescendants()) do
                        if v.Name == "Description" then
                            local npcconsidered = false
                            for npc, considered in pairs(kocmoc.vars.npcprefer) do
                                if not considered then continue end
                                if string.match(v.Parent.Parent.TitleBarBG.TitleBar.Text, npc) and not string.match(v.Parent.Parent.TitleBarBG.TitleBar.Text, "Snow Machine") then
                                    npcconsidered = true
                                    break
                                end
                            end
                            if not npcconsidered then continue end
                            if not string.find(v.Text, "Puffshroom") then
                                local pollentypes = {'White Pollen', "Red Pollen", "Blue Pollen", "Blue Flowers", "Red Flowers", "White Flowers"}
                                local text = v.Text
                                if api.returnvalue(fieldstable, text) and string.find(text, "Collect") and (string.find(text, "Pollen from") or string.find(text, "Goo from")) and not string.find(text, "Complete!") and not api.findvalue(kocmoc.blacklistedfields, api.returnvalue(fieldstable, text)) then
                                    local d = api.returnvalue(fieldstable, text)
                                    fieldselected = workspace.FlowerZones[d]
                                    if table.find(temptable.redfields, d) then
                                        mask = "Demon Mask"
                                    elseif table.find(temptable.bluefields, d) then
                                        mask = "Diamond Mask"
                                    elseif table.find(temptable.whitefields, d) then
                                        mask = "Gummy Mask"
                                    end
                                    break
                                elseif api.returnvalue(pollentypes, text) and not string.find(text, 'Complete!') then
                                    local d = api.returnvalue(pollentypes, text)

                                    if d == "Blue Flowers" or d == "Blue Pollen" then
                                        fieldselected = workspace.FlowerZones[kocmoc.bestfields.blue]
                                        break
                                    elseif d == "White Flowers" or d == "White Pollen" then
                                        fieldselected = workspace.FlowerZones[kocmoc.bestfields.white]
                                        mask = "Gummy Mask"
                                        break
                                    elseif d == "Red Flowers" or d == "Red Pollen" then
                                        fieldselected = workspace.FlowerZones[kocmoc.bestfields.red]
                                        mask = "Demon Mask"
                                        break
                                    end
                                end
                            end
                        end
                    end
                else
                    fieldselected = workspace.FlowerZones[kocmocfield]
                end
                fieldpos = CFrame.new(fieldselected.Position.X, fieldselected.Position.Y+3, fieldselected.Position.Z)
                fieldposition = fieldselected.Position
                if temptable.sprouts.detected and temptable.sprouts.coords and kocmoc.toggles.farmsprouts then
                    if tonumber(pollenpercentage) >= 99 then
                        convert_all()
                        pollenpercentage = 0
                    end
                    fieldposition = temptable.sprouts.coords.Position
                    fieldpos = temptable.sprouts.coords
                else
                    -- sprout > puffs
                    if kocmoc.toggles.farmpuffshrooms and workspace.Happenings.Puffshrooms:FindFirstChildOfClass("Model") then
                        temptable.magnitude = 40
                        local order = {"Mythic", "Legendary", "Epic", "Rare"}
                        fieldpos, fieldposition = nil, nil
                        for _, o in pairs(order) do
                            if api.partwithnamepart(o, workspace.Happenings.Puffshrooms) then
                                fieldpos = api.partwithnamepart(o, workspace.Happenings.Puffshrooms):FindFirstChild("Puffball Stem").CFrame
                                fieldposition = fieldpos.Position
                                local fpos = find_field(fieldposition)
                                if not fpos or table.find(temptable.blacklistedfields, fpos) then
                                    continue
                                end
                                break
                            end
                        end
                        if not fieldpos then
                            fieldpos = api.getbiggestmodel(workspace.Happenings.Puffshrooms):FindFirstChild("Puffball Stem").CFrame
                            fieldposition = fieldpos.Position
                        end
                        if lastPuff and lastPuff ~= fieldposition then
                            task.wait(1.5)
                            Pipes.toAHK({
                                Type = "increment_stat",
                                Stat = "Total Puffshrooms",
                            })
                            for i=1, 10 do gettoken(lastPuff) end
                        end
                        lastPuff = fieldposition
                    end
                end
            end
            if kocmoc.toggles.automask and statsget()["SessionAccessories"]["Hat"] ~= mask then
                print("Equip: "..mask)
                task.spawn(equip_mask, mask)
                statsget()["SessionAccessories"]["Hat"] = mask
            end

            if kocmoc.toggles.boosting.glitterrefresh then
                if get_buff_combo(kocmocfield.." Boost") then
                    -- attempt to glitter field if timer < 1.5 min
                    if get_buff_active_duration(kocmocfield.." Boost") > (13.5 * 60) and find_field(game.Players.LocalPlayer.Character.PrimaryPart.Position) == kocmocfield then
                        local stats = statsget()
                        if ((workspace.OsTime.Value - stats["PlayerActiveTimes"]["Glitter"]) > 15.5*60) and (stats.Eggs.Glitter > 0) then
                            game:GetService("ReplicatedStorage").Events.PlayerActivesCommand:FireServer({["Name"] = "Glitter"})
                        end
                    end
                end
            end
            if kocmoc.toggles.spamglitter then
                if get_buff_active_duration(kocmocfield.." Boost") > (13.5 * 60) and find_field(game.Players.LocalPlayer.Character.PrimaryPart.Position) == kocmocfield then
                    local stats = statsget()
                    if ((workspace.OsTime.Value - stats["PlayerActiveTimes"]["Glitter"]) > 15.5*60) and (stats.Eggs.Glitter > 0) then
                        game:GetService("ReplicatedStorage").Events.PlayerActivesCommand:FireServer({["Name"] = "Glitter"})
                    end
                end
            end
            if tonumber(kocmoc.vars.convertat) < 1 or tonumber(pollenpercentage) < tonumber(kocmoc.vars.convertat) then
                if not temptable.farm_tokens then
                    routeToField(find_field(fieldposition))
                    if (fieldposition-game.Players.LocalPlayer.Character.HumanoidRootPart.Position).Magnitude > temptable.magnitude then
                        api.tween(nil, fieldpos)
                        task.wait(2)
                    end
                    temptable.farm_tokens = true
                    if kocmoc.toggles.autosprinkler then makesprinklers() end
                else
                    if kocmoc.toggles.touchmondo then
                        -- same version as killmondo, but only kill for 45 seconds, then mark attribute "Done" on mondo
                        if workspace.Monsters:FindFirstChild("Mondo Chick (Lvl 8)") then
                            local mondo = workspace.Monsters["Mondo Chick (Lvl 8)"]
                            if not mondo:GetAttribute("Done") then
                                addToQueue("kill_mondo", function()
                                    if not workspace.Monsters:FindFirstChild("Mondo Chick (Lvl 8)") then return end
                                    if workspace.Monsters["Mondo Chick (Lvl 8)"]:GetAttribute("Done") then return end
                                    routeToField("Mountain Top Field")

                                    temptable.oldmask = statsget()["SessionAccessories"]["Hat"]
                                    equip_mask("Demon Mask")

                                    workspace.Monsters["Mondo Chick (Lvl 8)"]:SetAttribute("Done", true)
                                    temptable.started.mondo = true
                                    local timeout = tick() + 45
                                    while workspace.Monsters:FindFirstChild("Mondo Chick (Lvl 8)") and tick() < timeout do
                                        workspace.Map.Ground.HighBlock.CanCollide = false 
                                        mondopition = workspace.Monsters["Mondo Chick (Lvl 8)"].Head.Position
                                        local cpos = Vector3.new(mondopition.x, mondopition.Y - 52, mondopition.z)
                                        floatpad.CanCollide = true floatpad.Position = cpos - Vector3.new(0, 3.5, 0)
                                        api.tween(nil, CFrame.new(cpos))
                                        task.wait(1)
                                        temptable.float = true
                                    end
                                    floatpad.CanCollide = false
                                    equip_mask(temptable.oldmask)
                                    task.wait(.5) workspace.Map.Ground.HighBlock.CanCollide = true temptable.float = false api.tween(nil, fieldpos) task.wait(1)
                                    temptable.started.mondo = false
                                end)
                            end
                        end
                    elseif kocmoc.toggles.killmondo then
                        if workspace.Monsters:FindFirstChild("Mondo Chick (Lvl 8)") then
                            addToQueue("kill_mondo", function()
                                if not workspace.Monsters:FindFirstChild("Mondo Chick (Lvl 8)") then return end
                                routeToField("Mountain Top Field")
                                temptable.started.mondo = true
                                while workspace.Monsters:FindFirstChild("Mondo Chick (Lvl 8)") do
                                    workspace.Map.Ground.HighBlock.CanCollide = false 
                                    mondopition = workspace.Monsters["Mondo Chick (Lvl 8)"].Head.Position
                                    local cpos = Vector3.new(mondopition.x, mondopition.Y - 52, mondopition.z)
                                    floatpad.CanCollide = true floatpad.Position = cpos - Vector3.new(0, 3.5, 0)
                                    api.tween(nil, CFrame.new(cpos))
                                    task.wait(1)
                                    temptable.float = true
                                end
                                floatpad.CanCollide = false
                                task.wait(.5) workspace.Map.Ground.HighBlock.CanCollide = true temptable.float = false api.tween(nil, CFrame.new(73.2, 176.35, -167)) task.wait(1)
                                for i = 0, 50 do 
                                    gettoken(CFrame.new(73.2, 176.35, -167).Position) 
                                end 
                                api.tween(nil, fieldpos) 
                                temptable.started.mondo = false
                            end)
                        end
                    end
                    if (fieldposition-game.Players.LocalPlayer.Character.HumanoidRootPart.Position).Magnitude > temptable.magnitude then
                        if kocmoc.toggles.legit then
                            routeToField(find_field(fieldposition))
                            if (fieldposition-game.Players.LocalPlayer.Character.HumanoidRootPart.Position).Magnitude > temptable.magnitude then
                                api.tween(nil, fieldpos)
                            end
                            task.wait(.2)
                        else
                            api.tween(nil, fieldpos)
                            task.wait(.2)
                        end
                        if kocmoc.toggles.autosprinkler then makesprinklers() end
                    end
                    if kocmoc.toggles.avoidmobs then avoidmobs() end
                    if kocmoc.toggles.farmclouds then walk_under_clouds() end
                    if kocmoc.toggles.farmunderballoons then walk_under_balloons() end
                    if kocmoc.toggles.farmbubbles then walk_to_bubble() end
                    if not kocmoc.toggles.donotfarmtokens then gettoken(fieldposition) end
                end
            elseif tonumber(pollenpercentage) >= tonumber(kocmoc.vars.convertat) then
                if tonumber(kocmoc.vars.convertat) <= 1 then return end
                temptable.farm_tokens = false
                if kocmoc.toggles.legit then
                    routeToField("hive")
                else
                    api.tween(nil, game:GetService("Players").LocalPlayer.SpawnPos.Value * CFrame.fromEulerAnglesXYZ(0, 110, 0) + Vector3.new(0, 0, 9))
                end
                
                task.wait(2)
                Pipes.toAHK({
                    Type = "set_script_status",
                    Status = 2,
                })
                temptable.converting = true
                repeat
                    task.wait()
                    converthoney()
                until game.Players.LocalPlayer.CoreStats.Pollen.Value == 0
                if kocmoc.toggles.convertballoons and gethiveballoon() then
                    task.wait(6)
                    repeat
                        task.wait()
                        converthoney()
                    until not gethiveballoon() or not kocmoc.toggles.convertballoons
                end
                
                temptable.converting = false
                temptable.act = temptable.act + 1
                task.wait(3)
                doBPChecks()
                local boosting = false
                if kocmoc.toggles.boosting.lockfield then
                    local f = getfield()
                    if f and get_buff_combo(f.." Boost") then boosting = true end -- boosting ; don't want to waste time
                end
                if not boosting and kocmoc.toggles.autoant and not workspace.Toys["Ant Challenge"].Busy.Value and get_latest_player_stats().Eggs.AntPass > 0 then 
                    if kocmoc.toggles.autodoquest and game:GetService("Players").LocalPlayer.PlayerGui.ScreenGui.Menus.Children.Quests.Content:FindFirstChild("Frame") then
                        for i, v in pairs(game:GetService("Players").LocalPlayer.PlayerGui.ScreenGui.Menus.Children.Quests:GetDescendants()) do
                            if v.Name == "Description" then
                                if not v.Parent then continue end
                                local npcconsidered = false
                                for npc, _ in pairs(kocmoc.vars.npcprefer) do
                                    if string.match(v.Parent.Parent.TitleBarBG.TitleBar.Text, npc) then
                                        npcconsidered = true
                                        break
                                    end
                                end
                                if not npcconsidered then continue end
                                if not string.find(v.Text, "Puffshroom") then
                                    if string.find(v.Text, "Ant") and not string.find(v.Text, "Complete!") then
                                        farmant()
                                    end
                                end
                            end
                        end
                    end
                end
                if kocmoc.toggles.legit then
                    routeToField(kocmocfield)
                end
                Pipes.toAHK({
                    Type = "set_script_status",
                    Status = 1,
                })
            end
        end
    end
end end)

task.spawn(function()
    while task.wait(1) do
		if kocmoc.toggles.killvicious and temptable.detected.vicious then
            addToQueue("vicious_kill", function()
                if not temptable.detected.vicious then return end
                temptable.started.vicious = true
                temptable.oldmask = statsget()["SessionAccessories"]["Hat"]

                equip_mask("Demon Mask")
                
                local vichumanoid = game:GetService("Players").LocalPlayer.Character.HumanoidRootPart
                for i, v in pairs(workspace.Particles:GetChildren()) do
                    for x in string.gmatch(v.Name, "Vicious") do
                        if string.find(v.Name, "Vicious") then
                            if kocmoc.toggles.legit and kocmoc.toggles.autofarm then
                                routeToField(find_field(v.Position))
                            end
                            task.spawn(function()
                                task.wait(5)
                                timeout = true
                            end)
                            repeat
                                task.wait()
                                game.Players.LocalPlayer.Character:WaitForChild("Humanoid"):MoveTo(v.Position)
                            until (game.Players.LocalPlayer.Character.PrimaryPart.Position - v.Position).Magnitude < 3 or timeout
                            if (game.Players.LocalPlayer.Character.PrimaryPart.Position - v.Position).Magnitude > 30 then
                                api.tween(nil, CFrame.new(v.Position)) task.wait(1)
                                api.tween(nil, CFrame.new(v.Position)) task.wait(.5)
                            else
                                game.Players.LocalPlayer.Character:WaitForChild("Humanoid"):MoveTo(v.Position)
                                task.wait(3)
                                if (game.Players.LocalPlayer.Character.PrimaryPart.Position - v.Position).Magnitude > 30 then
                                    api.tween(nil, CFrame.new(v.Position)) task.wait(1)
                                    api.tween(nil, CFrame.new(v.Position)) task.wait(.5)
                                end
                            end

                            break
                        end
                    end
                end
                local viciousbee
                for i, v in pairs(workspace.Particles:GetChildren()) do
                    if string.find(v.Name, "Vicious") then
                        viciousbee = v
                        break
                    end
                end
                if false then-- kocmoc.toggles.legit then
                    local raycastParams = RaycastParams.new()
                    raycastParams.FilterType = Enum.RaycastFilterType.Whitelist
                    raycastParams.FilterDescendantsInstances = {workspace.Gates, workspace["Invisible Walls"], workspace.Map, viciousbee}
                    local cycle = 1
                    while kocmoc.toggles.killvicious and temptable.detected.vicious do
                        local offsets = {
                            Vector3.new(1, 0, 0),
                            Vector3.new(1, 0, 1),
                            Vector3.new(-1, 0, 1),
                            Vector3.new(-1, 0, -1),
                        }
                        local compute_destination
                        compute_destination = function()
                            if not viciousbee.Parent then return game.Players.LocalPlayer.Character:WaitForChild("HumanoidRootPart").Position end
                            local ppp = game.Players.LocalPlayer.Character.PrimaryPart.Position
                            local offset = offsets[1 + cycle % 4]
                            local dest = viciousbee.Position + offset * 15
                            local raycast = workspace:Raycast(ppp, CFrame.new(ppp, dest * Vector3.new(1, 0, 1) + ppp * Vector3.new(0, 1, 0)).LookVector * 20, raycastParams)
                            if raycast then
                                dest = raycast.Position -- the position is blocked by a fence or something. Just walk there.
                            end
                            local floor_raycast = workspace:Raycast(dest * Vector3.new(1, 0, 1) + ppp * Vector3.new(0, 1, 0) + Vector3.new(0, 1, 0), Vector3.new(0, -5, 0), raycastParams)
                            -- CHECK IF THERE'S A FLOOR!!
                            if not floor_raycast or not floor_raycast.Position then
                                cycle += 1
                                task.wait()
                                return compute_destination()
                            end
                            return dest * Vector3.new(1, 0, 1) + ppp * Vector3.new(0, 1, 0)
                        end
                        repeat
                            task.wait()
                            if game.Players.LocalPlayer.Character:FindFirstChild("Humanoid") then
                                game.Players.LocalPlayer.Character.Humanoid:MoveTo(compute_destination())
                            end
                        until (game.Players.LocalPlayer.Character.PrimaryPart.Position - compute_destination()).Magnitude < 4 or not (kocmoc.toggles.killvicious and temptable.detected.vicious)
                        cycle += 1
                        task.wait()
                    end
                else
                    while kocmoc.toggles.killvicious and temptable.detected.vicious do
                        for i=1, 4 do
                            temptable.float = true
                            vichumanoid.CFrame = CFrame.new(viciousbee.Position.x, viciousbee.Position.y + 8, viciousbee.Position.z)
                            floatpad.CanCollide = true floatpad.CFrame = CFrame.new(vichumanoid.Position.X, vichumanoid.Position.Y-3.5, vichumanoid.Position.Z)
                            task.wait(.3)
                        end
                    end
                    floatpad.CanCollide = false temptable.float = false
                end
                task.wait(1)
                Pipes.toAHK({
                    Type = "increment_stat",
                    Stat = "Total Vic Kills",
                })
                temptable.started.vicious = false
                equip_mask(temptable.oldmask)
                enableall()
            end, {ignore_legit = true})
		end
	end
end)

task.spawn(function() while task.wait() do
    if kocmoc.toggles.killwindy and temptable.detected.windy and not temptable.converting and not temptable.started.vicious and not temptable.started.mondo and not temptable.started.monsters then
        temptable.started.windy = true
        wlvl = "" aw = false awb = false -- some variable for autowindy, yk?
        disableall()
        while kocmoc.toggles.killwindy and temptable.detected.windy do
            if not aw then
                for i,v in pairs(workspace.Monsters:GetChildren()) do
                    if string.find(v.Name, "Windy") then wlvl = v.Name aw = true -- we found windy!
                    end
                end
            end
            if aw then
                for i,v in pairs(workspace.Monsters:GetChildren()) do
                    if string.find(v.Name, "Windy") then
                        if v.Name ~= wlvl then
                            temptable.float = false task.wait(5) for i =1, 8 do gettoken(api.humanoidrootpart().Position) end -- collect tokens :yessir:
                            wlvl = v.Name
                        end
                    end
                end
            end
            if not awb then api.tween(nil,temptable.gacf(temptable.windy, 5)) task.wait(1) awb = true end
            if awb and temptable.windy.Name == "Windy" then
                api.humanoidrootpart().CFrame = temptable.gacf(temptable.windy, 25)
                floatpad.CanCollide = true floatpad.CFrame = CFrame.new(vichumanoid.Position.X, vichumanoid.Position.Y-3.5, vichumanoid.Position.Z)
                
                temptable.float = true task.wait()
            end
        end 
        enableall()
        temptable.float = false
        temptable.started.windy = false
    end
end end)

task.spawn(function() while task.wait(0.1) do
    if kocmoc.toggles.traincrab then game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(-259, 111.8, 496.4) * CFrame.fromEulerAnglesXYZ(0, 110, 90) temptable.float = true temptable.float = false end
end end)
task.spawn(function()
    while task.wait(.35) do
        if kocmoc.toggles.autodig then
            if game.Players.LocalPlayer then
                game.ReplicatedStorage.Events.ToolCollect:FireServer()
            end
        end
    end
end)

workspace.Sprouts.ChildAdded:Connect(function(child)
    if child.Name == "Sprout" then
        temptable.sprouts.detected = true
        temptable.sprouts.coords = child.CFrame
    end
end)
workspace.Sprouts.ChildRemoved:Connect(function(child)
    if child.Name == "Sprout" then
        task.wait(30)
        temptable.sprouts.detected = false
        temptable.sprouts.coords = ""
    end
end)

workspace.NPCBees.ChildAdded:Connect(function(v)
    if v.Name == "Windy" then
        task.wait(3) temptable.windy = v temptable.detected.windy = true
    end
end)
workspace.NPCBees.ChildRemoved:Connect(function(v)
    if v.Name == "Windy" then
        task.wait(3) temptable.windy = nil temptable.detected.windy = false
    end
end)

game:GetService("RunService").RenderStepped:Connect(function(step)
    temptable.runningfor += step

    -- local gold_balloon = nil
    -- for _, b in pairs(workspace.Balloons.FieldBalloons:GetChildren()) do
    --     if b:FindFirstChild("PlayerName") and b.PlayerName.Value == game.Players.LocalPlayer.Name and b:FindFirstChild("BalloonBody") and b.BalloonBody.Color == Color3.fromRGB(255, 193, 59) then
    --         if (b.BalloonBody.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude <= temptable.magnitude/1.2 then
    --             gold_balloon = b
    --             break
    --         end
    --     end
    -- end
    -- if gold_balloon then
    --     local lc = game.Players.LocalPlayer.Character:GetPrimaryPartCFrame()
    --     local lp = lc.Position
    --     game.Players.LocalPlayer.Character.PrimaryPart.CFrame = CFrame.new(game.Players.LocalPlayer.Character.PrimaryPart.Position) * CFrame.Angles(0, Vector3.new(CFrame.new(game.Players.LocalPlayer.Character.PrimaryPart.Position, gold_balloon.BalloonBody.Position):ToOrientation()).Y ,0)
    -- end
end)

local _counter = 0
game:GetService("RunService").Heartbeat:Connect(function(dt)
_counter += dt
if _counter >= 1 then
    _counter -= 1
    local stats = statsget()
    temptable.honeycurrent = HoneyStat.Value
    if kocmoc.toggles.honeystorm and canToyBeUsed("Honeystorm") then game.ReplicatedStorage.Events.ToyEvent:FireServer("Honeystorm") end
    if kocmoc.toggles.collectgingerbreads and workspace.Toys:FindFirstChild("Gingerbread House") and canToyBeUsed("Gingerbread House") then game:GetService("ReplicatedStorage").Events.ToyEvent:FireServer("Gingerbread House") end
    if kocmoc.toggles.autodispense then
        if kocmoc.dispensesettings.rj and canToyBeUsed("Free Royal Jelly Dispenser") then game:GetService("ReplicatedStorage").Events.ToyEvent:FireServer("Free Royal Jelly Dispenser") end
        if kocmoc.dispensesettings.blub and canToyBeUsed("Blueberry Dispenser") then game:GetService("ReplicatedStorage").Events.ToyEvent:FireServer("Blueberry Dispenser") end
        if kocmoc.dispensesettings.straw and canToyBeUsed("Strawberry Dispenser") then game:GetService("ReplicatedStorage").Events.ToyEvent:FireServer("Strawberry Dispenser") end
        if kocmoc.dispensesettings.treat and canToyBeUsed("Treat Dispenser") then game:GetService("ReplicatedStorage").Events.ToyEvent:FireServer("Treat Dispenser") end
        if kocmoc.dispensesettings.coconut and canToyBeUsed("Coconut Dispenser") then game:GetService("ReplicatedStorage").Events.ToyEvent:FireServer("Coconut Dispenser") end
        if kocmoc.dispensesettings.glue and canToyBeUsed("Glue Dispenser") then game:GetService("ReplicatedStorage").Events.ToyEvent:FireServer("Glue Dispenser") end
    end
    if kocmoc.toggles.autofarm and kocmoc.toggles.autoboosters then 
        if kocmoc.dispensesettings.white and canToyBeUsed("Field Booster") then game.ReplicatedStorage.Events.ToyEvent:FireServer("Field Booster") end
        if kocmoc.dispensesettings.red and canToyBeUsed("Red Field Booster") then game.ReplicatedStorage.Events.ToyEvent:FireServer("Red Field Booster") end
        if kocmoc.dispensesettings.blue and canToyBeUsed("Blue Field Booster") then game.ReplicatedStorage.Events.ToyEvent:FireServer("Blue Field Booster") end
    end
    if kocmoc.toggles.clock and canToyBeUsed("Wealth Clock") then
        if not addToQueue("clock", function() 
            if not canToyBeUsed("Wealth Clock") then return end
            routeToField("Clover Field")
            playRoute("Clover Field", "Toys/Wealth Clock")
            task.wait(1)
            if workspace.Toys:FindFirstChild("Stockings") and canToyBeUsed("Stockings") then
                playRoute("Toys/Wealth Clock", "Toys/Stockings")
                task.wait(1)
                playRoute("Toys/Stockings", "Clover Field")
            else
                playRoute("Toys/Wealth Clock", "Clover Field")
            end
        end) then
            game:GetService("ReplicatedStorage").Events.ToyEvent:FireServer("Wealth Clock")

            if workspace.Toys:FindFirstChild("Stockings") and canToyBeUsed("Stockings") then
                game:GetService("ReplicatedStorage").Events.ToyEvent:FireServer("Stockings")
                task.wait(3)
                local platformm = workspace.Toys["Stockings"].Platform
                for i,v in pairs(workspace.Collectibles:GetChildren()) do
                    if (v.Position-platformm.Position).magnitude < 25 and v.CFrame.YVector.Y == 1 then
                        api.humanoidrootpart().CFrame = v.CFrame
                        task.wait(.5)
                    end
                end
            end
        end
    end
    if kocmoc.toggles.autofeast and workspace.Toys:FindFirstChild("Beesmas Feast") and canToyBeUsed("Beesmas Feast") then
        if not addToQueue("bessmasfeast", function() 
            routeToField("Pumpkin Patch")
            playRoute("Pumpkin Patch", "Toys/Beesmas Feast")
            task.wait(1)
            playRoute("Toys/Beesmas Feast", "Pumpkin Patch")
        end) then
            game:GetService("ReplicatedStorage").Events.ToyEvent:FireServer("Beesmas Feast")
            task.wait(3)
            local platformm = workspace.Toys["Beesmas Feast"].Platform
            for i,v in pairs(workspace.Collectibles:GetChildren()) do
                if (v.Position-platformm.Position).magnitude < 25 and v.CFrame.YVector.Y == 1 then
                    api.humanoidrootpart().CFrame = v.CFrame
                    task.wait(.5)
                end
            end
        end
    end
    if kocmoc.toggles.autosamovar and workspace.Toys:FindFirstChild("Samovar") and canToyBeUsed("Samovar") then
        if not addToQueue("samovar", function() 
            routeToField("Stump Field")
            playRoute("Stump Field", "Toys/Samovar")
            task.wait(1)
            playRoute("Toys/Samovar", "Stump Field")
        end) then
            game:GetService("ReplicatedStorage").Events.ToyEvent:FireServer("Samovar")
            task.wait(3)
            local platformm = workspace.Toys.Samovar.Platform
            for i,v in pairs(workspace.Collectibles:GetChildren()) do
                if (v.Position-platformm.Position).magnitude < 25 and v.CFrame.YVector.Y == 1 then
                    api.humanoidrootpart().CFrame = v.CFrame
                    task.wait(.5)
                end
            end
        end
    end
    if kocmoc.toggles.autocandles and workspace.Toys:FindFirstChild("Honeyday Candles") and canToyBeUsed("Honeyday Candles") then
        if not addToQueue("honeydaycandles", function() 
            routeToField("Rose Field")
            playRoute("Rose Field", "Toys/Honeyday Candles")
            playRoute("Toys/Honeyday Candles", "Rose Field")
        end) then
            game:GetService("ReplicatedStorage").Events.ToyEvent:FireServer("Honeyday Candles")
            task.wait(3)
            local platformm = workspace.Toys["Honeyday Candles"].Platform
            for i,v in pairs(workspace.Collectibles:GetChildren()) do
                if (v.Position-platformm.Position).magnitude < 25 and v.CFrame.YVector.Y == 1 then
                    api.humanoidrootpart().CFrame = v.CFrame
                    task.wait(.5)
                end
            end
        end
    end
    if kocmoc.toggles.autosnowmachine and workspace.Toys:FindFirstChild("Snow Machine") and canToyBeUsed("Snow Machine") then
        game:GetService("ReplicatedStorage").Events.ToyEvent:FireServer("Snow Machine")
    end
    if kocmoc.toggles.autosnowbear and workspace.Toys:FindFirstChild("Snowbear") and canToyBeUsed("Snowbear") then
        addToQueue("snowbear", function() 
            routeToField("Spider Field")
            playRoute("Spider Field", "Toys/Snowbear")
            playRoute("Toys/Snowbear", "Spider Field")
            if find_field(game.Players.LocalPlayer.Character.PrimaryPart.Position) == "Spider Field" then
                attempt_snowbear()
            end
        end)
    end

    if kocmoc.toggles.autoonettart and workspace.Toys:FindFirstChild("Onett's Lid Art") and canToyBeUsed("Onett's Lid Art") then
        if not addToQueue("onettlidart", function() 
            routeToField("Mountain Top Field")
            playRoute("Mountain Top Field", "Toys/Onett's Lid Art")
            playRoute("Toys/Onett's Lid Art", "Mountain Top Field")
        end) then
            game:GetService("ReplicatedStorage").Events.ToyEvent:FireServer("Onett's Lid Art")
            task.wait(5)
            local platformm = workspace.Toys["Onett's Lid Art"].Platform
            for i,v in pairs(workspace.Collectibles:GetChildren()) do
                if (v.Position-platformm.Position).magnitude < 25 and v.CFrame.YVector.Y == 1 then
                    api.humanoidrootpart().CFrame = v.CFrame
                    task.wait(.5)
                end
            end
        end
    end

    if kocmoc.toggles.freeantpass and canToyBeUsed("Free Ant Pass Dispenser") and stats.Eggs.AntPass < 10 then 
        if not addToQueue("antpass", function() 
            routeToField("Dandelion Field")
            playRoute("Dandelion Field", "Toys/Free Ant Pass Dispenser")
            task.wait(1)
            playRoute("Toys/Free Ant Pass Dispenser", "Dandelion Field")
        end) then
            game:GetService("ReplicatedStorage").Events.ToyEvent:FireServer("Free Ant Pass Dispenser")
        end
    end
    if kocmoc.toggles.freerobopass and canToyBeUsed("Free Robo Pass Dispenser") and stats.Eggs.RoboPass < 10 then
        if not addToQueue("robopass", function() 
            routeToField("Mountain Top Field")
            playRoute("Mountain Top Field", "Toys/Free Robo Pass Dispenser")
            task.wait(1)
            playRoute("Toys/Free Robo Pass Dispenser", "Mountain Top Field")
        end) then
            game:GetService("ReplicatedStorage").Events.ToyEvent:FireServer("Free Robo Pass Dispenser")
        end
    end
    local gained = temptable.honeycurrent - temptable.honeystart
    gainedhoneylabel:UpdateText("Gained Honey: "..api.suffixstring(gained))
    avghoney_s:UpdateText("Average Honey / Second: "..api.suffixstring(gained / temptable.runningfor))
    avghoney_m:UpdateText("Average Honey / Minute: "..api.suffixstring(gained / temptable.runningfor * 60))
    avghoney_h:UpdateText("Average Honey / Hour: "..api.suffixstring(gained / temptable.runningfor * 60 * 60))
    avghoney_d:UpdateText("Average Honey / 12h: "..api.suffixstring(gained / temptable.runningfor * 60 * 60 * 12))
    
    local pollen_in_stray_balloons = count_stray_balloons()
    balloonSize:UpdateText("Balloon: "..api.suffixstring(get_hive_balloon_size())..(pollen_in_stray_balloons > 0 and " (+"..api.suffixstring(pollen_in_stray_balloons)..")" or ""))
    timepassedlabel:UpdateText("Time Elapsed: "..api.toHMS(temptable.runningfor))
    
    local acd, bcd, ccd = getTimeUntilToyAvailable("Instant Converter"), getTimeUntilToyAvailable("Instant Converter B"), getTimeUntilToyAvailable("Instant Converter C")
    misccva:UpdateText("Instant Converter A ("..(acd > 0 and api.toHMS(acd) or "Available")..")")
    misccvb:UpdateText("Instant Converter B ("..(bcd > 0 and api.toHMS(bcd) or "Available")..")")
    misccvc:UpdateText("Instant Converter C ("..(ccd > 0 and api.toHMS(ccd) or "Available")..")")
    local nowEggs = stats.Totals.EggsReceived
    local diffEggs = {}
    for item, amt in pairs(nowEggs) do
        local start = start_eggs[item] or 0
        diffEggs[item] = amt - start
    end

    for item, diff in pairs(diffEggs) do
        if diff >= 1 then
            local label = gainedEggToLabel[item]
            if not label then
                label = gainedSection:CreateLabel(item..": 0")
                gainedEggToLabel[item] = label
            end
            label:UpdateText(item..": "..diff)
        end
    end
end
end)

local floatY
game:GetService('RunService').Heartbeat:Connect(function()
    for i, v in pairs(game.Players.LocalPlayer.PlayerGui.ScreenGui:WaitForChild("MinigameLayer"):GetChildren()) do for k, q in pairs(v:WaitForChild("GuiGrid"):GetDescendants()) do if q.Name == "ObjContent" or q.Name == "ObjImage" then q.Visible = true end end end
    
    if game.Players.LocalPlayer.Character:FindFirstChild("Humanoid") then
        -- if temptable.float then
        --     if not floatY then
        --         floatY = game.Players.LocalPlayer.Character.HumanoidRootPart.Position.Y
        --     end
        --     game.Players.LocalPlayer.Character.Humanoid.BodyTypeScale.Value = 0 floatpad.CanCollide = true floatpad.CFrame = CFrame.new(game.Players.LocalPlayer.Character.HumanoidRootPart.Position.X, floatY-3.5, game.Players.LocalPlayer.Character.HumanoidRootPart.Position.Z)
        -- else
        --     floatY = nil
        --     floatpad.CanCollide = false
        -- end
        
        if kocmoc.toggles.loopspeed then game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = kocmoc.vars.walkspeed end
        if kocmoc.toggles.loopjump then game.Players.LocalPlayer.Character.Humanoid.JumpPower = kocmoc.vars.jumppower end
    end
    if kocmoc.toggles.autoquest then 
        local NPC = game:GetService("Players").LocalPlayer.PlayerGui:WaitForChild("ScreenGui"):WaitForChild("NPC")
        if not NPC.Visible then return end
        if kocmoc.toggles.expsamescriptenv then
            firesignal(game:GetService("Players").LocalPlayer.PlayerGui.ScreenGui.NPC.ButtonOverlay.MouseButton1Click)
        else
            local p = NPC.ButtonOverlay
            local x, y = p.AbsolutePosition.X + 50, p.AbsolutePosition.Y + 100
            x, y = math.floor(x), math.floor(y)

            game:GetService("VirtualInputManager"):SendMouseButtonEvent(x, y, 0, true, game, 1)
            game:GetService("VirtualInputManager"):SendMouseButtonEvent(x, y, 0, false, game, 1)
        end
    end
end)

task.spawn(function()while task.wait() do
    if kocmoc.toggles.farmsnowflakes then
        task.wait(3)
        for i,v in pairs(workspace.Collectibles:GetChildren()) do
            if v:FindFirstChildOfClass("Decal") and v:FindFirstChildOfClass("Decal").Texture == "rbxassetid://6087969886" and v.Transparency == 0 then
                api.humanoidrootpart().CFrame = CFrame.new(v.Position.X, v.Position.Y+3, v.Position.Z)
                break
            end
        end
    end
end end)

game.Players.LocalPlayer.CharacterAdded:Connect(function(char)
    humanoid = char:WaitForChild("Humanoid")
    humanoid.Died:Connect(function()
        -- if kocmoc.toggles.autofarm then
        --     temptable.dead = true
        --     kocmoc.toggles.autofarm = false
        --     temptable.converting = false
        --     temptable.farmtoken = false
        -- end
        if temptable.dead then
            task.wait(25)
            temptable.dead = false
            kocmoc.toggles.autofarm = true local player = game.Players.LocalPlayer
            temptable.converting = false
            temptable.farm_tokens = true
        end
    end)
end)

-- do
--     local SayMessageRequest = game:GetService("ReplicatedStorage").DefaultChatSystemChatEvents.SayMessageRequest
--     game.Players.PlayerAdded:Connect(function(player)
--         if #game.Players:GetPlayers() >= 4 then
--             if not shared._chatbotstarted then
--                 shared._chatbotstarted = true
--                 while shared._chatbotstarted and #game.Players:GetPlayers() >= 4 do
--                     task.wait(3)
--                     -- SayMessageRequest:FireServer("[4 OR MORE PLAYERS DETECTED. PLEASE USE THE OTHER AFK SERVER TO AVOID LAGGING THE GAME!]", "All")
--                 end
--                 shared._chatbotstarted = false
--                 SayMessageRequest:FireServer(player.Name.." has left. There are "..#game.Players:GetPlayers().." players in game now.", "All")
--             end
--         end
--     end)
-- end
local vu = game:GetService("VirtualUser")
game:GetService("Players").LocalPlayer.Idled:Connect(function() vu:Button2Down(Vector2.new(0,0),workspace.CurrentCamera.CFrame)task.wait(1)vu:Button2Up(Vector2.new(0,0),workspace.CurrentCamera.CFrame)end)


task.spawn(function() while task.wait() do
    if not game.Players.LocalPlayer.Character.PrimaryPart then continue end
    local pos = game.Players.LocalPlayer.Character.PrimaryPart.Position
    task.wait()
    if (pos-game.Players.LocalPlayer.Character.PrimaryPart.Position).Magnitude > 0 then
        temptable.running = true
    else
        temptable.running = false
    end
end end)

load_config = function(configname) -- also doubles as a function to refresh all the button states
    if configname then
        kocmoc = HttpService:JSONDecode(readfile("kocmoc/BSS_"..configname..".json"))
        shared.kocmoc = kocmoc
    end
    for _, toggle in pairs({"autodig", "autosprinkler", "farmbubbles", "farmflame", "farmcoco", "collectcrosshairs", "farmfuzzy", "farmunderballoons", "farmclouds", "autodispense", "autoboosters", "clock",
        "collectgingerbreads", "autosamovar", "autosnowmachine", "autostockings", "autoplanters", "autocandles", "autosnowbear", "autofeast", "autoonettart", "freeantpass", "freerobopass", "farmsprouts", "farmpuffshrooms", "farmrares", "autoquest", "autodoquest", "automask", "honeystorm",
            "killmondo", "touchmondo", "killvicious", "killwindy", "autokillmobs", "avoidmobs", "autoant", "tptonpc", "convertballoons", "donotfarmtokens", "autofarm", "loopspeed", "loopjump", "legit", "expsamescriptenv", "spamglitter"}) do
            _buttons[toggle]:SetState(kocmoc.toggles[toggle])
    end

    for _, dispense in pairs({"rj", "blub", "straw", "treat", "coconut", "glue", "white", "blue", "red"}) do
        _buttons["dispense"][dispense]:SetState(kocmoc.dispensesettings[dispense])
    end


    -- SOLARA FIX
    for _, nectar in pairs(allnectars) do
        _buttons["planters"][nectar]:SetState(kocmoc.planters.farmnectars[nectar])
    end

    for npc, button in pairs(_buttons["npcprefer"]) do
        button:SetState(kocmoc.vars.npcprefer[npc])
    end

    for _, toggle in pairs({"glitterrefresh", "jellybeans", "increaseballooncap", "lockfield", "pivottoboosted"}) do
        _buttons["boosting"][toggle]:SetState(kocmoc.toggles.boosting[toggle])
    end

    for _, slider in pairs({"convertat", "convertatballoon", "walkspeed", "jumppower"}) do
        _buttons[slider]:SetValue(kocmoc.vars[slider])
    end
end

for _, v in pairs(workspace.Collectibles:GetChildren()) do v:Destroy() end 

do
    local has_claimed_hive
    local hives = workspace.Honeycombs:GetChildren()
    for i = #hives, 1, -1 do
        local v = hives[i]
        if v.Owner.Value == game.Players.LocalPlayer then
            print("already claimed hive")
            has_claimed_hive = true
            break
        end
    end
    if not has_claimed_hive then
        for i = #hives, 1, -1 do
            local v = hives[i]
            if not v.Owner.Value then
                game.ReplicatedStorage.Events.ClaimHive:FireServer(v.HiveID.Value)
                break
            end
        end
    end
end
local function _hidePart(part)
    if part:IsA("BasePart") then part.CanCollide = false part.Transparency = part.Transparency < 0.5 and 0.5 or part.Transparency end
end

-- some errror here: pairs got nil
if workspace.Toys:FindFirstChild("Snowbear") then for _, ball in pairs(workspace.Toys.Snowbear.Snowman:GetDescendants()) do _hidePart(ball) end end
if workspace.Leaderboards:FindFirstChild("SnowbearKills") then for _, part in pairs(workspace.Leaderboards.SnowbearKills:GetDescendants()) do _hidePart(part) end _hidePart(workspace.Leaderboards:FindFirstChild("SnowbearKills")) end
for _, part in pairs(workspace:FindFirstChild("FieldDecos"):GetDescendants()) do _hidePart(part) end
for _, part in pairs(workspace:FindFirstChild("Decorations"):GetDescendants()) do if part:IsA("BasePart") and (part.Parent.Name == "Bush" or part.Parent.Name == "Blue Flower" or part.Parent.Name == "Mushroom") then part.CanCollide = false part.Transparency = part.Transparency < 0.5 and 0.5 or part.Transparency end end
-- before here

do
    ramp = Instance.new("Part")
    ramp.Anchored = true
    ramp.Shape = Enum.PartType.Wedge
    ramp.CFrame = CFrame.new(Vector3.new(290, 103, -20)) * CFrame.Angles(0, -math.rad(90), 0)
    ramp.Size = Vector3.new(25, 8, 25)
    ramp.Parent = workspace
    ramp.Transparency = 1
end

if shared.autoload then if isfile("kocmoc/BSS_"..shared.autoload..".json") then load_config(shared.autoload) end end
