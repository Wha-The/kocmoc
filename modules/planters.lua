if not isfile("kocmoc/cache/umodules/import.lua") then writefile("kocmoc/cache/umodules/import.lua", game:HttpGet("https://raw.githubusercontent.com/Wha-The/kocmoc/main/umodules/import.lua")) end
local uimport, import = loadstring(readfile("kocmoc/cache/umodules/import.lua"))()

local proxyfilewrite, proxyfileappend, proxyfileread, proxyfileexists, proxywipecache 	= uimport("proxyfileinterface.lua")
local find_field 																		= import("find_field.lua")
local playRoute, routeToField 															= import("routes.lua")
local Pipes 																			= import("Pipes.lua")
local farm, gettoken 																	= import("tokens.lua")
local get_buff_combo, get_buff_active_duration, get_buff_percentage, compile_buff_list  = import("buffs.lua")
local api                                                                               = uimport("api.lua", "https://raw.githubusercontent.com/Boxking776/kocmoc/main/api.lua")

local HttpService = game:GetService("HttpService")

local PlanterRecommendedFields = {
    ["Comforting Nectar"] = {
        Pots = {"Hydroponic Planter", "Blue Clay Planter", "Plastic Planter"},
        Fields = {"Pine Tree Forest", "Bamboo Field"},
    },
    ["Refreshing Nectar"] = {
        Pots = {"Pesticide Planter", "Hydroponic Planter", "Plastic Planter"},
        Fields = {"Strawberry Field", "Blue Flower Field", "Coconut Field"},
    },
    ["Satisfying Nectar"] = {
        Pots = {"Petal Planter", "Tacky Planter", "Plastic Planter"},
        Fields = {"Pumpkin Patch", "Sunflower Field", "Pineapple Patch"},
    },
    ["Motivating Nectar"] = {
        Pots = {"Heat-Treated Planter", "Candy Planter", "Red Clay Planter", "Pesticide Planter", "Plastic Planter"},
        Fields = {"Stump Field", "Rose Field", "Spider Field", "Mushroom Field"},
    },
    ["Invigorating Nectar"] = {
        Pots = {"Heat-Treated Planter", "Red Clay Planter", "Pesticide Planter", "Plastic Planter"},
        Fields = {"Pepper Patch", "Mountain Top Field", "Cactus Field", "Clover Field"},
    }
}

-- ULTRA OPTIMIZED VERSION FOR BLUE HIVES https://docs.google.com/document/d/1V0U8k_Ha1irNPkr7LIQismElw__GbLEnhcfwyTXEp1w/edit
-- local PlanterRecommendedFields = {
--     ["Comforting Nectar"] = {
--         Pots = {"Blue Clay Planter", "Tacky Planter"},
--         Fields = {"Pine Tree Forest", "Dandelion Field"},
--     },
--     ["Refreshing Nectar"] = {
--         Pots = {"Pesticide Planter", "Blue Clay Planter"},
--         Fields = {"Strawberry Field", "Blue Flower Field"},
--     },
--     ["Satisfying Nectar"] = {
--         Pots = {"Tacky Planter"},
--         Fields = {"Sunflower Field"},
--     },
--     ["Motivating Nectar"] = {
--         Pots = {"Pesticide Planter", "Red Clay Planter"},
--         Fields = {"Spider Field", "Rose Field"},
--     },
--     -- invigorating nectar is not used in the blue hive, this should be off in settings.
--     ["Invigorating Nectar"] = {
--         Pots = {"Heat-Treated Planter", "Red Clay Planter", "Pesticide Planter", "Plastic Planter"},
--         Fields = {"Pepper Patch", "Mountain Top Field", "Cactus Field", "Clover Field"},
--     }
-- }
local PlanterOptions = {
    ["Comforting Nectar"] = {
        {{"Hydroponic Planter", "Blue Clay Planter"}, "Pine Tree Forest"},
        {{"Petal Planter", "Tacky Planter"}, "Dandelion Field"},
    },
    ["Refreshing Nectar"] = {
        {{"Pesticide Planter"}, "Strawberry Field"},
        {{"Hydroponic Planter", "Blue Clay Planter"}, "Blue Flower Field"},
    },
    ["Satisfying Nectar"] = {
        {{"Tacky Planter"}, "Sunflower Field"},
    },
    ["Motivating Nectar"] = {
        {{"Pesticide Planter"}, "Spider Field"},
        {{"Heat-Treated Planter", "Red Clay Planter"}, "Rose Field"},
    },
    ["Invigorating Nectar"] = { -- should never be used
        {{"Heat-Treated Planter"}, "Pepper Patch"},
        {{"Red Clay Planter"}, "Mountain Top Field"},
        {{"Plastic Planter"}, "Clover Field"},
    }
}


local ColoredPlanters = {
    ["Heat-Treated Planter"] = "Red",
    ["Red Clay Planter"] = "Red",
    ["Hydroponic Planter"] = "Blue",
    ["Blue Clay Planter"] = "Blue",
}

local VirtualInputManager = game:GetService("VirtualInputManager")

