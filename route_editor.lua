if not isfolder("kocmoc") then makefolder("kocmoc") end
if not isfolder("kocmoc/cache") then makefolder("kocmoc/cache") end
if not isfolder("kocmoc/cache/umodules") then makefolder("kocmoc/cache/umodules") end
if not isfolder("kocmoc/cache/modules") then makefolder("kocmoc/cache/modules") end

if not isfile("kocmoc/cache/umodules/import.lua") then writefile("kocmoc/cache/umodules/import.lua", game:HttpGet("https://raw.githubusercontent.com/Wha-The/kocmoc/main/umodules/import.lua")) end
local uimport, import = loadstring(readfile("kocmoc/cache/umodules/import.lua"))()

local proxyfilewrite, proxyfileappend, proxyfileread, proxyfileexists, proxywipecache	= uimport("proxyfileinterface.lua")
local pathfind, playbackRoute															= uimport("pathfind.lua")

local UserInputService = game:GetService("UserInputService")
local ScreenGui = game:GetObjects("rbxassetid://11806110065")[1]:Clone()
ScreenGui.Parent = game.CoreGui
ScreenGui.ResetOnSpawn = false
local MainFrame = ScreenGui:WaitForChild("MainFrame")

local CommandBar = MainFrame:WaitForChild("CommandBar"):WaitForChild("Content")
local Output = MainFrame:WaitForChild("ScrollingFrame")
local Template = Output:WaitForChild("Frame")
local Prompt = ScreenGui:WaitForChild("Prompt")
Prompt.Visible = false
Template.Visible = false
Template.Parent = nil

