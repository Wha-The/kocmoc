local uimport, import = ((isfile("kocmoc/cache/umodules/import.lua") or not writefile("kocmoc/cache/umodules/import.lua", game:HttpGet("https://raw.githubusercontent.com/Wha-The/kocmoc/main/umodules/import.lua"))) and loadstring(readfile("kocmoc/cache/umodules/import.lua"))())
local proxyfilewrite, proxyfileappend, proxyfileread, proxyfileexists, proxywipecache = uimport("proxyfileinterface.lua")

local HttpService = game:GetService("HttpService")

-- Sewage pipes :)
-- Reason we're using a proxy to read/write is because synapse crashes if you call readfile/writefile too much
-- This does require a separate HTTP server running in the background though - which's existence is checked before the main script runs.
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

return Pipes
