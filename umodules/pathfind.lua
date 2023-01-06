local PathfindingService = game:GetService("PathfindingService")
local VirtualInputManager = getvirtualinputmanager and getvirtualinputmanager() or game:GetService("VirtualInputManager")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local path = PathfindingService:CreatePath({AgentCanJump = true,})

local waypoints
local nextWaypointIndex
local reachedConnection
local blockedConnection

local function followPath(destination)
	local humanoid = game.Players.LocalPlayer.Character.Humanoid
	-- Compute the path
	local success, errorMessage = pcall(function()
		path:ComputeAsync(game.Players.LocalPlayer.Character.PrimaryPart.Position, destination)
	end)

	if success and path.Status == Enum.PathStatus.Success then
		-- Get the path waypoints
		waypoints = path:GetWaypoints()

		-- Detect if path becomes blocked
		blockedConnection = path.Blocked:Connect(function(blockedWaypointIndex)
			-- Check if the obstacle is further down the path
			if blockedWaypointIndex >= nextWaypointIndex then
				-- Stop detecting path blockage until path is re-computed
				blockedConnection:Disconnect()
				-- Call function to re-compute new path
				followPath(destination)
			end
		end)

		-- Detect when movement to next waypoint is complete
		if not reachedConnection then
			reachedConnection = humanoid.MoveToFinished:Connect(function(reached)
				if reached and nextWaypointIndex < #waypoints then
					-- Increase waypoint index and move to next waypoint
					nextWaypointIndex += 1
					if waypoints[nextWaypointIndex].Action == Enum.PathWaypointAction.Jump then
						humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
					end
					humanoid:MoveTo(waypoints[nextWaypointIndex].Position)
				else
					reachedConnection:Disconnect()
					blockedConnection:Disconnect()
				end
			end)
		end

		-- Initially move to second waypoint (first waypoint is path start; skip it)
		nextWaypointIndex = 2
		humanoid:MoveTo(waypoints[nextWaypointIndex].Position)

		local timeout = false
		task.spawn(function()
			task.wait(20)
			timeout = true
		end)
		repeat task.wait() until nextWaypointIndex >= #waypoints or timeout
		return not timeout
	else
		return false
	end
end

local parseVector3 = function(v)
	if typeof(v) == "table" then
		return Vector3.new(table.unpack(v))
	end
	if v == "hive" then
		return game.Players.LocalPlayer.SpawnPos.Value.Position
	end
end

local function playbackRoute(waypoints)
	for _, command in pairs(waypoints) do
	    if command.Command == "Jump" then
	    	game.Players.LocalPlayer.Character.Humanoid.JumpPower = 77
			if game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("Humanoid") then
				game.Players.LocalPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end
	    elseif command.Command == "Wait" then
	    	task.wait(command.Data.Seconds)
	    elseif command.Command == "Cannon" then
	    	local cannonPos = workspace.Toys[command.Data.Cannon].Platform.Position
	    	local timeout = false
		    task.spawn(function()
		        task.wait(10)
		        timeout = true
		    end)
		    repeat
		        task.wait()
		        if game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("Humanoid") then
		        	game.Players.LocalPlayer.Character.Humanoid:MoveTo(cannonPos)
		    	end
		    until ((game.Players.LocalPlayer.Character.PrimaryPart.Position - cannonPos) * Vector3.new(1, 0, 1)).Magnitude < 2 or timeout
		    if timeout then return false end
			task.wait(.5)
            -- attempt to press "E"
            local ActivateButton = game.Players.LocalPlayer.PlayerGui.ScreenGui.ActivateButton
            if ActivateButton.Position.Y.Offset > 0 then
                -- Press "E"
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                task.spawn(function()
                    task.wait(.1)
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                end)
                -- local start_position = game.Players.LocalPlayer.Character.PrimaryPart.Position
                -- -- test if player was launched
                -- task.wait(.2)
                -- if (game.Players.LocalPlayer.Character.PrimaryPart.Position - start_position).Magnitude > 5 then
                    -- launched, glide to hive.
            end
        elseif command.Command == "Glider" then
        	-- activate parachute
            for i = 1, 2 do
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                task.wait(.1)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
                task.wait(.1)
            end
        elseif command.Command == "FaceWalkToPoint" then
        	local dest = parseVector3(command.Data.Point)
            -- keep rotating player to face hive
            local timeout = false
            task.spawn(function()
                task.wait(10)
                timeout = true
            end)
            repeat
                task.wait()
                local lc = game.Players.LocalPlayer.Character:GetPrimaryPartCFrame()
                game.Players.LocalPlayer.Character.PrimaryPart.CFrame = CFrame.new(lc.Position) * CFrame.Angles(0, Vector3.new(CFrame.new(lc.Position, dest):ToOrientation()).Y ,0)
                game.Players.LocalPlayer.Character.Humanoid:MoveTo(dest)
            until (game.Players.LocalPlayer.Character.PrimaryPart.Position - dest).Magnitude < 5 or timeout
            if timeout then return false end
        elseif command.Command == "Walk" then
        	local timeout = false
		    task.spawn(function()
		        task.wait(10)
		        timeout = true
		    end)
		    local dest = parseVector3(command.Data.Point)
		    repeat
		        task.wait()
		        game.Players.LocalPlayer.Character.Humanoid:MoveTo(dest)
		    until (game.Players.LocalPlayer.Character.PrimaryPart.Position - dest).Magnitude < 2 or timeout
		    if timeout then return false end
	    end
	    
	end
	return true
end

return followPath, playbackRoute
