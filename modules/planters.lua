if not isfile("kocmoc/cache/umodules/import.lua") then writefile("kocmoc/cache/umodules/import.lua", game:HttpGet("https://raw.githubusercontent.com/Wha-The/kocmoc/main/umodules/import.lua")) end
local uimport, import = loadstring(readfile("kocmoc/cache/umodules/import.lua"))()

local proxyfilewrite, proxyfileappend, proxyfileread, proxyfileexists, proxywipecache 	= uimport("proxyfileinterface.lua")
local find_field 																		= import("find_field.lua")
local playRoute, routeToField 															= import("routes.lua")
local Pipes 																			= import("Pipes.lua")
local farm, gettoken 																	= import("tokens.lua")
local get_buff_combo, get_buff_active_duration, get_buff_percentage, compile_buff_list  = import("buffs.lua")

local HttpService = game:GetService("HttpService")

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
    ["Invigorating Nectar"] = {
        Pots = {"Red Clay Planter", "Pesticide Planter", "Plastic Planter"},
        Fields = {"Pepper Patch", "Spider Field", "Mountain Top Field", "Cactus Field", "Clover Field"},
    }
}

local allnectars = {"Comforting Nectar", "Invigorating Nectar", "Motivating Nectar" "Refreshing Nectar", "Satisfying Nectar"}
local nectarprioritypresets = {
    Blue = {1, 3, 5, 4, 2},
    Red = {2, 4, 5, 3, 1},
    White = {5, 1, 4, 3, 2},
}

local GetPlanterData = require(game.ReplicatedStorage.PlanterTypes).Get

function compile_planters()
    local planters = {}
    local nectar -- find the nectar which the field where the planter on is for

    for i,v in pairs(getupvalues(require(game:GetService("ReplicatedStorage").LocalPlanters).LoadPlanter)[4]) do 
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
    for i,v in pairs(getupvalues(require(game:GetService("ReplicatedStorage").LocalPlanters).LoadPlanter)[4]) do 
        if v.IsMine then
            total += 1
        end
    end
    if total >= 3 then return end -- already full, can't plant more

    local NectarPriority = {}
    for _, id in pairs(nectarprioritypresets[kocmoc.planters.priority]) do
        table.insert(NectarPriority, allnectars[id])
    end

    -- populate "occupied_fields" and "planters_in_use"
    local occupied_fields = {}
    local planters_in_use = {}
    local nectars_already_working_on = {}
    for i,v in pairs(getupvalues(require(game:GetService("ReplicatedStorage").LocalPlanters).LoadPlanter)[4]) do 
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
        if not kocmoc.planters.farmnectars[nectar] then continue end -- skip ones that aren't marked on

        local percent = get_buff_percentage(nectar)
        local recommended_hover_above = index <= 3 and 0.8 or 0.6
        if table.find(nectars_already_working_on, nectar) and percent > (recommended_hover_above/1.5) then continue end
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

    if #nectars_needed == 0 then return end
    if #nectars_needed < 3 then
        while #nectars_needed < 3 do
            for _, v in pairs(nectars_needed) do
                table.insert(nectars_needed, v)
            end
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
            game.Players.LocalPlayer.Character:SetPrimaryPartCFrame(CFrame.new(workspace.FlowerZones[field].Position) + Vector3.new(0, 3, 0))
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
    for i, v in pairs(getupvalues(require(game:GetService("ReplicatedStorage").LocalPlanters).LoadPlanter)[4]) do
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
                    local nectar_given = v.GrowthPercent * GetPlanterData(v.Type).MaxGrowth * 1.1 -- *1.1 because it's the average and a good assumption.
                    if (get_buff_percentage(nectar) * (24 * 60 * 60) + nectar_given) > ((24 * 60 * 60) * (recommended_hover_above + 0.15)) then
                        should_harvest = true
                    end
                end
            end
            if not force_harvest and not should_harvest then continue end
            if kocmoc.toggles.legit then
                routeToField(field)
                game.Players.LocalPlayer.Character.Humanoid:MoveTo(v.PotModel.Soil.Position)
            end
            if find_field(game.Players.LocalPlayer.Character.PrimaryPart.Position) ~= field then
                game.Players.LocalPlayer.Character:SetPrimaryPartCFrame(v.PotModel.Soil.CFrame)
            end
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
end

return compile_planters, place_new_planters, collectplanters, allnectars, nectarprioritypresets
