shared.LoadedModules = shared.LoadedModules or {}
local function fetchcache(path)
    return function(modulename, moduledownload)
        print("load module: "..path.."/"..modulename)
        -- Caching will speed up startup times.
        -- umodules stands for Utility Modules.
        local cached = shared.LoadedModules[path.."/"..modulename] -- Simulate behavior of Roblox Modules
        if cached then
            return table.unpack(cached)
        end

        if not isfile("kocmoc/cache/"..path.."/"..modulename) then
            print("downloading "..("https://raw.githubusercontent.com/Wha-The/kocmoc/main/"..path.."/"..modulename))
            writefile("kocmoc/cache/"..path.."/"..modulename, game:HttpGet(moduledownload or "https://raw.githubusercontent.com/Wha-The/kocmoc/main/"..path.."/"..modulename))
        end
        local load, err = loadstring(readfile("kocmoc/cache/"..path.."/"..modulename), path.."/"..modulename)
        if not load then
            error(err)
        end
        local returnd = table.pack(load())
        returnd.n = nil
        shared.LoadedModules[path.."/"..modulename] = returnd
        return table.unpack(returnd)
    end
end
return fetchcache("umodules"), fetchcache("modules")