local allnectars = {"Comforting Nectar", "Invigorating Nectar", "Motivating Nectar", "Refreshing Nectar", "Satisfying Nectar"} -- The order must be preserved. `nectarprioritypresets` uses this order.

local nectarprioritypresets = {
    Blue = {1, 3, 5, 4, 2},
    Red = {2, 4, 5, 3, 1},
    White = {5, 1, 4, 3, 2},
}

local GetPlanterData = require(game.ReplicatedStorage.PlanterTypes).Get
local getupvalues = debug.getupvalues or getupvalues

local function compileactiveplanters()
    if shared.kocmoc.toggles.expsamescriptenv then
        return getupvalues(require(game:GetService("ReplicatedStorage").LocalPlanters).LoadPlanter)[4]
    end
    local t = workspace.Planters:GetChildren()
    local planters = {}

    local function find_closest_pot_model(pos)
        local closest, closestMag = nil, math.huge
        for _, p in t do
            if not p:IsA("Model") then continue end
            local mag = (p:GetModelCFrame().Position - pos).Magnitude
            if mag < closestMag then
                closestMag = mag
                closest = p
            end
        end
        return closest
    end

    for _, p in t do
        if not p:IsA("MeshPart") then continue end -- not PlanterBulb
        local success, textlabel = pcall(function()
            return p["Gui Attach"]["Planter Gui"].Bar.TextLabel
        end)
        if not success then print(textlabel) continue end -- not ours
        local percent = tonumber(textlabel.Text:match("%((.-)%%%)"))/100
        local pot = find_closest_pot_model(p.Position)
        table.insert(planters, {
            IsMine = true,
            GrowthPercent = percent,
            PotModel = pot,
            Type = string.gsub(pot.Name, " Planter", ""),
        })
    end
    return planters
end

local function compile_planters()
    local planters = {}
    local nectar -- find the nectar which the field where the planter on is for

    for i,v in compileactiveplanters() do 
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
                EstimatedDurationLeft = math.round((1 - v.GrowthPercent) * GetPlanterData(v.Type).MaxGrowth),
            })
        end
    end
    Pipes.toAHK({
        Type = "update_planters",
        Planters = planters,
    })
end

local get_nectar_priority = function()
    local NectarPriority = {}
    for _, id in pairs(nectarprioritypresets[kocmoc.planters.priority]) do
        table.insert(NectarPriority, allnectars[id])
    end
    return NectarPriority
end

