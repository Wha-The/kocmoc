_G.autoload = "afk"

repeat task.wait(0.1) until game:IsLoaded()

-- REMOVE THE FUCKING ADS!!!!!!
-- local ads = {
--     workspace.Decorations.Misc:FindFirstChild("AdFrame"),
--     workspace:FindFirstChild("ForwardPortal"),
-- }
-- for _, ad in pairs(ads) do
--     if ad then
--         ad:Destroy()
--     end
-- end

-- file management
if not isfolder("kocmoc") then makefolder("kocmoc") end
if not isfile("kocmoc/planter_degradation.planters") then
    writefile("kocmoc/planter_degradation.planters", "{}")
end
if not isfolder("kocmoc/cache") then makefolder("kocmoc/cache") end

local HttpService = game:GetService("HttpService")
if not isfolder("kocmoc/routes") then
    makefolder("kocmoc/routes")
    -- download routes
    local routes = game:HttpGet("https://raw.githubusercontent.com/Wha-The/kocmoc/main/routes.json")
    routes = game:GetService("HttpService"):JSONDecode(routes)
    local unpack_directory
    unpack_directory = function(root, d)
        for name, data in pairs(d) do
            if typeof(data) == "table" then
                if not isfolder(root..name) then
                    makefolder(root..name)
                end
                unpack_directory(root, data)
            else
                writefile(root..name, data)
            end
        end
    end
    unpack_directory("kocmoc/", routes)
end

-- API CALLS

local function wrapcache(modulename, moduledownload)
    if not isfile("kocmoc/cache/"..modulename) then
        -- download module
        writefile("kocmoc/cache/"..modulename, game:HttpGet(moduledownload))
    end
    return loadstring(readfile("kocmoc/cache/"..modulename))()
end

local library = wrapcache("bracketv4.lua", "https://raw.githubusercontent.com/Wha-The/kocmoc/main/modules/bracketv4.lua")
local api = wrapcache("api.lua", "https://raw.githubusercontent.com/Boxking776/kocmoc/main/api.lua")
local pathfind, playbackRoute = wrapcache("pathfind.lua", "https://raw.githubusercontent.com/Wha-The/kocmoc/main/modules/pathfind.lua")
local proxyfilewrite, proxyfileappend, proxyfileread, proxyfileexists = wrapcache("proxyfileinterface.lua", "https://raw.githubusercontent.com/Wha-The/kocmoc/main/modules/proxyfileinterface.lua")

-- globals
local playerstatsevent = game:GetService("ReplicatedStorage").Events.RetrievePlayerStats
local statstable = playerstatsevent:InvokeServer()
local function get_latest_player_stats() return playerstatsevent:InvokeServer() end
local function equip_mask(mask) return game:GetService("ReplicatedStorage").Events.ItemPackageEvent:InvokeServer("Equip", { ["Mute"] = false, ["Type"] = mask, ["Category"] = "Accessory"}) end

local function round_decimal(n, place)
    return string.format("%."..place.."f", n)
end

-- Sewage pipes :)
-- Reason we're using a proxy to read/write is because synapse crashes if you call readfile/writefile too much
-- This does require a separate HTTP server running in the background though.
local Pipes = {} do
    
    if not isfolder("kocmoc/pipes") then
        makefolder("kocmoc/pipes")
    end
    if not isfile("kocmoc/pipes/toAHK.pipe") then
        writefile("kocmoc/pipes/toAHK.pipe", "[]")
    end
    writefile("kocmoc/pipes/toRoblox.pipe", "[]")

    function Pipes.fileCheck(f)
        while not proxyfileexists(f) do
            task.wait(1)
        end
    end

    function Pipes.toAHK(data)
        Pipes.fileCheck("kocmoc/pipes/toAHK.pipe")
        if not proxyfileexists("kocmoc/pipes/toAHK.pipe") then return end
        pcall(function()
            if string.sub(proxyfileread("kocmoc/pipes/toAHK.pipe"), 1, 3) == "[][" then
                proxyfilewrite("kocmoc/pipes/toAHK.pipe", string.sub(proxyfileread("kocmoc/pipes/toAHK.pipe"), 3))
            end
        end)
        pcall(function()
            if string.sub(proxyfileread("kocmoc/pipes/toAHK.pipe"), -3) == "][]" then
                proxyfilewrite("kocmoc/pipes/toAHK.pipe", string.sub(proxyfileread("kocmoc/pipes/toAHK.pipe"), 0, -3))
            end
        end)
        local existing
        pcall(function()
            existing = HttpService:JSONDecode(proxyfileread("kocmoc/pipes/toAHK.pipe"))
        end)
        if not existing then return end
        table.insert(existing, data)
        proxyfilewrite("kocmoc/pipes/toAHK.pipe", HttpService:JSONEncode(existing))
    end
    function Pipes.processCommands(callback)
        Pipes.fileCheck("kocmoc/pipes/toRoblox.pipe")
        if not proxyfileexists("kocmoc/pipes/toRoblox.pipe") then return end
        pcall(function()
            if string.sub(proxyfileread("kocmoc/pipes/toRoblox.pipe"), 1, 3) == "[][" then
                proxyfilewrite("kocmoc/pipes/toRoblox.pipe", string.sub(proxyfileread("kocmoc/pipes/toRoblox.pipe"), 3))
            end
        end)
        pcall(function()
            if string.sub(proxyfileread("kocmoc/pipes/toRoblox.pipe"), -3) == "][]" then
                proxyfilewrite("kocmoc/pipes/toRoblox.pipe", string.sub(proxyfileread("kocmoc/pipes/toRoblox.pipe"), 0, -3))
            end
        end)
        local existing
        pcall(function()
            existing = HttpService:JSONDecode(proxyfileread("kocmoc/pipes/toRoblox.pipe"))
        end)
        if not existing then return end
        if #existing > 0 then
            proxyfilewrite("kocmoc/pipes/toRoblox.pipe", "[]")
        end
        
        for _, command in pairs(existing) do
            callback(command)
        end
    end
    function Pipes.toLog(line, color)
        if not proxyfileexists("kocmoc/debug.log") then proxyfilewrite("kocmoc/debug.log", "") end
        line = "["..os.date("%H:%M:%S").."] "..line
        proxyfileappend("kocmoc/debug.log", line.."\n")

        local color = ({
            red = 15085139,
            lightgreen = 8871681,
            green = 9755247,
            yellow = 8871681,
        })[color]
        -- task.spawn(syn.request, {
        --     Url = "",
        --     Method = "POST",
        --     Body = HttpService:JSONEncode({
        --         embeds = {{
        --             description = line,
        --             color = color,
        --         }},
        --     }),
        -- })
    end
end

-- Script tables

local temptable = {
    version = "2.16.0",
    blackfield = "Ant Field",
    redfields = {},
    bluefields = {},
    whitefields = {},
    puffshroomdetected = false,
    magnitude = 70,
    blacklist = {},
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
    honeystart = 0,
    honeycurrent = statstable.Totals.Honey,
    dead = false,
    float = false,
    alpha = false,
    beta = false,
    myhiveis = false,
    invis = false,
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
    allplanters = {},
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
        coordd = CFrame.new(part.Position.X, part.Position.Y+offset, part.Position.Z)
        return coordd
    end
}

for i,v in pairs(temptable.blacklist) do if v == api.nickname then game.Players.LocalPlayer:Kick("You're blacklisted! Get clapped!") end end
if temptable.honeystart == 0 then temptable.honeystart = statstable.Totals.Honey end

for i,v in pairs(workspace.MonsterSpawners:GetDescendants()) do if v.Name == "TimerAttachment" then v.Name = "Attachment" end end
for i,v in pairs(workspace.MonsterSpawners:GetChildren()) do if v.Name == "RoseBush" then v.Name = "ScorpionBush" elseif v.Name == "RoseBush2" then v.Name = "ScorpionBush2" end end
for i,v in pairs(workspace.FlowerZones:GetChildren()) do if v:FindFirstChild("ColorGroup") then if v:FindFirstChild("ColorGroup").Value == "Red" then table.insert(temptable.redfields, v.Name) elseif v:FindFirstChild("ColorGroup").Value == "Blue" then table.insert(temptable.bluefields, v.Name) end else table.insert(temptable.whitefields, v.Name) end end

local masktable = {}
for _, v in pairs(game:GetService("ReplicatedStorage").Accessories:GetChildren()) do if string.match(v.Name, "Mask") then table.insert(masktable, v.Name) end end
local collectorstable = {}
for _, v in pairs(getupvalues(require(game:GetService("ReplicatedStorage").Collectors).Exists)) do for e,r in pairs(v) do table.insert(collectorstable, e) end end
local fieldstable = {}
for _, v in pairs(workspace.FlowerZones:GetChildren()) do table.insert(fieldstable, v.Name) end
local toystable = {}
for _, v in pairs(workspace.Toys:GetChildren()) do table.insert(toystable, v.Name) end
local spawnerstable = {}
for _, v in pairs(workspace.MonsterSpawners:GetChildren()) do table.insert(spawnerstable, v.Name) end
local accesoriestable = {}
for _, v in pairs(game:GetService("ReplicatedStorage").Accessories:GetChildren()) do if v.Name ~= "UpdateMeter" then table.insert(accesoriestable, v.Name) end end
for i, v in pairs(getupvalues(require(game:GetService("ReplicatedStorage").PlanterTypes).GetTypes)) do for e,z in pairs(v) do table.insert(temptable.allplanters, e) end end
table.sort(fieldstable)
table.sort(accesoriestable)
table.sort(toystable)
table.sort(spawnerstable)
table.sort(masktable)
table.sort(temptable.allplanters)
table.sort(collectorstable)

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

