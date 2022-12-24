shared.ModuleCache = shared.ModuleCache or {}
local function fetchcache(path)
    return function(modulename, moduledownload)
        -- Caching will speed up startup times.
        -- umodules stands for Utility Modules.
        local cached = shared.ModuleCache[path.."/"..modulename] -- Simulate behavior of Roblox Modules
        if cached then
            return table.unpack(cached)
        end

        if not isfile("kocmoc/cache/"..path.."/"..modulename) then
            writefile("kocmoc/cache/"..path.."/"..modulename, game:HttpGet(moduledownload or "https://raw.githubusercontent.com/Wha-The/kocmoc/main/"..path.."/"..modulename..".lua"))
        end

        local returnd = table.pack(loadstring(readfile("kocmoc/cache/"..path.."/"..modulename))())
        shared.ModuleCache[path.."/"..modulename] = returnd
        return table.unpack(returnd)
    end
end

return fetchcache("umodules"), fetchcache("modules")
