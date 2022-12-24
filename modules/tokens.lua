if not isfile("kocmoc/cache/umodules/import.lua") then writefile("kocmoc/cache/umodules/import.lua", game:HttpGet("https://raw.githubusercontent.com/Wha-The/kocmoc/main/umodules/import.lua")) end
local uimport, import = loadstring(readfile("kocmoc/cache/umodules/import.lua"))()

local token_priority = {
    "Ticket", "Turpentine", "StarTreat", "AtomicTreat", "Diamond", "Gold", "Silver",

    "Neonberry", "SoftWax", "HardWax", "CausticWax", "SwirledWax", "MagicBean",
    "Glue", "Glitter", "BlueExtract", "RedExtract", "Enzymes", "Oil",

    "Token Link",

    "Blueberry", "Strawberry", "Pineapple", "SunflowerSeed", "MoonCharm", "Gumdrops",

    "PollenBomb", "Surprise Party", "Blue Balloon", "Pollen Haze",
}
local maxmagnitude = 70
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
    game.Players.LocalPlayer.Character.Humanoid:MoveTo(token.Position) 
    repeat task.wait() until (token.Position-game.Players.LocalPlayer.Character.PrimaryPart.Position).magnitude <= 3 or not IsToken(token)
    token:SetAttribute("_token_collected", true)
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

    -- check if all names are valid
    local token_texture = {}
    for k, v in pairs(token_index) do
        token_texture[v] = k
    end
    for _, n in pairs(token_priority) do
        if not token_texture[n] then
            warn("Invalid Token Name in Priority List in tokens.lua: "..n)
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
    if (r.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).Magnitude <= maxmagnitude/1.4 and (v3-r.Position).Magnitude <= maxmagnitude then
        farm(r)
    end
end

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
return farm, gettoken
