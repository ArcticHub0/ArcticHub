-- games/demo.lua - actual game script for the loader
local ArcticHub = ...

if not ArcticHub then
	return
end

local Window = ArcticHub:CreateWindow({
	Title = "ArcticHub - Example",
	Size = Vector2.new(600, 450),
	Theme = "Arctic",
})

local Main = Window:AddTab("Main")
local Misc = Window:AddTab("Misc")

Main:AddSection("Features")

Main:AddToggle({
	Name = "ESP",
	Default = false,
	Callback = function(v)
		print("ESP:", v)
	end,
})

Main:AddToggle({
	Name = "Aimbot",
	Default = false,
	Callback = function(v)
		print("Aimbot:", v)
	end,
})

Main:AddSlider({
	Name = "FOV",
	Min = 0,
	Max = 120,
	Default = 60,
	Increment = 1,
	Callback = function(v)
		print("FOV:", v)
	end,
})

Main:AddDropdown({
	Name = "Target Mode",
	Options = {"Closest", "Head", "Body"},
	Default = "Closest",
	Callback = function(v)
		print("Target Mode:", v)
	end,
})

Main:AddSection("Actions")

Main:AddButton({
	Name = "Kill All",
	Callback = function()
		print("Kill All executed")
	end,
})

Main:AddButton({
	Name = "Teleport Spawn",
	Callback = function()
		print("Teleport to Spawn")
	end,
})

Misc:AddSection("Settings")

Misc:AddButton({
	Name = "Reset Settings",
	Callback = function()
		print("Settings reset")
	end,
})

Misc:AddLabel("This script is loaded from: games/" .. game.PlaceId .. ".lua")
Misc:AddLabel("ArcticHub Library Version: " .. (ArcticHub.Version or "Unknown"))
