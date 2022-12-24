if not isfile("kocmoc/cache/umodules/import.lua") then writefile("kocmoc/cache/umodules/import.lua", game:HttpGet("https://raw.githubusercontent.com/Wha-The/kocmoc/main/umodules/import.lua")) end
local uimport, import = loadstring(readfile("kocmoc/cache/umodules/import.lua"))()
local proxyfilewrite, proxyfileappend, proxyfileread, proxyfileexists, proxywipecache   = uimport("proxyfileinterface.lua")
local Pipes                                                                             = import("Pipes.lua")

local function round_decimal(n, place)
    return string.format("%."..place.."f", n)
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
return get_buff_combo, get_buff_active_duration, get_buff_percentage, compile_buff_list
