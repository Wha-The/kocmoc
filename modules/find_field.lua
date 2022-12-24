local function find_field(position, options)
    options = options or {}
    local matches = {}
    for _, p in pairs(workspace.FlowerZones:GetChildren()) do
        if options.exceptions and table.find(options.exceptions, p.Name) then continue end
        table.insert(matches, {(position - p.Position).Magnitude, p.Name})
    end
    if options.hive and (not options.exceptions or not table.find(options.exceptions, "hive")) then
        -- consider the hive too
        table.insert(matches, {(position - game.Players.LocalPlayer.SpawnPos.Value.Position).Magnitude, "hive"})
    end
    table.sort(matches, function(a, b) return a[1] < b[1] end)
    return matches[1][2]
end
return find_field
