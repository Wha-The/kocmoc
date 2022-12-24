local suffix_to_value = {k = 1000,M = 1000000,B = 1000000000,T = 1000000000000,}
local function count_stray_balloons() -- total up pollen in all stray balloons
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

local function gethiveballoon()
    local result = false
    for i, hive in pairs(workspace.Honeycombs:GetChildren()) do
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

local function get_hive_balloon_size()
    local x = 0
    local s, b = pcall(function()return gethiveballoon().BalloonBody.GuiAttach.Gui.Bar.TextLabel.Text end)
    if s then
        s, x = pcall(function() local a = string.gsub(b, ",", ""); return tonumber(a) end)
    end
    return s and x
end

return count_stray_balloons, gethiveballoon, get_hive_balloon_size