local function place_new_planters()
    local total = 0
    for i,v in compileactiveplanters() do
        if v.IsMine then
            total += 1
        end
    end
    if total >= 3 then return end -- already full, can't plant more

    local NectarPriority = get_nectar_priority()

    -- populate "occupied_fields" and "planters_in_use"
    local occupied_fields = {}
    local planters_in_use = {}
    local nectars_already_working_on = {}
    for i,v in compileactiveplanters() do 
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
        if not kocmoc.planters.farmnectars[nectar] then continue end -- skip ones that aren't marked

        local percent = get_buff_percentage(nectar)
        local recommended_hover_above = index <= 3 and 0.85 or 0.6
        if table.find(nectars_already_working_on, nectar) then continue end
        if percent < recommended_hover_above then
            table.insert(nectars_needed, nectar)
            table.insert(nectars_already_working_on, nectar)
        end
    end
    -- if no nectar is <80%, populate "nectars_needed" with all nectars arranged from lowest to highest 
    if #nectars_needed <= 0 then
        local nectars = {}
        for _, nectar in pairs(NectarPriority) do
            if not kocmoc.planters.farmnectars[nectar] then continue end -- skip ones that aren't marked
            table.insert(nectars, {get_buff_percentage(nectar), nectar})
        end
        table.sort(nectars, function(a, b) return a[1] < b[1] end)
        for _, data in pairs(nectars) do
            table.insert(nectars_needed, data[2])
        end
    end

    if #nectars_needed == 0 then return end
    if #nectars_needed == 2 then
        nectars_needed = {nectars_needed[1], nectars_needed[2], nectars_needed[1]}
    elseif #nectars_needed == 1 then
        nectars_needed = {nectars_needed[1], nectars_needed[1], nectars_needed[1]}
    end

    -- Load Planter Degration File
    local success, LastCollectTimes = pcall(function() return HttpService:JSONDecode(proxyfileread("kocmoc/planter_degradation.planters")) end)
    if not success then LastCollectTimes = {} end
    -- go plant
    local planted = 0
    for _, nectar in pairs(nectars_needed) do
        if total >= 3 then break end

        local field, pot do
            -- local available_fields = {}
            -- for _, _f in pairs(PlanterRecommendedFields[nectar].Fields) do
            --     if not table.find(occupied_fields, _f) then
            --         table.insert(available_fields, _f)
            --     end
            -- end
            local available_fields = {}
            for _, option in PlanterOptions[nectar] do
                if not table.find(occupied_fields, option[2]) then
                    table.insert(available_fields, option[2])
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

        -- local pot do
        --     for _, _p in pairs(PlanterRecommendedFields[nectar].Pots) do
        --         pot = _p

        --         -- if the pot is colored, check if the field matches that color. If it doesn't, use a different pot.
        --         if ColoredPlanters[pot] then
        --             if workspace.FlowerZones:FindFirstChild(field) and workspace.FlowerZones[field]:FindFirstChild("ColorGroup") then
        --                 if string.lower(workspace.FlowerZones[field]["ColorGroup"].Value) ~= string.lower(ColoredPlanters[pot]) then
        --                     continue
        --                 end
        --             end
        --         end

        --         -- check if the player owns this pot
        --         local potId = string.gsub(pot, " Planter", "Planter")
        --         if not statsget().Eggs[potId] or statsget().Eggs[potId] <= 0 then -- `statsget` is a global variable
        --             continue
        --         end
        --         if not table.find(planters_in_use, pot) then
        --             break
        --         end
                
        --     end
        --     if not pot then
        --         pot = "Paper Planter"
        --     else
        --         table.insert(planters_in_use, pot)
        --     end
        -- end
        local function determine_pot()
            for optionid, option in PlanterOptions[nectar] do
                if option[2] == field then
                    local available_planters = option[1]
                    for _, _p in pairs(available_planters) do
                        pot = _p
        
                        -- if the pot is colored, check if the field matches that color. If it doesn't, use a different pot.
                        -- if ColoredPlanters[pot] then
                        --     if workspace.FlowerZones:FindFirstChild(field) and workspace.FlowerZones[field]:FindFirstChild("ColorGroup") then
                        --         if string.lower(workspace.FlowerZones[field]["ColorGroup"].Value) ~= string.lower(ColoredPlanters[pot]) then
                        --             continue
                        --         end
                        --     end
                        -- end
                        -- EDIT: ALREADY CHECKED BY SPECIFYING PREDEFINED COMBINATIONS
        
                        -- check if the player owns this pot
                        local potId = string.gsub(pot, " Planter", "Planter")
                        if not statsget().Eggs[potId] or statsget().Eggs[potId] <= 0 then -- `statsget` is a global variable
                            pot = nil
                            continue
                        end
                        if not table.find(planters_in_use, pot) then
                            break
                        end
                    end
                    if not pot then
                        -- pot = "Paper Planter"
                        -- error: lets check if theres a better field
                        local nextoption = PlanterOptions[nectar][optionid + 1]
                        if nextoption then
                            field = nextoption[2]
                            return determine_pot()
                        else
                            pot = "Paper Planter"
                        end
                    else
                        table.insert(planters_in_use, pot)
                    end
                    break
                end
            end
            return pot
        end

        local pot = determine_pot()
        -- determine what pot is best for the fieldd

        
        -- go to field and plant
        if kocmoc.toggles.legit then
            routeToField(field)
        end
        if find_field(game.Players.LocalPlayer.Character.PrimaryPart.Position) ~= field then 
            game.Players.LocalPlayer.Character:SetPrimaryPartCFrame(CFrame.new(workspace.FlowerZones[field].Position) + Vector3.new(0, 3, 0))
        end
        task.wait(1)
        print("Placing Pot: " .. pot .. " on Field: " .. field)
        game:GetService("ReplicatedStorage").Events.PlayerActivesCommand:FireServer({["Name"] = pot})
        task.wait(1)
        total += 1
        planted += 1
    end
    return planted
end

local function collectplanters(force_harvest)
    local NectarPriority = get_nectar_priority()
    local has_collected = false
    for i, v in compileactiveplanters() do
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
                    local recommended_hover_above = table.find(NectarPriority, nectar) <= 3 and 0.8 or 0.7
                    local nectar_given = v.GrowthPercent * GetPlanterData(v.Type).MaxGrowth * 1.1 -- *1.1 because it's the average and a good assumption.
                    if (get_buff_percentage(nectar) * (24 * 60 * 60) + nectar_given) > ((24 * 60 * 60) * (recommended_hover_above + 0.15)) then
                        should_harvest = true
                    end
                end
            end
            if not force_harvest and not should_harvest then continue end
            if kocmoc.toggles.legit then
                routeToField(field)
                game.Players.LocalPlayer.Character:WaitForChild("Humanoid"):MoveTo(v.PotModel.Soil.Position)
            end
            if find_field(game.Players.LocalPlayer.Character.PrimaryPart.Position) ~= field then
                api.tween(nil, v.PotModel.Soil.CFrame)
            end
            local Soil = v.PotModel.Soil
            task.wait(1)
            if v.ActorID then
                game:GetService("ReplicatedStorage").Events.PlanterModelCollect:FireServer(v.ActorID)
            else
                -- send "E"
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                task.spawn(function()
                    task.wait(.1)
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                end)
            end
            
            local success, LastCollectTimes = pcall(function() return HttpService:JSONDecode(proxyfileread("kocmoc/planter_degradation.planters")) end)
            if not success then LastCollectTimes = {} end
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
            has_collected = true
        end
    end
    if has_collected then refresh_stats() end
    place_new_planters()
end

return compile_planters, place_new_planters, collectplanters, allnectars, nectarprioritypresets
