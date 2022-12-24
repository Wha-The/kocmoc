local get_parts_of_path = function(path)
    return string.split(path, "/")
end
local derive_parent = function(path)
    local parts = get_parts_of_path()
    parts[#parts] = nil
    return table.concat(parts, "/")
end
local derive_end = function(path)
    local parts = get_parts_of_path()
    return parts[#parts]
end
shared.filesystem = shared.filesystem or {}
readfile = function(path)
    local current = shared.filesystem
    for _, part in pairs(get_parts_of_path(path)) do
        if not current[part] then
            return false
        end
        current = current[part]
    end
    return current
end

isfile = function(path)
    if path == "" then return true end
    return readfile(path) ~= false
end
isfolder = isfile
writefile = function(path, data)
    local root = readfile(derive_parent(path))
    if root then
        root[derive_end(path)] = data
    end
end
makefolder = function(path)
    return writefile(path, {})
end
