local uimport, import = ((isfile("kocmoc/cache/umodules/import.lua") or not writefile("kocmoc/cache/umodules/import.lua", game:HttpGet("https://raw.githubusercontent.com/Wha-The/kocmoc/main/umodules/import.lua"))) and loadstring(readfile("kocmoc/cache/umodules/import.lua"))())

local proxyfilewrite, proxyfileappend, proxyfileread, proxyfileexists, proxywipecache   = uimport("proxyfileinterface.lua")
local followPath, playbackRoute                                                         = uimport("pathfind.lua")
local find_field                                                                        = import("find_field.lua")

local HttpService = game:GetService("HttpService")

if not isfolder("kocmoc/routes") then -- Download all 200+ routes that I've spent hours working on :) and unpack them all into kocmoc/routes
    makefolder("kocmoc/routes")

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
    unpack_directory("kocmoc/", routes) -- unpacks like a zip
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
        return playRoute(start, "hive") and playRoute("hive", dest)
    end
    local success, data = pcall(HttpService.JSONDecode, HttpService, proxyfileread(fname, true))
    if not success then
        warn(data)
        warn("file: "..fname)
        warn("Data: "..proxyfileread(fname, true))
        proxywipecache(proxyfileread, fname)
        return
    end
    return playbackRoute(data)
end

function routeToField(field)
    local currentField = find_field(game.Players.LocalPlayer.Character.PrimaryPart.Position, {hive=true})
    return playRoute(currentField, field)
end

return playRoute, routeToField