local kocmoc = {
    rares = {},
    bestfields = {
        red = "Pepper Patch",
        white = "Coconut Field",
        blue = "Stump Field"
    },
    blacklistedfields = {},
    killerkocmoc = {},
    bltokens = {},
    toggles = {
        autofarm = false,
        farmbubbles = false,
        autodig = false,
        farmrares = false,
        farmfuzzy = false,
        farmcoco = false,
        farmflame = false,
        farmclouds = false,
        killmondo = false,
        killvicious = false,
        loopspeed = false,
        loopjump = false,
        autoquest = false,
        autoboosters = false,
        autodispense = false,
        clock = false,
        freeantpass = false,
        honeystorm = false,
        autodoquest = false,
        disableseperators = false,
        npctoggle = false,
        loopfarmspeed = false,
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
        autoonettart = false,
        autocandles = false,
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
        farmspeed = 60,
        prefer = "Tokens",
        walkspeed = 70,
        jumppower = 70,
        npcprefer = "All Quests",
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
    }
}
local defaultkocmoc = kocmoc

-- functions
local routeToField, find_field

local function statsget() local StatCache = require(game.ReplicatedStorage.ClientStatCache) local stats = StatCache:Get() return stats end

local function getTimeSinceToyActivation(name)
    return workspace.OsTime.Value - require(game.ReplicatedStorage.ClientStatCache):Get("ToyTimes")[name]
end

local function getTimeUntilToyAvailable(n)
    return workspace.Toys[n].Cooldown.Value - getTimeSinceToyActivation(n)
end

local function canToyBeUsed(toy)
    local timeleft = getTimeUntilToyAvailable(toy)
    return timeleft <= 0
end

local function IsToken(token)
    if not token or not token.Parent then
        return false
    end
    if token.Orientation.Z ~= 0 then
        return false
    end
    if not token:FindFirstChild("FrontDecal") then
        return false
    end
    if not token.Name == "C" then
        return false
    end
    if not token:IsA("Part") then
        return false
    end
    return true
end
local function farm(token)
    if token:GetAttribute("_token_collected") then return end
    if kocmoc.toggles.loopfarmspeed then game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = kocmoc.vars.farmspeed end
    api.humanoid():MoveTo(token.Position) 
    repeat task.wait() until (token.Position-api.humanoidrootpart().Position).magnitude <= 3 or not IsToken(token) or not temptable.running
    token:SetAttribute("_token_collected", true)
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



local token_index = {} do
    for _, child in pairs(game:GetService("ReplicatedStorage").Collectibles:GetChildren()) do
        if child:FindFirstChild("Icon") then
            token_index[child.Icon.Texture] = child.Name
        end
    end
    for _, child in pairs(game:GetService("ReplicatedStorage").EggTypes:GetChildren()) do
        if child:IsA("Decal") then
            token_index[child.Texture] = string.gsub(child.Name, "Icon", "")
        end
    end
end

local function identifyToken(token)
    -- returns "Blueberry", "Token Link"
    local icon = token:WaitForChild("FrontDecal").Texture
    return token_index[icon]
end

local function go_after_token(v3, r)
    if not v3 then return end
    if not game.Players.LocalPlayer.Character.PrimaryPart then return end
    if (r.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).Magnitude <= temptable.magnitude/1.4 and (v3-r.Position).Magnitude <= temptable.magnitude then
        farm(r)
    end
end

local token_priority = {

    "Ticket", "Turpentine", "StarTreat", "AtomicTreat", "Diamond", "Gold", "Silver",

    "Neonberry", "SoftWax", "HardWax", "CausticWax", "SwirledWax", "MagicBean",
    "Glue", "Glitter", "BlueExtract", "RedExtract", "Enzymes", "Oil",

    "Token Link",

    "Blueberry", "Strawberry", "Pineapple", "SunflowerSeed", "MoonCharm", "Gumdrop",

    "PollenBomb", "Surprise Party", "Inflate Balloons", "Pollen Haze",

}
local function get_default_priority_tokens()
    local _existingPriorityTokens = {}
    for _, _r in pairs(workspace.Collectibles:GetChildren()) do
        if not IsToken(_r) then continue end
        local name = identifyToken(_r)
        if table.find(token_priority, name) then
            table.insert(_existingPriorityTokens, _r)
        end
    end
    table.sort(_existingPriorityTokens, function(t1, t2)
        return table.find(token_priority, identifyToken(t1)) > table.find(token_priority, identifyToken(t2))
    end)
    return _existingPriorityTokens
end
local fieldposition
local function gettoken(v3)
    if not v3 then
        v3 = fieldposition
    end
    for e,r in pairs(workspace.Collectibles:GetChildren()) do
        for _, _r in pairs(get_default_priority_tokens()) do
            if not IsToken(_r) then continue end
            go_after_token(v3, _r)
        end
        if not IsToken(r) then continue end
        go_after_token(v3, r)
    end
end

local function makesprinklers()
    sprinkler = statsget().EquippedSprinkler
    e = 1
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

local function balloonBlessingTimerLow()
    local BalloonBlessing = statsget().Modifiers["BalloonBlessing"]
    if BalloonBlessing then
        local success, sDB = pcall(function() return BalloonBlessing["_"]["Mods"][1] end)
        if success then
            local durationLeft = sDB.Start + sDB.Dur - workspace.OsTime.Value
            if durationLeft > (15 * 60) then -- 15 mins
                return false
            end
        end
    end
    return true
end

local BuffTile = require(game:GetService("ReplicatedStorage"):WaitForChild("Gui"):WaitForChild("TileDisplay"):WaitForChild("BuffTile"))
local function get_buff_combo(buff)
    return select(2, BuffTile.GetBuffInfo(buff))
end
local function get_buff_active_duration(buff)
    return workspace.OsTime.Value - select(1, BuffTile.GetBuffInfo(buff))
end
local PercentageTilesByTag = getupvalues(require(game:GetService("ReplicatedStorage"):WaitForChild("Gui"):WaitForChild("TileDisplay"):WaitForChild("BuffTile")).RegisterListeners)[1].TilesByTag
local function get_buff_percentage(buff)
    local nectar = PercentageTilesByTag[buff]
    if not nectar then return 0 end
    local percent = (nectar.TimerDur - (workspace.OsTime.Value - nectar.TimerStart)) / nectar.TimerDur
    return percent
end
local function compile_buff_list()
    local buffs = {}

    buffs["babylove"] = get_buff_combo("Baby Love")
    buffs["jbshare"] = get_buff_combo("Jelly Bean Sharing Bonus")
    buffs["festivemark"] = get_buff_combo("Festive Mark")
    buffs["guiding"] = get_buff_combo("Guiding Star Aura+")
    buffs["bear"] = (get_buff_combo("Brown Bear Morph") or 0) + (get_buff_combo("Black Bear Morph") or 0) + (get_buff_combo("Polar Bear Morph") or 0) + (get_buff_combo("Panda Bear Morph") or 0) + 
        (get_buff_combo("Gummy Bear Morph") or 0) + (get_buff_combo("Mother Bear Morph") or 0) + (get_buff_combo("Science Bear Morph") or 0)
    
    buffs["focus"] = get_buff_combo("Focus")
    buffs["bombcombo"] = get_buff_combo("Bomb Combo")
    buffs["balloonaura"] = get_buff_combo("Balloon Aura")
    buffs["balloonaura"] = get_buff_combo("Balloon Aura")
    buffs["clock"] = get_buff_combo("Wealth Clock")
    buffs["precision"] = get_buff_combo("Precision")
    buffs["honeymark"] = get_buff_combo("Honey Mark")
    buffs["pollenmark"] = get_buff_combo("Pollen Mark")

    buffs["haste"] = get_buff_combo("Haste")
    buffs["melody"] = get_buff_combo("Melody")

    buffs["redboost"] = get_buff_combo("Red Boost")
    buffs["blueboost"] = get_buff_combo("Blue Boost")
    buffs["whiteboost"] = get_buff_combo("White Boost")

    buffs["blessing"] = get_buff_combo("Balloon Blessing")
    buffs["inspire"] = get_buff_combo("Inspire")

    for _, nectar in pairs({{"Comforting Nectar", "comforting"}, {"Motivating Nectar", "motivating"}, {"Satisfying Nectar", "satisfying"}, {"Refreshing Nectar", "refreshing"}, {"Invigorating Nectar", "invigorating"}}) do
        buffs[nectar[2]] = math.round(get_buff_percentage(nectar[1]) * 100)
    end
    buffs["tideblessing"] = round_decimal(1 + get_buff_percentage("Tide Blessing") * 0.15, 2)
    buffs["bloat"] = round_decimal(get_buff_percentage("Bubble Bloat") * 6, 2)
    
    Pipes.toAHK({
        Type = "update_buffs",
        Buffs = buffs,
    })
end