local function getChildrenOrdered()
	local items = {} 
	for _, temp in pairs(Output:GetChildren()) do
		if not temp:IsA("ImageButton") then continue end
		table.insert(items, temp)
	end
	table.sort(items, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	return items
end

local function prompt(question)
	if Prompt.Visible then
		-- another prompt in progress: auto cancel this prompt
		return
	end
	Prompt.Visible = true
	Prompt.Text = ""
	Prompt.PlaceholderText = question
	Prompt:CaptureFocus()
	local enterPressed = Prompt.FocusLost:Wait()
	Prompt.Visible = false
	return enterPressed and Prompt.Text
end

local current_index = 1

local function compileOutput(toComp)
	local data = {}
	for _, temp in pairs(toComp or getChildrenOrdered()) do
		local extradata = {}
		for n, v in pairs(temp:GetAttributes()) do
			if string.sub(n, 1, 5) == "data_" then
				if typeof(v) == "Vector3" then
					extradata[string.sub(n, 6, -1)] = {v.X, v.Y, v.Z}
				else
					extradata[string.sub(n, 6, -1)] = v
				end
			end
		end
		table.insert(data, {
			Command = temp:GetAttribute("Command"),
			Data = extradata,
		})
	end
	return data
end

local function getSelected()
	local selected = {}
	for _, command in pairs(getChildrenOrdered()) do
		if command:GetAttribute("Selected") then
			table.insert(selected, command)
		end
	end
	return selected
end
local function toggleSelected(temp)
	temp:SetAttribute("Selected", not temp:GetAttribute("Selected"))
	temp.BackgroundColor3 = temp:GetAttribute("Selected") and Color3.fromRGB(11, 90, 175) or Color3.fromRGB(255, 255, 255)
	temp.TextLabel.TextColor3 = temp:GetAttribute("Selected") and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(0, 0, 0)
end
local function getPlayerPosition()
	return game.Players.LocalPlayer.Character.PrimaryPart.Position
end

local function deriveDisplayText(temp)
	return ({
		Walk = function()
			local point = temp:GetAttribute("data_Point")
			if point == "hive" then
				return "Walk | (HIVE)"
			end
			return "Walk | "..math.round(point.X)..", "..math.round(point.Y)..", "..math.round(point.Z)
		end,
		Wait = function()
			local seconds = temp:GetAttribute("data_Seconds")
			return "Wait "..seconds.."s"
		end,
		Jump = function()
			return "Jump"
		end,
		FaceWalkToPoint = function()
			local point = temp:GetAttribute("data_Point")
			if point == "hive" then
				return "FaceWalkToPoint | (HIVE)"
			end
			return "FaceWalkToPoint | "..math.round(point.X)..", "..math.round(point.Y)..", "..math.round(point.Z)
		end,
		Cannon = function()
			return "Cannon | "..temp:GetAttribute("data_Cannon")
		end,
		Glider = function()
			return "Activate Glider"
		end,
	})[temp:GetAttribute("Command")]()
end

local selected_start_before_shiftclick
local last_move_scrollwheel_pos
local function addCommand(command, data)
	data = data or {}
	local colors = {
		Walk = Color3.fromRGB(17, 198, 8),
		Wait = Color3.fromRGB(95, 88, 88),
		Cannon = Color3.fromRGB(255, 0, 0),
		Glider = Color3.fromRGB(229, 175, 13),
		Jump = Color3.fromRGB(85, 170, 127),
		FaceWalkToPoint = Color3.fromRGB(229, 96, 198),
	}
	local temp = Template:Clone()
	temp.UIStroke.Color = colors[command]
	temp:SetAttribute("Command", command)
	for k, v in pairs(data) do
		temp:SetAttribute("data_"..k, v)
	end
	temp:SetAttribute("Selected", false)
	temp.LayoutOrder = current_index
	current_index += 1
	temp.TextLabel.Text = deriveDisplayText(temp)
	temp.MouseButton1Click:Connect(function()
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
			local selected = getSelected()
			if #selected >= 1 then
				if not selected_start_before_shiftclick then
					selected_start_before_shiftclick = selected[#selected]
				end

				for _, _selected in pairs(selected) do
					toggleSelected(_selected)
				end

				for _, _temp in pairs(getChildrenOrdered()) do
					if (_temp.LayoutOrder <= temp.LayoutOrder and _temp.LayoutOrder >= selected_start_before_shiftclick.LayoutOrder) or
						(_temp.LayoutOrder >= temp.LayoutOrder and _temp.LayoutOrder <= selected_start_before_shiftclick.LayoutOrder) then
						toggleSelected(_temp)
					end
				end
			end
		elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
			if selected_start_before_shiftclick then
				selected_start_before_shiftclick = temp
			end
			toggleSelected(temp)
		else
			selected_start_before_shiftclick = nil
			for _, selected in pairs(getSelected()) do
				if selected == temp then continue end
				toggleSelected(selected)
			end
			toggleSelected(temp)
		end
	end)
	temp.Visible = true
	temp.Parent = Output

	return temp
end
CommandBar.FaceWalkToField.Text = "Load"
(function(s)
	local order = {"Playback", "Save", "AddWalk", "AddWait", "AddCannon", "AddGlider", "AddJump", "FaceWalkToPoint", "FaceWalkToField"}
	for index, callback in pairs(s) do
		local button = CommandBar:WaitForChild(order[index])
		button.MouseButton1Click:Connect(callback)
	end
end)({
	function()
		local selected = getSelected()
		if #selected <= 0 then
			selected = nil
		end
		local data = compileOutput(selected)
		playbackRoute(data)
	end,
	function()
		local data = compileOutput()
		local fname = prompt("filename?")
		if not fname then return end
		fname ..= ".route"
		local root = "routes/"
		if proxyfileexists("kocmoc") then
			root = "kocmoc/"..root
		end
		proxyfilewrite(root..fname, game:GetService("HttpService"):JSONEncode(data))
	end,
	function()
		if (getPlayerPosition() - game:GetService("Players").LocalPlayer.SpawnPos.Value.Position).Magnitude < 10 then
			return addCommand("Walk", {Point = "hive"})
		end
		addCommand("Walk", {Point = getPlayerPosition()})
	end,
	function()
		local seconds = prompt("seconds?")
		while not tonumber(seconds) do
			seconds = prompt("not a number. seconds?")
			if not seconds then break end
		end
		if not seconds then return end
		addCommand("Wait", {Seconds=tonumber(seconds)})
	end,
	function()
		local cannon, closestmag = "", math.huge
		for _, toy in pairs(workspace.Toys:GetChildren()) do
			local mag = (toy.Platform.Position - getPlayerPosition()).Magnitude
			if toy:FindFirstChild("Platform") and mag < closestmag then
				closestmag = mag
				cannon = toy.Name
			end
		end
		addCommand("Cannon", {Cannon=cannon})
	end,
	function()
		addCommand("Glider")
	end,
	function()
		addCommand("Jump")
	end,
	function()
		if (getPlayerPosition() - game:GetService("Players").LocalPlayer.SpawnPos.Value.Position).Magnitude < 10 then
			return addCommand("FaceWalkToPoint", {Point = "hive"})
		end
		addCommand("FaceWalkToPoint", {Point = getPlayerPosition()})
	end,
	function()
		local fname = prompt("filename?")
		if not fname then return end
		fname ..= ".route"
		local root = "routes/"
		if proxyfileexists("kocmoc") then
			root = "kocmoc/"..root
		end
		if not proxyfileexists(root..fname) then return end
		local data = game:GetService("HttpService"):JSONDecode(proxyfileread(root..fname))
		for _, selected in pairs(getSelected()) do
			toggleSelected(selected)
		end
		for _, command in pairs(data) do
			local cmddata = command.Data
			if cmddata.Point and typeof(cmddata.Point) == "table" then
				cmddata.Point = Vector3.new(cmddata.Point[1], cmddata.Point[2], cmddata.Point[3])
			end
			toggleSelected(addCommand(command.Command, cmddata))
		end
	end,
})

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.Keyboard then
		if input.KeyCode == Enum.KeyCode.Backspace then
			local selected = getSelected()
			if #selected >= 1 then
				for _, item in pairs(selected) do
					item:Destroy()
				end
			else
				local items = getChildrenOrdered()
				if #items <= 0 then return end
				items[#items]:Destroy()
			end
		elseif table.find({Enum.KeyCode.LeftBracket, Enum.KeyCode.RightBracket}, input.KeyCode) then
			local isUp = input.KeyCode == Enum.KeyCode.LeftBracket
			local all = getChildrenOrdered()
			local selected = getSelected()
			if #selected <= 0 or #all <= 1 then return end
			
			for index = (isUp and 1 or #selected), (isUp and #selected or 1), (isUp and 1 or -1) do 
				local _selected = selected[index]
				local other = all[table.find(all, _selected) + (isUp and -1 or 1)]
				other.LayoutOrder, _selected.LayoutOrder = _selected.LayoutOrder, other.LayoutOrder
			end
			
		end
	end
end)
