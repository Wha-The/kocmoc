local proxyfilewrite, proxyfileappend, proxyfileread, proxyfileexists, proxywipecache
local cachewrap
local HttpService = game:GetService("HttpService")
local encode = function(thing) return HttpService:UrlEncode(thing) end

local function communicate(method, path, body)
	local success, result = pcall((syn and syn.request or http_request), {
		Url = "http://127.0.0.1:22125"..path,
		Method = method,
		Body = body,
	})
	if not success then
		print("Error communicating with filesystem proxy: "..result)
		messagebox("Error communicating with filesystem proxy: "..result, "Error", 0) -- i know this hangs the thread
	end
	return result.Body
end

function proxyfilewrite(file, data)
	return communicate("POST", "/write?file="..encode(file), data)
end
function proxyfileappend(file, data)
	return communicate("POST", "/append?file="..encode(file), data)
end
function proxyfileread(file)
	return communicate("GET", "/read?file="..encode(file))
end
function proxyfileexists(file)
	return communicate("GET", "/exists?file="..encode(file)) == "1"
end

local CacheCallbackToOriginalCallback = {}
local Cache = {}
function cachewrap(callback)
	Cache[callback] = {}
	local cachecallback = function(a1, canCache)
		if canCache and Cache[callback][a1] then
			return Cache[callback][a1]
		end
		local result = callback(a1)
		if canCache then
			Cache[callback][a1] = result
		end
		return result
	end
	CacheCallbackToOriginalCallback[cachecallback] = callback
	return cachecallback
end

function proxywipecache(cachecallback, a1)
	local callback = CacheCallbackToOriginalCallback[cachecallback]
	if a1 then
		Cache[callback][a1] = nil
	else
		Cache[callback] = {}
	end
end

if shared.no_filesystem or shared.no_fs_proxy then
	-- appendfile isn't overwritten all of the time
    return writefile, function(n, d) return writefile(readfile(n)..d) end, readfile, function(n) return isfile(n) or isfolder(n) end, function()end
end

return proxyfilewrite, proxyfileappend, cachewrap(proxyfileread), cachewrap(proxyfileexists), proxywipecache
