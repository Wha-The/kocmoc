local proxyfilewrite, proxyfileappend, proxyfileread, proxyfileexists
local HttpService = game:GetService("HttpService")
local encode = function(thing) return HttpService:UrlEncode(thing) end

local function communicate(method, path, body)
	local success, result = pcall(syn.request, {
		Url = "http://127.0.0.1:22125"..path,
		Method = method,
		Body = body,
	})
	if not success then
		-- hang thread
		messagebox(result)
		while true do task.wait(1e6) end
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

return proxyfilewrite, proxyfileappend, proxyfileread, proxyfileexists