local compile_planters
task.spawn(function()
    while task.wait() do
        Pipes.processCommands(function(command)
            if command == "send_honey" then
                Pipes.toAHK({
                    Type = "update_honey",
                    Honey = statsget().Honey
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
    end
end)

local function avoidmobs()
    for i, v in pairs(workspace.Monsters:GetChildren()) do
        if v:FindFirstChild("Head") then
            if (v.Head.Position-game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude < 30 and api.humanoid():GetState() ~= Enum.HumanoidStateType.Freefall then
                game.Players.LocalPlayer.Character.Humanoid.Jump = true
            end
        end
    end
end

local function get_my_monsters()
    local monsters = {}
    for _, monster in pairs(workspace.Monsters:GetChildren()) do
        if monster:FindFirstChild("Target") and monster.Target.Value == game.Players.LocalPlayer then
            table.insert(monsters, monster)
        end
    end
    return monsters
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
        monsterpart, v = d.Part, d.v
        if v:FindFirstChild("TimerLabel", true).Visible then
            table.remove(mob_spawns, index)
            continue
        end

        local mob_count = #get_my_monsters()
        if kocmoc.toggles.legit then
            routeToField(find_field(monsterpart.Position))
            if find_field((game.Players.LocalPlayer.Character.PrimaryPart.Position)) == find_field(monsterpart.Position) then
                game.Players.LocalPlayer.Character.Humanoid:MoveTo(monsterpart.Position)
                task.wait(2)
            end
        end

        -- move on if no new mobs are detected after 3 seconds.
        local timeout = false
        task.spawn(function()
            local ltimeout = false
            task.spawn(function()
                task.wait(3)
                ltimeout = true
            end)
            repeat task.wait() until #get_my_monsters() ~= mob_count or ltimeout
            timeout = ltimeout
        end)
        
        api.humanoidrootpart().CFrame = monsterpart.CFrame
        repeat api.humanoidrootpart().CFrame = monsterpart.CFrame; avoidmobs(); task.wait(1) until v:FindFirstChild("TimerLabel", true).Visible or timeout
        if timeout then
            table.remove(mob_spawns, index)
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
    antpart.CanCollide = true
    temptable.started.ant = true
    anttable = {left = true, right = false}
    local stats = get_latest_player_stats()
    temptable.oldtool = stats['EquippedCollector']
    temptable.oldmask = stats["SessionAccessories"]["Hat"]
    equip_mask("Demon Mask")
    game.ReplicatedStorage.Events.ItemPackageEvent:InvokeServer("Equip",{["Mute"] = true,["Type"] = "Spark Staff",["Category"] = "Collector"})
    game.ReplicatedStorage.Events.ToyEvent:FireServer("Ant Challenge")
    kocmoc.toggles.autodig = true
    acl = CFrame.new(127, 48, 547)
    acr = CFrame.new(65, 48, 534)
    task.wait(1)
    game.ReplicatedStorage.Events.PlayerActivesCommand:FireServer({["Name"] = "Sprinkler Builder"})
    api.humanoidrootpart().CFrame = api.humanoidrootpart().CFrame + Vector3.new(0, 15, 0)
    task.wait(3)
    repeat
        task.wait()
        for i,v in next, workspace.Toys["Ant Challenge"].Obstacles:GetChildren() do
            if v:FindFirstChild("Root") then
                if (v.Root.Position-api.humanoidrootpart().Position).magnitude <= 40 and anttable.left then
                    api.humanoidrootpart().CFrame = acr
                    anttable.left = false anttable.right = true
                    wait(.1)
                elseif (v.Root.Position-api.humanoidrootpart().Position).magnitude <= 40 and anttable.right then
                    api.humanoidrootpart().CFrame = acl
                    anttable.left = true anttable.right = false
                    wait(.1)
                end
            end
        end
    until not workspace.Toys["Ant Challenge"].Busy.Value
    task.wait(1)
    game.ReplicatedStorage.Events.ItemPackageEvent:InvokeServer("Equip",{["Mute"] = true,["Type"] = temptable.oldtool,["Category"] = "Collector"})
    equip_mask(temptable.oldmask)
    temptable.started.ant = false
    antpart.CanCollide = false
end
local PlanterRecommendedFields = {
    ["Comforting Nectar"] = {
        Pots = {"Blue Clay Planter"},
        Fields = {"Pine Tree Forest", "Bamboo Field"},
    },
    ["Refreshing Nectar"] = {
        Pots = {"Pesticide Planter", "Tacky Planter", "Plastic Planter"},
        Fields = {"Strawberry Field", "Blue Flower Field", "Coconut Field"},
    },
    ["Satisfying Nectar"] = {
        Pots = {"Petal Planter", "Tacky Planter", "Plastic Planter"},
        Fields = {"Pumpkin Patch", "Sunflower Field", "Pineapple Patch"},
    },
    ["Motivating Nectar"] = {
        Pots = {"Candy Planter", "Red Clay Planter", "Pesticide Planter", "Plastic Planter"},
        Fields = {"Stump Field", "Rose Field", "Spider Field", "Mushroom Field"},
    },
    -- ["Invigorating Nectar"] = {
    --     Pots = {"Red Clay Planter", "Pesticide Planter", "Plastic Planter"},
    --     Fields = {"Pepper Patch", "Spider Field", "Mountain Top Field", "Cactus Field", "Clover Field"},
    -- }
}
local NectarPriority = {"Comforting Nectar", "Motivating Nectar", "Satisfying Nectar", "Refreshing Nectar"--[[, "Invigorating Nectar"]]}
local GetPlanterData = require(game.ReplicatedStorage.PlanterTypes).Get

function find_field(position, options)
    options = options or {}
    local matches = {}
    for _, p in pairs(workspace.FlowerZones:GetChildren()) do
        if options.exceptions and table.find(options.exceptions, p.Name) then continue end
        table.insert(matches, {(position - p.Position).Magnitude, p.Name})
    end
    if options.hive and (not options.exceptions or not table.find(options.exceptions, "hive")) then
        -- consider the hive too
        table.insert(matches, {(position - game.Players.LocalPlayer.SpawnPos.Value.Position).Magnitude, "hive"})
    end
    table.sort(matches, function(a, b) return a[1] < b[1] end)
    return matches[1][2]
end

local function playRoute(start, dest)
    if start == dest then
        return
        -- return playRoute(find_field(workspace.FlowerZones[start].Position, {hive=true, exceptions={start, dest}}), start)
    end
    local fname = "kocmoc/routes/"..start.."/"..dest..".route"
    if not proxyfileexists(fname) then
        if start == "hive" or dest == "hive" then
            return warn("Can't find path! "..fname)
        end
        playRoute(start, "hive")
        playRoute("hive", dest)
        return
    end
    local data = HttpService:JSONDecode(proxyfileread(fname))
    return playbackRoute(data)
end

function routeToField(field)
    local currentField = find_field(game.Players.LocalPlayer.Character.PrimaryPart.Position, {hive=true})
    playRoute(currentField, field)
end

function compile_planters()
    local planters = {}
    local nectar -- find the nectar which the field where the planter on is for

    for i,v in pairs(debug.getupvalues(require(game:GetService("ReplicatedStorage").LocalPlanters).LoadPlanter)[4]) do 
        if v.IsMine then
            local field = find_field(v.PotModel.Soil.Position)
            local nectar_type do
                for _nectar, data in pairs(PlanterRecommendedFields) do
                    if table.find(data.Fields, field) then
                        nectar_type = _nectar
                        break
                    end
                end
            end
            if not nectar_type then continue end
            table.insert(planters, {
                PlanterName = string.gsub(v.PotModel.Name, " ", ""),
                FieldName = string.gsub(string.gsub(string.gsub(find_field(v.PotModel.Soil.Position), " Patch", ""), " Forest", ""), " Field", ""),
                NectarType = string.gsub(nectar_type, " Nectar", ""),
                EstimatedPlantedDuration = math.round(v.GrowthPercent * GetPlanterData(v.Type).MaxGrowth),
            })
        end
    end

    Pipes.toAHK({
        Type = "update_planters",
        Planters = planters,
    })
end



local function place_new_planters()
    local total = 0
    for i,v in pairs(debug.getupvalues(require(game:GetService("ReplicatedStorage").LocalPlanters).LoadPlanter)[4]) do 
        if v.IsMine then
            total += 1
        end
    end
    if total >= 3 then return end -- already full, can't plant more

    -- populate "occupied_fields" and "planters_in_use"
    local occupied_fields = {}
    local planters_in_use = {}
    local nectars_already_working_on = {}
    for i,v in pairs(debug.getupvalues(require(game:GetService("ReplicatedStorage").LocalPlanters).LoadPlanter)[4]) do 
        if v.IsMine then
            table.insert(occupied_fields, find_field(v.PotModel.Soil.Position))
            table.insert(planters_in_use, v.PotModel.Name)

            local field = find_field(v.PotModel.Soil.Position)
            local nectar
            for _nectar, data in pairs(PlanterRecommendedFields) do
                if table.find(data.Fields, field) then
                    nectar = _nectar
                    break
                end
            end
            table.insert(nectars_already_working_on, nectar)
        end
    end
    -- compute the Nectar the player needs
    local nectars_needed = {}
    for index, nectar in pairs(NectarPriority) do
        local percent = get_buff_percentage(nectar)
        local recommended_hover_above = index <= 3 and 0.8 or 0.6
        if table.find(nectars_already_working_on, nectar) and percent > (recommended_hover_above/2) then continue end
        if percent < recommended_hover_above then
            table.insert(nectars_needed, nectar)
        end
    end
    -- if no nectar is <80%, populate "nectars_needed" with all nectars arranged from lowest to highest 
    if #nectars_needed <= 0 then
        local nectars = {}
        for _, nectar in pairs(NectarPriority) do
            table.insert(nectars, {get_buff_percentage(nectar), nectar})
        end
        table.sort(nectars, function(a, b) return a[1] < b[1] end)
        for _, data in pairs(nectars) do
            table.insert(nectars_needed, data[2])
        end
    end

    -- Load Planter Degration File
    local LastCollectTimes = HttpService:JSONDecode(proxyfileread("kocmoc/planter_degradation.planters"))

    -- go plant
    local planted = 0
    for _, nectar in pairs(nectars_needed) do
        if total >= 3 then break end
        local pot do
            for _, _p in pairs(PlanterRecommendedFields[nectar].Pots) do
                pot = _p
                if not table.find(planters_in_use, _p) then
                    break
                end
            end
            if not pot then
                pot = "Paper Planter"
            else
                table.insert(planters_in_use, pot)
            end
        end

        local field do
            local available_fields = {}
            for _, _f in pairs(PlanterRecommendedFields[nectar].Fields) do
                if not table.find(occupied_fields, _f) then
                    table.insert(available_fields, _f)
                end
            end
            
            local _computeDegradation = function(field)
                local degradation = LastCollectTimes[field] and ((LastCollectTimes[field][1] + LastCollectTimes[field][2])) or 0
                local existing_degradation = 0
                if LastCollectTimes[field] then
                    existing_degradation = (LastCollectTimes[field][1] + LastCollectTimes[field][2]) - workspace.OsTime.Value
                    if existing_degradation < 0 then
                        existing_degradation = 0
                    end
                end
                return existing_degradation
            end
            local zero_degradation = {}
            local has_degradation = {}
            for _, _f in pairs(available_fields) do
                if _f == kocmoc.vars.field then
                    table.insert(zero_degradation, 1, _f)
                    continue
                end
                if _computeDegradation(_f) == 0 then
                    table.insert(zero_degradation, _f)
                else
                    table.insert(has_degradation, _f)
                end
            end
            table.sort(has_degradation, function(field_a, field_b)
                return _computeDegradation(field_a) < _computeDegradation(field_b)
            end)
            available_fields = zero_degradation
            for _, field in pairs(has_degradation) do
                table.insert(available_fields, field)
            end
            if #available_fields <= 0 then
                field = "Mountain Top Field" -- Mountain Top Field isn't good for anything, fall back in case everything fails (which should never happen, but, just in case)
            else
                field = available_fields[1]
                table.insert(occupied_fields, field)
            end
        end
        -- go to field and plant
        if kocmoc.toggles.legit then
            routeToField(field)
        end
        if find_field(game.Players.LocalPlayer.Character.PrimaryPart.Position) ~= field then 
            api.tween(2, CFrame.new(workspace.FlowerZones[field].Position) + Vector3.new(0, 3, 0))
        end
        task.wait(1)
        game:GetService("ReplicatedStorage").Events.PlayerActivesCommand:FireServer({["Name"] = pot})
        task.wait(1)
        total += 1
        planted += 1
    end
    return planted
end

local function collectplanters(force_harvest)
    temptable.started.planters = true
    for i, v in pairs(debug.getupvalues(require(game:GetService("ReplicatedStorage").LocalPlanters).LoadPlanter)[4]) do
        if v.IsMine then
            local field = find_field(v.PotModel.Soil.Position)
            local should_harvest = v.GrowthPercent == 1 -- compute if the player should harvest planter
            if not should_harvest then
                local nectar -- find the nectar which the field where the planter on is for
                for _nectar, data in pairs(PlanterRecommendedFields) do
                    if table.find(data.Fields, field) then
                        nectar = _nectar
                        break
                    end
                end
                if nectar then
                    -- predict how much nectar harvasting the planter now would give us
                    local recommended_hover_above = table.find(NectarPriority, nectar) <= 3 and 0.8 or 0.5
                    local nectar_given = v.GrowthPercent * GetPlanterData(v.Type).MaxGrowth * 1.25 -- *1.25 because it's the average and a good assumption.
                    if (get_buff_percentage(nectar) * (24 * 60 * 60) + nectar_given) > ((24 * 60 * 60) * (recommended_hover_above + 0.15)) then
                        should_harvest = true
                    end
                end
            end
            if not force_harvest and not should_harvest then continue end

            api.humanoidrootpart().CFrame = v.PotModel.Soil.CFrame
            local Soil = v.PotModel.Soil
            task.wait(1)
            game:GetService("ReplicatedStorage").Events.PlanterModelCollect:FireServer(v.ActorID)
            
            local LastCollectTimes = HttpService:JSONDecode(proxyfileread("kocmoc/planter_degradation.planters"))
            local existing_degradation = 0
            if LastCollectTimes[field] then
                existing_degradation = (LastCollectTimes[field][1] + LastCollectTimes[field][2]) - workspace.OsTime.Value
                if existing_degradation < 0 then
                    existing_degradation = 0
                end
            end
            LastCollectTimes[field] = {workspace.OsTime.Value, existing_degradation + math.round(v.GrowthPercent * GetPlanterData(v.Type).MaxGrowth) + (60 * 60)}
            proxyfilewrite("kocmoc/planter_degradation.planters", HttpService:JSONEncode(LastCollectTimes))
            Pipes.toAHK({
                Type = "increment_stat",
                Stat = "Total Planters",
            })
            task.wait(3)
            for i = 1, 8 do gettoken(Soil.Position) end
            task.wait(3)
        end
    end
    place_new_planters()
    temptable.started.planters = false
end


local function gethiveballoon()
    task.wait()
    local result = false
    for i, hive in pairs(workspace.Honeycombs:GetChildren()) do
        task.wait()
        if hive:FindFirstChild("Owner") and hive:FindFirstChild("SpawnPos") then
            if hive.Owner.Value == game.Players.LocalPlayer then
                for e, balloon in pairs(workspace.Balloons.HiveBalloons:GetChildren()) do
                    if balloon:FindFirstChild("BalloonRoot") then
                        if (balloon.BalloonRoot.Position-hive.SpawnPos.Value.Position).magnitude < 15 then
                            result = balloon
                            break
                        end
                    end
                end
            end
        end
    end
    return result
end


local function converthoney()
    if temptable.converting then
        if game.Players.LocalPlayer.PlayerGui.ScreenGui.ActivateButton.TextBox.Text ~= "Stop Making Honey" and game.Players.LocalPlayer.PlayerGui.ScreenGui.ActivateButton.BackgroundColor3 ~= Color3.new(201, 39, 28) or (game:GetService("Players").LocalPlayer.SpawnPos.Value.Position-game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude > 10 then
            api.tween(1, game:GetService("Players").LocalPlayer.SpawnPos.Value * CFrame.fromEulerAnglesXYZ(0, 110, 0) + Vector3.new(0, 0, 9))
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
            repeat task.wait() until (game.Players.LocalPlayer.Character.PrimaryPart.Position * Vector3.new(1,0,1)- v.Position * Vector3.new(1,0,1)).Magnitude < 11 or not v.Parent
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
                if string.match(v.Parent.Parent.TitleBar.Text, kocmoc.vars.npcprefer) or kocmoc.vars.npcprefer == "All Quests" and not string.find(v.Text, "Puffshroom") then
                    if string.find(v.Text, "Red Boost") and not string.find(v.Text, "Complete!") then
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
                if string.match(v.Parent.Parent.TitleBar.Text, kocmoc.vars.npcprefer) or kocmoc.vars.npcprefer == "All Quests" and not string.find(v.Text, "Puffshroom") then
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
                if string.match(v.Parent.Parent.TitleBar.Text, kocmoc.vars.npcprefer) or kocmoc.vars.npcprefer == "All Quests" and not string.find(v.Text, "Puffshroom") then
                    if (string.find(v.Text, "Strawberry Tokens") or string.find(v.Text, "Blueberry Tokens")) and not string.find(v.Text, "Complete!") then
                        return true
                    end
                end
            end
        end
    end
end

task.spawn(function()
    while task.wait(60) do
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
        if v.Name ~= "Ant Challenge Info" and v.Name ~= "Bubble Bee Man 2" and v.Name ~= "Wind Shrine" and v.Name ~= "Gummy Bear" and v.Name ~= "Honey Bee" then if v:FindFirstChild("Platform") then if v.Platform:FindFirstChild("AlertPos") then if v.Platform.AlertPos:FindFirstChild("AlertGui") then if v.Platform.AlertPos.AlertGui:FindFirstChild("ImageLabel") then
            image = v.Platform.AlertPos.AlertGui.ImageLabel
            button = game:GetService("Players").LocalPlayer.PlayerGui.ScreenGui.ActivateButton.MouseButton1Click
            if image.ImageTransparency == 0 then
                if kocmoc.toggles.tptonpc then
                    game.Players.LocalPlayer.Character.Humanoid:Move(Vector3.zero)
                    game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(v.Platform.Position.X, v.Platform.Position.Y+3, v.Platform.Position.Z)
                    task.wait(1)
                    game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(v.Platform.Position.X, v.Platform.Position.Y+3, v.Platform.Position.Z)
                else
                    api.tween(2,CFrame.new(v.Platform.Position.X, v.Platform.Position.Y+3, v.Platform.Position.Z))
                    task.wait(3)
                end
                for b, z in pairs(getconnections(button)) do    z.Function()    end
                Pipes.toAHK({
                    Type = "increment_stat",
                    Stat = "Quests Done",
                })
                task.wait(8)
                if image.ImageTransparency == 0 then
                    for b, z in pairs(getconnections(button)) do    z.Function()    end
                end
                task.wait(2)
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
        return
    end
    local availability = {stats.ToyTimes["Instant Converter"] + 15 * 60 - workspace.OsTime.Value, stats.ToyTimes["Instant Converter B"] + 15 * 60 - workspace.OsTime.Value, stats.ToyTimes["Instant Converter C"] + 15 * 60 - workspace.OsTime.Value}
    for i = 1, 3 do
        if availability[i] <= 0 then
            game:GetService("ReplicatedStorage").Events.ToyEvent:FireServer("Instant Converter"..(({"", " B", " C"})[i]))
            return
        end
    end
    if stats.Eggs["Micro-Converter"] > 0 then
        game:GetService("ReplicatedStorage").Events.PlayerActivesCommand:FireServer({
            ["Name"] = "Micro-Converter"
        })
        return
    end
end

local Config = { WindowName = "🌘  kocmoc | "..temptable.version, Color = Color3.fromRGB(164, 84, 255), Keybind = Enum.KeyCode.Semicolon}
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
information:CreateLabel("Thanks you for using our script, "..api.nickname)
information:CreateLabel("Script version: "..temptable.version)
information:CreateLabel("Place version: "..game.PlaceVersion)
information:CreateLabel("⚠️ - Not Safe Function")
information:CreateLabel("⚙ - Configurable Function")
information:CreateLabel("Place version: "..game.PlaceVersion)
information:CreateLabel("Script by weuz_ and mrdevl")
information:CreateLabel("Script improved by WhutThe")

local gainedSection = hometab:CreateSection("Gained")
gainedSection:CreateButton("Reset Timer/Gained Honey", function()
    temptable.runningfor = 0
    temptable.honeystart = statsget().Totals.Honey
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
convertatslider_balloon = farmo:CreateSlider("Convert Balloon At", 10000000000, 250000000000, 15000000000, false, function(Value) kocmoc.vars.convertatballoon = Value end)
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
_buttons["autostockings"] = farmt:CreateToggle("Auto Stockings", nil, function(State) kocmoc.toggles.autostockings = State end)
_buttons["autoplanters"] = farmt:CreateToggle("Auto Planters", nil, function(State) kocmoc.toggles.autoplanters = State end):AddToolTip("Will re-plant your planters after converting, if they hit 100%")
_buttons["autocandles"] = farmt:CreateToggle("Auto Honey Candles", nil, function(State) kocmoc.toggles.autocandles = State end)
_buttons["autofeast"] = farmt:CreateToggle("Auto Beesmas Feast", nil, function(State) kocmoc.toggles.autofeast = State end)
_buttons["autoonettart"] = farmt:CreateToggle("Auto Onett's Lid Art", nil, function(State) kocmoc.toggles.autoonettart = State end)
_buttons["freeantpass"] = farmt:CreateToggle("Auto Free Antpasses", nil, function(State) kocmoc.toggles.freeantpass = State end)
_buttons["farmsprouts"] = farmt:CreateToggle("Farm Sprouts", nil, function(State) kocmoc.toggles.farmsprouts = State end)
_buttons["farmpuffshrooms"] = farmt:CreateToggle("Farm Puffshrooms", nil, function(State) kocmoc.toggles.farmpuffshrooms = State end)
_buttons["farmsnowflakes"] = farmt:CreateToggle("Farm Snowflakes ⚠️", nil, function(State) kocmoc.toggles.farmsnowflakes = State end)
_buttons["farmrares"] = farmt:CreateToggle("Teleport To Rares ⚠️", nil, function(State) kocmoc.toggles.farmrares = State end)
_buttons["autoquest"] = farmt:CreateToggle("Auto Accept/Confirm Quests ⚙", nil, function(State) kocmoc.toggles.autoquest = State end)
_buttons["autodoquest"] = farmt:CreateToggle("Auto Do Quests ⚙", nil, function(State) kocmoc.toggles.autodoquest = State end)
_buttons["honeystorm"] = farmt:CreateToggle("Auto Honeystorm", nil, function(State) kocmoc.toggles.honeystorm = State end)


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
miscc:CreateButton("Ant Challenge Semi-Godmode", function() api.tween(1, CFrame.new(93.4228, 32.3983, 553.128)) task.wait(1) game.ReplicatedStorage.Events.ToyEvent:FireServer("Ant Challenge") game.Players.LocalPlayer.Character.HumanoidRootPart.Position = Vector3.new(93.4228, 42.3983, 553.128) task.wait(2) game.Players.LocalPlayer.Character.Humanoid.Name = 1 local l = game.Players.LocalPlayer.Character["1"]:Clone() l.Parent = game.Players.LocalPlayer.Character l.Name = "Humanoid" task.wait() game.Players.LocalPlayer.Character["1"]:Destroy() api.tween(1, CFrame.new(93.4228, 32.3983, 553.128)) task.wait(8) api.tween(1, CFrame.new(93.4228, 32.3983, 553.128)) end)
local wstoggle = miscc:CreateToggle("Walk Speed", nil, function(State) kocmoc.toggles.loopspeed = State end) wstoggle:CreateKeybind("K", function(Key) end)
local jptoggle = miscc:CreateToggle("Jump Power", nil, function(State) kocmoc.toggles.loopjump = State end) jptoggle:CreateKeybind("L", function(Key) end)
_buttons["loopspeed"], _buttons["loopjump"] = wstoggle, jptoggle
local misco = misctab:CreateSection("Other")
misco:CreateDropdown("Equip Accesories", accesoriestable, function(Option) local ohString1 = "Equip" local ohTable2 = { ["Mute"] = false, ["Type"] = Option, ["Category"] = "Accessory" } game:GetService("ReplicatedStorage").Events.ItemPackageEvent:InvokeServer(ohString1, ohTable2) end)
misco:CreateDropdown("Equip Masks", masktable, function(Option) local ohString1 = "Equip" local ohTable2 = { ["Mute"] = false, ["Type"] = Option, ["Category"] = "Accessory" } game:GetService("ReplicatedStorage").Events.ItemPackageEvent:InvokeServer(ohString1, ohTable2) end)
misco:CreateDropdown("Equip Collectors", collectorstable, function(Option) local ohString1 = "Equip" local ohTable2 = { ["Mute"] = false, ["Type"] = Option, ["Category"] = "Collector" } game:GetService("ReplicatedStorage").Events.ItemPackageEvent:InvokeServer(ohString1, ohTable2) end)
misco:CreateDropdown("Generate Amulet", {"Supreme Star Amulet", "Diamond Star Amulet", "Gold Star Amulet","Silver Star Amulet","Bronze Star Amulet","Moon Amulet"}, function(Option) local A_1 = Option.." Generator" local Event = game:GetService("ReplicatedStorage").Events.ToyEvent Event:FireServer(A_1) end)
misco:CreateButton("Export Stats Table", function() local StatCache = require(game.ReplicatedStorage.ClientStatCache)writefile("Stats_"..api.nickname..".json", StatCache:Encode()) end)
misco:CreateButton("Do Ant Challenge", function() farmant() end)
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
extras:CreateTextBox("Glider Speed", "", true, function(Value) local StatCache = require(game.ReplicatedStorage.ClientStatCache) local stats = StatCache:Get() stats.EquippedParachute = "Glider" local module = require(game:GetService("ReplicatedStorage").Parachutes) local st = module.GetStat local glidersTable = getupvalues(st) glidersTable[1]["Glider"].Speed = Value setupvalue(st, st[1]'Glider', glidersTable) end)
extras:CreateTextBox("Glider Float", "", true, function(Value) local StatCache = require(game.ReplicatedStorage.ClientStatCache) local stats = StatCache:Get() stats.EquippedParachute = "Glider" local module = require(game:GetService("ReplicatedStorage").Parachutes) local st = module.GetStat local glidersTable = getupvalues(st) glidersTable[1]["Glider"].Float = Value setupvalue(st, st[1]'Glider', glidersTable) end)
extras:CreateButton("Invisibility", function(State) api.teleport(CFrame.new(0,0,0)) wait(1) if game.Players.LocalPlayer.Character:FindFirstChild('LowerTorso') then Root = game.Players.LocalPlayer.Character.LowerTorso.Root:Clone() game.Players.LocalPlayer.Character.LowerTorso.Root:Destroy() Root.Parent = game.Players.LocalPlayer.Character.LowerTorso api.teleport(game:GetService("Players").LocalPlayer.SpawnPos.Value) end end)
extras:CreateToggle("Float", nil, function(State) temptable.float = State end)


local farmsettings = setttab:CreateSection("Autofarm Settings")
_buttons["farmspeed"] = farmsettings:CreateTextBox("Autofarming Walkspeed", "Default Value = 60", true, function(Value) kocmoc.vars.farmspeed = Value end)
_buttons["loopfarmspeed"] = farmsettings:CreateToggle("^ Loop Speed On Autofarming",nil, function(State) kocmoc.toggles.loopfarmspeed = State end)
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
kocmocs:CreateButton("Reset Config", function() kocmoc = defaultkocmoc; load_config() end)
local fieldsettings = setttab:CreateSection("Fields Settings")
fieldsettings:CreateDropdown("Best White Field", temptable.whitefields, function(Option) kocmoc.bestfields.white = Option end)
fieldsettings:CreateDropdown("Best Red Field", temptable.redfields, function(Option) kocmoc.bestfields.red = Option end)
fieldsettings:CreateDropdown("Best Blue Field", temptable.bluefields, function(Option) kocmoc.bestfields.blue = Option end)
fieldsettings:CreateDropdown("Field", fieldstable, function(Option) temptable.blackfield = Option end)
fieldsettings:CreateButton("Add Field To Blacklist", function() table.insert(kocmoc.blacklistedfields, temptable.blackfield) game:GetService("CoreGui"):FindFirstChild(_G.windowname).Main:FindFirstChild("Blacklisted Fields D",true):Destroy() fieldsettings:CreateDropdown("Blacklisted Fields", kocmoc.blacklistedfields, function(Option) end) end)
fieldsettings:CreateButton("Remove Field From Blacklist", function() table.remove(kocmoc.blacklistedfields, api.tablefind(kocmoc.blacklistedfields, temptable.blackfield)) game:GetService("CoreGui"):FindFirstChild(_G.windowname).Main:FindFirstChild("Blacklisted Fields D",true):Destroy() fieldsettings:CreateDropdown("Blacklisted Fields", kocmoc.blacklistedfields, function(Option) end) end)
fieldsettings:CreateDropdown("Blacklisted Fields", kocmoc.blacklistedfields, function(Option) end)
local aqs = setttab:CreateSection("Auto Quest Settings")
aqs:CreateDropdown("Do NPC Quests", {'All Quests', 'Bucko Bee', 'Brown Bear', 'Riley Bee', 'Polar Bear'}, function(Option) kocmoc.vars.npcprefer = Option end)
_buttons["tptonpc"] = aqs:CreateToggle("Teleport To NPC", nil, function(State) kocmoc.toggles.tptonpc = State end)

local aqs = setttab:CreateSection("Legit Mode")
_buttons["legit"] = aqs:CreateToggle("Legit Mode", nil, function(State) kocmoc.toggles.legit = State end)
-- script

task.spawn(function() while task.wait() do
    if kocmoc.toggles.autofarm then
        --if kocmoc.toggles.farmcoco then getcoco() end
        --if kocmoc.toggles.collectcrosshairs then getcrosshairs() end
        if kocmoc.toggles.farmfuzzy then walk_to_fuzzies() end
    end
end end)

workspace.Particles.ChildAdded:Connect(function(v)
    if temptable.started.planters or temptable.started.monsters then return end
    if not temptable.started.vicious and not temptable.started.ant then
        if v.Name == "WarningDisk" and not temptable.started.vicious and kocmoc.toggles.autofarm and not temptable.started.ant and kocmoc.toggles.farmcoco and (v.Position-api.humanoidrootpart().Position).magnitude < temptable.magnitude and not temptable.converting then
            table.insert(temptable.coconuts, v)
            getcoco(v)
            gettoken()
        elseif not hasboosttokenquest() and v.Name == "Crosshair" and v ~= nil and v.BrickColor ~= BrickColor.new("Forest green") and not temptable.started.ant and v.BrickColor ~= BrickColor.new("Flint") and (v.Position-api.humanoidrootpart().Position).magnitude < temptable.magnitude and kocmoc.toggles.autofarm and kocmoc.toggles.collectcrosshairs and not temptable.converting then
            if #temptable.crosshairs <= 3 then
                table.insert(temptable.crosshairs, v)
                getcrosshairs(v)
                gettoken()
            end
        end
    end
end)


local cccinterval = 5*60
local ccccounter = tick() - cccinterval
local doBPChecks = function()
    if kocmoc.vars.field and get_buff_combo(kocmoc.vars.field.." Boost") then return end -- boosting ; don't want to waste time
    if kocmoc.toggles.autoquest then makequests() end
    if kocmoc.toggles.autoplanters then collectplanters() end
    if tonumber(kocmoc.vars.convertat) < 1 or kocmoc.toggles.autokillmobs then 
        if temptable.act >= kocmoc.vars.monstertimer then
            temptable.started.monsters = true
            temptable.act = 0
            killmobs() 
            temptable.started.monsters = false
        elseif ccccounter > cccinterval then
            ccccounter -= cccinterval * math.floor(ccccounter / cccinterval)
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
            if get_buff_combo(kocmoc.vars.field.." Boost") then
                if pollenpercentage >= 100 then
                    convert_all()
                    task.wait(6)
                    pollenpercentage = game.Players.LocalPlayer.CoreStats.Pollen.Value/maxpollen*100
                end

                if find_field(game.Players.LocalPlayer.Character.PrimaryPart.Position) == kocmoc.vars.field then
                    local stats = statsget()
                    if ((workspace.OsTime.Value - stats.PlayerActiveTimes["Jelly Beans"]) > 2*60) and (stats.Eggs.JellyBeans > 85) then
                        game:GetService("ReplicatedStorage").Events.PlayerActivesCommand:FireServer({["Name"] = "Jelly Beans"})
                    end
                end
            end
            local s, b = pcall(function()return gethiveballoon().BalloonBody.GuiAttach.Gui.Bar.TextLabel.Text end)
            if s then
                s, b = pcall(function() local a = string.gsub(b, ",", ""); return tonumber(a) end)
                if s and typeof(b) == "number" and b > (kocmoc.vars.convertatballoon * (1 + (get_buff_combo(kocmoc.vars.field.." Boost") or 0))) then
                    pollenpercentage = 100
                end
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

            local fieldselected = workspace.FlowerZones[kocmoc.vars.field]
            local mask = "Diamond Mask"
            local fieldpos = CFrame.new(fieldselected.Position.X, fieldselected.Position.Y+3, fieldselected.Position.Z)
            fieldposition = fieldselected.Position
            if not get_buff_combo(kocmoc.vars.field.." Boost") then
                if kocmoc.toggles.autodoquest and game:GetService("Players").LocalPlayer.PlayerGui.ScreenGui.Menus.Children.Quests.Content:FindFirstChild("Frame") then
                    for i, v in pairs(game:GetService("Players").LocalPlayer.PlayerGui.ScreenGui.Menus.Children.Quests:GetDescendants()) do
                        if v.Name == "Description" then
                            if not string.match(v.Parent.Parent.TitleBar.Text, "Brown Bear") and (string.match(v.Parent.Parent.TitleBar.Text, kocmoc.vars.npcprefer) or kocmoc.vars.npcprefer == "All Quests" and not string.find(v.Text, "Puffshroom")) then
                                pollentypes = {'White Pollen', "Red Pollen", "Blue Pollen", "Blue Flowers", "Red Flowers", "White Flowers"}
                                text = v.Text
                                if api.returnvalue(fieldstable, text) and not string.find(v.Text, "Complete!") and not api.findvalue(kocmoc.blacklistedfields, api.returnvalue(fieldstable, text)) then
                                    d = api.returnvalue(fieldstable, text)
                                    fieldselected = workspace.FlowerZones[d]
                                    if table.find(temptable.redfields, d) then
                                        mask = "Demon Mask"
                                    elseif table.find(temptable.bluefields, d) then
                                        mask = "Diamond Mask"
                                    elseif table.find(temptable.whitefields, d) then
                                        mask = "Gummy Mask"
                                    end
                                    break
                                elseif api.returnvalue(pollentypes, text) and not string.find(v.Text, 'Complete!') then
                                    d = api.returnvalue(pollentypes, text)

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
                    fieldselected = workspace.FlowerZones[kocmoc.vars.field]
                end
                fieldpos = CFrame.new(fieldselected.Position.X, fieldselected.Position.Y+3, fieldselected.Position.Z)
                fieldposition = fieldselected.Position
                if temptable.sprouts.detected and temptable.sprouts.coords and kocmoc.toggles.farmsprouts then
                    if tonumber(pollenpercentage) >= 99 then
                        convert_all()
                    end
                    fieldposition = temptable.sprouts.coords.Position
                    fieldpos = temptable.sprouts.coords
                end
                if kocmoc.toggles.farmpuffshrooms and workspace.Happenings.Puffshrooms:FindFirstChildOfClass("Model") then
                    temptable.magnitude = 40
                    if api.partwithnamepart("Mythic", workspace.Happenings.Puffshrooms) then
                        fieldpos = api.partwithnamepart("Mythic", workspace.Happenings.Puffshrooms):FindFirstChild("Puffball Stem").CFrame
                        fieldposition = fieldpos.Position
                    elseif api.partwithnamepart("Legendary", workspace.Happenings.Puffshrooms) then
                        fieldpos = api.partwithnamepart("Legendary", workspace.Happenings.Puffshrooms):FindFirstChild("Puffball Stem").CFrame
                        fieldposition = fieldpos.Position
                    elseif api.partwithnamepart("Epic", workspace.Happenings.Puffshrooms) then
                        fieldpos = api.partwithnamepart("Epic", workspace.Happenings.Puffshrooms):FindFirstChild("Puffball Stem").CFrame
                        fieldposition = fieldpos.Position
                    elseif api.partwithnamepart("Rare", workspace.Happenings.Puffshrooms) then
                        fieldpos = api.partwithnamepart("Rare", workspace.Happenings.Puffshrooms):FindFirstChild("Puffball Stem").CFrame
                        fieldposition = fieldpos.Position
                    else
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
            if statsget()["SessionAccessories"]["Hat"] ~= mask then
                print("Equip mask "..mask)
                task.spawn(equip_mask, mask)
                statsget()["SessionAccessories"]["Hat"] = mask
            end

            if get_buff_combo(kocmoc.vars.field.." Boost") then
                -- attempt to glitter field if timer < 1 min
                if get_buff_active_duration(kocmoc.vars.field.." Boost") > (13.5 * 60) and find_field(game.Players.LocalPlayer.Character.PrimaryPart.Position) == kocmoc.vars.field then
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
                        api.tween(2, fieldpos)
                        task.wait(2)
                    end
                    temptable.farm_tokens = true
                    if kocmoc.toggles.autosprinkler then makesprinklers() end
                else
                    if kocmoc.toggles.killmondo then
                        while kocmoc.toggles.killmondo and workspace.Monsters:FindFirstChild("Mondo Chick (Lvl 8)") and not temptable.started.vicious and not temptable.started.monsters do
                            temptable.started.mondo = true
                            while workspace.Monsters:FindFirstChild("Mondo Chick (Lvl 8)") do
                                disableall()
                                workspace.Map.Ground.HighBlock.CanCollide = false 
                                mondopition = workspace.Monsters["Mondo Chick (Lvl 8)"].Head.Position
                                api.tween(1, CFrame.new(mondopition.x, mondopition.Y - 52, mondopition.z))
                                task.wait(1)
                                temptable.float = true
                            end
                            task.wait(.5) workspace.Map.Ground.HighBlock.CanCollide = true temptable.float = false api.tween(2.5, CFrame.new(73.2, 176.35, -167)) task.wait(1)
                            for i = 0, 50 do 
                                gettoken(CFrame.new(73.2, 176.35, -167).Position) 
                            end 
                            enableall() 
                            api.tween(2, fieldpos) 
                            temptable.started.mondo = false
                        end
                    end
                    if (fieldposition-game.Players.LocalPlayer.Character.HumanoidRootPart.Position).Magnitude > temptable.magnitude then
                        if kocmoc.toggles.legit then
                            routeToField(find_field(fieldposition))
                            if (fieldposition-game.Players.LocalPlayer.Character.HumanoidRootPart.Position).Magnitude > temptable.magnitude then
                                api.tween(2, fieldpos)
                            end
                            task.wait(.2)
                        else
                            api.tween(2, fieldpos)
                            task.wait(.2)
                        end
                        if kocmoc.toggles.autosprinkler then makesprinklers() end
                    end
                    if kocmoc.toggles.avoidmobs then avoidmobs() end
                    if kocmoc.toggles.farmclouds then walk_under_clouds() end
                    if kocmoc.toggles.farmunderballoons then walk_under_balloons() end
                    if kocmoc.toggles.farmbubbles then walk_to_bubble() end
                    if not kocmoc.toggles.donotfarmtokens then gettoken() end
                end
            elseif tonumber(pollenpercentage) >= tonumber(kocmoc.vars.convertat) then
                if tonumber(kocmoc.vars.convertat) <= 1 then return end
                temptable.farm_tokens = false
                if kocmoc.toggles.legit then
                    routeToField("hive")
                else
                    api.tween(2, game:GetService("Players").LocalPlayer.SpawnPos.Value * CFrame.fromEulerAnglesXYZ(0, 110, 0) + Vector3.new(0, 0, 9))
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
                if kocmoc.toggles.autoant and not workspace.Toys["Ant Challenge"].Busy.Value and get_latest_player_stats().Eggs.AntPass > 0 then 
                    if kocmoc.toggles.autodoquest and game:GetService("Players").LocalPlayer.PlayerGui.ScreenGui.Menus.Children.Quests.Content:FindFirstChild("Frame") then
                        for i, v in pairs(game:GetService("Players").LocalPlayer.PlayerGui.ScreenGui.Menus.Children.Quests:GetDescendants()) do
                            if v.Name == "Description" then
                                if string.match(v.Parent.Parent.TitleBar.Text, kocmoc.vars.npcprefer) or kocmoc.vars.npcprefer == "All Quests" and not string.find(v.Text, "Puffshroom") then
                                    if string.find(v.Text, "Ant") and not string.find(v.Text, "Complete!") then
                                        farmant()
                                    end
                                end
                            end
                        end
                    end
                end
                if kocmoc.toggles.legit then
                    routeToField(kocmoc.vars.field)
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
		if kocmoc.toggles.killvicious and temptable.detected.vicious and not temptable.converting and not temptable.started.monsters then
            temptable.started.vicious = true
            local autoFarmStatus = kocmoc.toggles.autofarm
            disableall()
            
			local vichumanoid = game:GetService("Players").LocalPlayer.Character.HumanoidRootPart
			for i, v in pairs(workspace.Particles:GetChildren()) do
				for x in string.gmatch(v.Name, "Vicious") do
					if string.find(v.Name, "Vicious") then
                        if kocmoc.toggles.legit and autoFarmStatus then
                            routeToField(find_field(v.Position))
                        end
                        if (game.Players.LocalPlayer.Character.PrimaryPart.Position - v.Position).Magnitude > 30 then
                            api.tween(1, CFrame.new(v.Position)) task.wait(1)
                            api.tween(0.5, CFrame.new(v.Position)) task.wait(.5)
                        else
                            game.Players.LocalPlayer.Character.Humanoid:MoveTo(v.Position)
                            task.wait(3)
                            if (game.Players.LocalPlayer.Character.PrimaryPart.Position - v.Position).Magnitude > 30 then
                                api.tween(1, CFrame.new(v.Position)) task.wait(1)
                                api.tween(0.5, CFrame.new(v.Position)) task.wait(.5)
                            end
                        end

                        break
					end
				end
			end
			for i, v in pairs(workspace.Particles:GetChildren()) do
				for x in string.gmatch(v.Name, "Vicious") do
                    while kocmoc.toggles.killvicious and temptable.detected.vicious do
                        task.wait()
                        if string.find(v.Name, "Vicious") then
                            for i=1, 4 do
                                temptable.float = true
                                vichumanoid.CFrame = CFrame.new(v.Position.x, v.Position.y + 3, v.Position.z)
                                task.wait(.3)
                            end
                        end
                    end
                end
			end
			task.wait(1)
			Pipes.toAHK({
                Type = "increment_stat",
                Stat = "Total Vic Kills",
            })
			temptable.float = false
            temptable.started.vicious = false
            if kocmoc.toggles.legit and autoFarmStatus then
                routeToField(kocmoc.vars.field)
            end
            enableall()
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
                            temptable.float = false task.wait(5) for i =1, 5 do gettoken(api.humanoidrootpart().Position) end -- collect tokens :yessir:
                            wlvl = v.Name
                        end
                    end
                end
            end
            if not awb then api.tween(1,temptable.gacf(temptable.windy, 5)) task.wait(1) awb = true end
            if awb and temptable.windy.Name == "Windy" then
                api.humanoidrootpart().CFrame = temptable.gacf(temptable.windy, 25) temptable.float = true task.wait()
            end
        end 
        enableall()
        temptable.float = false
        temptable.started.windy = false
    end
end end)

task.spawn(function() while task.wait(0.1) do
    if kocmoc.toggles.traincrab then game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(-259, 111.8, 496.4) * CFrame.fromEulerAnglesXYZ(0, 110, 90) temptable.float = true temptable.float = false end
    if kocmoc.toggles.autodig then if game.Players.LocalPlayer then if game.Players.LocalPlayer.Character then if game.Players.LocalPlayer.Character:FindFirstChildOfClass("Tool") then if game.Players.LocalPlayer.Character:FindFirstChildOfClass("Tool"):FindFirstChild("ClickEvent", true) then clickevent = game.Players.LocalPlayer.Character:FindFirstChildOfClass("Tool"):FindFirstChild("ClickEvent", true) or nil end end end if clickevent then clickevent:FireServer() end end end
end end)

workspace.Particles.Folder2.ChildAdded:Connect(function(child)
    if child.Name == "Sprout" then
        temptable.sprouts.detected = true
        temptable.sprouts.coords = child.CFrame
    end
end)
workspace.Particles.Folder2.ChildRemoved:Connect(function(child)
    if child.Name == "Sprout" then
        task.wait(30)
        temptable.sprouts.detected = false
        temptable.sprouts.coords = ""
    end
end)

workspace.Particles.ChildAdded:Connect(function(instance)
    if string.find(instance.Name, "Vicious") then
        temptable.detected.vicious = true
    end
end)
workspace.Particles.ChildRemoved:Connect(function(instance)
    if string.find(instance.Name, "Vicious") then
        temptable.detected.vicious = false
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

task.spawn(function() while task.wait(2) do
    if not temptable.converting then
        if kocmoc.toggles.autosamovar and workspace.Toys:FindFirstChild("Samovar") and canToyBeUsed("Samovar") then
            game:GetService("ReplicatedStorage").Events.ToyEvent:FireServer("Samovar")
            platformm = workspace.Toys.Samovar.Platform
            for i,v in pairs(workspace.Collectibles:GetChildren()) do
                if (v.Position-platformm.Position).magnitude < 25 and v.CFrame.YVector.Y == 1 then
                    api.humanoidrootpart().CFrame = v.CFrame
                    task.wait(.5)
                end
            end
        end
        if kocmoc.toggles.autostockings and workspace.Toys:FindFirstChild("Stockings") and canToyBeUsed("Stockings") then
            game:GetService("ReplicatedStorage").Events.ToyEvent:FireServer("Stockings")
            platformm = workspace.Toys.Stockings.Platform
            for i,v in pairs(workspace.Collectibles:GetChildren()) do
                if (v.Position-platformm.Position).magnitude < 25 and v.CFrame.YVector.Y == 1 then
                    api.humanoidrootpart().CFrame = v.CFrame
                    task.wait(.5)
                end
            end
        end
        if kocmoc.toggles.autoonettart and workspace.Toys:FindFirstChild("Onett's Lid Art") and canToyBeUsed("Onett's Lid Art") then
            game:GetService("ReplicatedStorage").Events.ToyEvent:FireServer("Onett's Lid Art")
            platformm = workspace.Toys["Onett's Lid Art"].Platform
            for i,v in pairs(workspace.Collectibles:GetChildren()) do
                if (v.Position-platformm.Position).magnitude < 25 and v.CFrame.YVector.Y == 1 then
                    api.humanoidrootpart().CFrame = v.CFrame
                    task.wait(.5)
                end
            end
        end
        if kocmoc.toggles.autocandles and workspace.Toys:FindFirstChild("Honeyday Candles") and canToyBeUsed("Honeyday Candles") then
            game:GetService("ReplicatedStorage").Events.ToyEvent:FireServer("Honeyday Candles")
            platformm = workspace.Toys["Honeyday Candles"].Platform
            for i,v in pairs(workspace.Collectibles:GetChildren()) do
                if (v.Position-platformm.Position).magnitude < 25 and v.CFrame.YVector.Y == 1 then
                    api.humanoidrootpart().CFrame = v.CFrame
                    task.wait(.5)
                end
            end
        end
        if kocmoc.toggles.autofeast and workspace.Toys:FindFirstChild("Beesmas Feast") and canToyBeUsed("Beesmas Feast") then
            game:GetService("ReplicatedStorage").Events.ToyEvent:FireServer("Beesmas Feast")
            platformm = workspace.Toys["Beesmas Feast"].Platform
            for i,v in pairs(workspace.Collectibles:GetChildren()) do
                if (v.Position-platformm.Position).magnitude < 25 and v.CFrame.YVector.Y == 1 then
                    api.humanoidrootpart().CFrame = v.CFrame
                    task.wait(.5)
                end
            end
        end
    end
end end)

game:GetService("RunService").RenderStepped:Connect(function(step)
    temptable.runningfor += step
    ccccounter += step

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

local suffix_to_value = {
    k = 1000,
    M = 1000000,
    B = 1000000000,
    T = 1000000000000,
}
local function count_stray_balloons()
    -- total up pollen in all stray balloons
    local total = 0
    for _, balloon in pairs(workspace.Balloons.FieldBalloons:GetChildren()) do
        if balloon:FindFirstChild("PlayerName") and balloon.PlayerName.Value == game.Players.LocalPlayer.Name and balloon:FindFirstChild("BalloonBody") and balloon.BalloonBody:FindFirstChild("GuiAttach")
            and balloon.BalloonBody.GuiAttach:FindFirstChild("Gui") and balloon.BalloonBody.GuiAttach.Gui:FindFirstChild("Bar") and balloon.BalloonBody.GuiAttach.Gui.Bar:FindFirstChild("TextLabel") then
                local text = balloon.BalloonBody.GuiAttach.Gui.Bar.TextLabel.Text
                local number = string.gsub(string.gsub(string.split(text, "/")[1], "🌺", ""), " ", "")
                local value = string.sub(number, 1, string.len(number)-1)
                local suffix = string.sub(number, string.len(number))
                if not suffix_to_value[suffix] then
                    -- it's not a suffix
                    total += tonumber(number)
                    continue
                end

                total += tonumber(value) * suffix_to_value[suffix]
        end
    end
    return total
end

task.spawn(function() while task.wait(1) do
    local stats = statsget()
    temptable.honeycurrent = stats.Totals.Honey
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
    if kocmoc.toggles.autofarm and canToyBeUsed("Blue Field Booster") then
        game.ReplicatedStorage.Events.ToyEvent:FireServer("Blue Field Booster")
    end
    if kocmoc.toggles.autoboosters and hasBoosterQuest() then 
        if kocmoc.dispensesettings.white then game.ReplicatedStorage.Events.ToyEvent:FireServer("Field Booster") end
        if kocmoc.dispensesettings.red then game.ReplicatedStorage.Events.ToyEvent:FireServer("Red Field Booster") end
        if kocmoc.dispensesettings.blue then game.ReplicatedStorage.Events.ToyEvent:FireServer("Blue Field Booster") end
    end
    if kocmoc.toggles.clock and canToyBeUsed("Wealth Clock") then game:GetService("ReplicatedStorage").Events.ToyEvent:FireServer("Wealth Clock") end
    if kocmoc.toggles.freeantpass and canToyBeUsed("Free Ant Pass Dispenser") and stats.Eggs.AntPass < 10 then game:GetService("ReplicatedStorage").Events.ToyEvent:FireServer("Free Ant Pass Dispenser") end
    local gained = temptable.honeycurrent - temptable.honeystart
    gainedhoneylabel:UpdateText("Gained Honey: "..api.suffixstring(gained))
    avghoney_s:UpdateText("Average Honey / Second: "..api.suffixstring(gained / temptable.runningfor))
    avghoney_m:UpdateText("Average Honey / Minute: "..api.suffixstring(gained / temptable.runningfor * 60))
    avghoney_h:UpdateText("Average Honey / Hour: "..api.suffixstring(gained / temptable.runningfor * 60 * 60))
    avghoney_d:UpdateText("Average Honey / 12h: "..api.suffixstring(gained / temptable.runningfor * 60 * 60 * 12))
    local x = 0
    local s, b = pcall(function()return gethiveballoon().BalloonBody.GuiAttach.Gui.Bar.TextLabel.Text end)
    if s then
        s, x = pcall(function() local a = string.gsub(b, ",", ""); return tonumber(a) end)
    end
    local pollen_in_stray_balloons = count_stray_balloons()
    balloonSize:UpdateText("Balloon: "..api.suffixstring(x)..(pollen_in_stray_balloons > 0 and " (+"..api.suffixstring(pollen_in_stray_balloons)..")" or ""))
    timepassedlabel:UpdateText("Time Elapsed: "..api.toHMS(temptable.runningfor))
    
    local acd, bcd, ccd = stats.ToyTimes["Instant Converter"] + 15 * 60 - workspace.OsTime.Value, stats.ToyTimes["Instant Converter B"] + 15 * 60 - workspace.OsTime.Value, stats.ToyTimes["Instant Converter C"] + 15 * 60 - workspace.OsTime.Value
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
end end)

game:GetService('RunService').Heartbeat:Connect(function() 
    
    if kocmoc.toggles.autoquest then firesignal(game:GetService("Players").LocalPlayer.PlayerGui.ScreenGui.NPC.ButtonOverlay.MouseButton1Click) end
    if game.Players.LocalPlayer.Character:FindFirstChild("Humanoid") then
        if kocmoc.toggles.loopspeed then game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = kocmoc.vars.walkspeed end
        if kocmoc.toggles.loopjump then game.Players.LocalPlayer.Character.Humanoid.JumpPower = kocmoc.vars.jumppower end
    end
end)

game:GetService('RunService').Heartbeat:Connect(function()
    for i, v in pairs(game.Players.LocalPlayer.PlayerGui.ScreenGui:WaitForChild("MinigameLayer"):GetChildren()) do for k, q in pairs(v:WaitForChild("GuiGrid"):GetDescendants()) do if q.Name == "ObjContent" or q.Name == "ObjImage" then q.Visible = true end end end
end)

game:GetService('RunService').Heartbeat:Connect(function() 
    if temptable.float then game.Players.LocalPlayer.Character.Humanoid.BodyTypeScale.Value = 0 floatpad.CanCollide = true floatpad.CFrame = CFrame.new(game.Players.LocalPlayer.Character.HumanoidRootPart.Position.X, game.Players.LocalPlayer.Character.HumanoidRootPart.Position.Y-3.75, game.Players.LocalPlayer.Character.HumanoidRootPart.Position.Z) task.wait(0)  else floatpad.CanCollide = false end
end)

local vu = game:GetService("VirtualUser")
game:GetService("Players").LocalPlayer.Idled:Connect(function() vu:Button2Down(Vector2.new(0,0),workspace.CurrentCamera.CFrame)task.wait(1)vu:Button2Up(Vector2.new(0,0),workspace.CurrentCamera.CFrame)end)

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
        if kocmoc.toggles.autofarm then
            temptable.dead = true
            kocmoc.toggles.autofarm = false
            temptable.converting = false
            temptable.farmtoken = false
        end
        if temptable.dead then
            task.wait(25)
            temptable.dead = false
            kocmoc.toggles.autofarm = true local player = game.Players.LocalPlayer
            temptable.converting = false
            temptable.farm_tokens = true
        end
    end)
end)

game.Players.PlayerAdded:Connect(function(player)
    if #game.Players:GetPlayers() >= 4 then
        if not shared._chatbotstarted then
            shared._chatbotstarted = true
            while shared._chatbotstarted and #game.Players:GetPlayers() >= 4 do
                task.wait(3)
                game:GetService("ReplicatedStorage").DefaultChatSystemChatEvents.SayMessageRequest:FireServer("[4 OR MORE PLAYERS DETECTED. PLEASE USE THE OTHER AFK SERVER TO AVOID LAGGING THE GAME!]", "All")
            end
            shared._chatbotstarted = false
            game:GetService("ReplicatedStorage").DefaultChatSystemChatEvents.SayMessageRequest:FireServer(player.Name.." has left. There are "..#game.Players:GetPlayers().." players in game now.", "All")
        end
    end
end)

task.spawn(function() while task.wait() do
    pos = game.Players.LocalPlayer.Character.HumanoidRootPart.Position
    task.wait()
    currentSpeed = (pos-game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude
    if currentSpeed > 0 then
        temptable.running = true
    else
        temptable.running = false
    end
end end)

load_config = function(configname)
    if configname then
        kocmoc = HttpService:JSONDecode(readfile("kocmoc/BSS_"..configname..".json"))
    end
    for _, toggle in pairs({"autodig", "autosprinkler", "farmbubbles", "farmflame", "farmcoco", "collectcrosshairs", "farmfuzzy", "farmunderballoons", "farmclouds", "autodispense", "autoboosters", "clock",
        "collectgingerbreads", "autosamovar", "autostockings", "autoplanters", "autocandles", "autofeast", "autoonettart", "freeantpass", "farmsprouts", "farmpuffshrooms", "farmrares", "autoquest", "autodoquest", "honeystorm",
            "killmondo", "killvicious", "killwindy", "autokillmobs", "avoidmobs", "autoant", "tptonpc", "loopfarmspeed", "convertballoons", "donotfarmtokens", "autofarm", "loopspeed", "loopjump", "legit"}) do
            _buttons[toggle]:SetState(kocmoc.toggles[toggle])
    end

    for _, dispense in pairs({"rj", "blub", "straw", "treat", "coconut", "glue", "white", "blue", "red"}) do
        _buttons["dispense"][dispense]:SetState(kocmoc.dispensesettings[dispense])
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
        local v = workspace.Honeycombs:GetChildren()[i]
        if v.Owner.Value == game.Players.LocalPlayer then
            print("already claimed hive")
            has_claimed_hive = true
            break
        end
    end
    if not has_claimed_hive then
        for i = #hives, 1, -1 do
            local v = workspace.Honeycombs:GetChildren()[i]
            if not v.Owner.Value then
                game.ReplicatedStorage.Events.ClaimHive:FireServer(v.HiveID.Value)
                break
            end
        end
    end
end
if _G.autoload then if isfile("kocmoc/BSS_".._G.autoload..".json") then load_config(_G.autoload) end end
for _, part in pairs(workspace:FindFirstChild("FieldDecos"):GetDescendants()) do if part:IsA("BasePart") then part.CanCollide = false part.Transparency = part.Transparency < 0.5 and 0.5 or part.Transparency task.wait() end end
for _, part in pairs(workspace:FindFirstChild("Decorations"):GetDescendants()) do if part:IsA("BasePart") and (part.Parent.Name == "Bush" or part.Parent.Name == "Blue Flower" or part.Parent.Name == "Mushroom") then part.CanCollide = false part.Transparency = part.Transparency < 0.5 and 0.5 or part.Transparency task.wait() end end
