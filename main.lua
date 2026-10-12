--[[
	ArcticHub — hub script

	A keyed hub built on the library in lib.lua: a supported-game gate, a JNKIE
	key system, and an arctic theme. Run this in a Roblox executor (or in Studio
	with an executor-style environment that provides loadstring).

	The library returns one table (D.API). Everything below hangs off it.
]]

----------------------------------------------------------------------
-- 1. Load the library
----------------------------------------------------------------------

-- Where the library lives. Point this at your own copy/branch if needed.
local LIB_URL = "https://raw.githubusercontent.com/ArcticHub0/ArcticHub/refs/heads/main/library.lua" -- host your own copy and update this

local function loadArcticHub()
	-- Prefer a local lib.lua next to the executor's working directory.
	if isfile and readfile and isfile("lib.lua") then
		local chunk = loadstring(readfile("lib.lua"))
		if chunk then
			local ok, result = pcall(chunk)
			if ok and result then return result end
		end
	end
	local body = game:HttpGet(LIB_URL)
	local chunk = assert(loadstring(body), "could not compile lib.lua")
	return chunk()
end

local ArcticHub = loadArcticHub()

----------------------------------------------------------------------
-- 2. Services and small helpers
----------------------------------------------------------------------

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Stats = game:GetService("Stats")
local UIS = game:GetService("UserInputService")

local LP = Players.LocalPlayer

local function humanoid()
	local char = LP.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function root()
	local h = humanoid()
	return h and h.RootPart
end

----------------------------------------------------------------------
-- 2b. Supported-game gate (runs before the key prompt)
----------------------------------------------------------------------

-- Only games listed on the ArcticHub repo are supported. The per-game script
-- (games/<placeid>.lua) is fetched here, BEFORE key validation; if it exists we
-- load it right away, and unsupported games get a notification and the hub exits.
local GAME_ID = game.PlaceId
local GAME_URL = "https://raw.githubusercontent.com/ArcticHub0/ArcticHub/refs/heads/main/games/" .. GAME_ID .. ".lua"

local httpReq = (syn and syn.request) or request or http_request
local gameScript

local function fetchGameScript()
	if httpReq then
		local ok, res = pcall(httpReq, {Url = GAME_URL, Method = "GET"})
		if ok and type(res) == "table" and res.StatusCode == 200 then
			local body = res.Body
			if type(body) == "string" and body ~= "" then
				gameScript = body
				return true
			end
		end
		return false
	end
	local ok, body = pcall(function() return game:HttpGet(GAME_URL, true) end)
	if ok and type(body) == "string" and body ~= "" and not string.find(string.lower(body), "404: not found") then
		gameScript = body
		return true
	end
	return false
end

if not fetchGameScript() then
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = "ArcticHub",
			Text = "This game is not supported yet.",
			Duration = 5,
		})
	end)
	return
end

-- Supported: compile the per-game script now so a bad script fails fast, but
-- only RUN it after the key check passes (handed off via win:OnOpen below).
local gameFn, gameErr = loadstring(gameScript)
if not gameFn then
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = "ArcticHub",
			Text = "Could not load the game script: " .. tostring(gameErr),
			Duration = 5,
		})
	end)
	return
end

----------------------------------------------------------------------
-- 3. Create the window
----------------------------------------------------------------------

-- Optional key system. The library has no key-system functions of its own; you
-- switch it on through CreateWindow, and it gates start() until a valid key is
-- entered. Fields (all optional):
--   Keys  = { "key1", "key2" }             simple allow-list, or
--   Check = function(key) return bool[, code] end   your own validation (takes priority)
--   Link        URL for a "Get Key" button, or function() -> link[, err]
--   Once        one-time keys: never cache / pre-check a saved key
--   Title       dialog title
--   Note        dialog body text
--   Placeholder input placeholder text
--   Wrong       message shown for a bad key
--   SaveKey     cache the key to <DIR>/key.txt (default true)
-- NOTE: this only gates D.start() (the window); the rest of your script still
-- runs, so gate your own features from a callback if you need them locked too.
-- Remove the `KeySystem = KEY_SYSTEM` line below to skip the prompt entirely.
-- JNKIE ("junkie") key validation. Load their public SDK once, then plug it in
-- as KeySystem.Check so every Continue press validates on their backend.
-- These are public-ish config values (not API tokens):
--   service    = Service name or id from your jnkie.com dashboard
--   identifier = your JNKIE account user id (NOT a Roblox/Discord id)
--   provider   = the provider used when minting new key links
local Junkie
pcall(function()
	Junkie = loadstring(game:HttpGet("https://jnkie.com/sdk/library.lua"))()
	Junkie.service = 103774
	Junkie.identifier = "1216330"
	Junkie.provider = 27381
end)

local KEY_SYSTEM = {
	-- Validate against JNKIE. Return true, or false + an error code the library
	-- maps to a friendly message ("KEY_EXPIRED", "ALREADY_USED", "http 429" ...).
	Check = function(key)
		if not Junkie then return false, "CHECK_ERROR" end
		local ok, r = pcall(Junkie.check_key, key)
		if not ok then return false, "CHECK_ERROR" end
		if r and r.valid then return true end
		return false, (r and r.error) or "KEY_INVALID"
	end,
	-- One-time keys: never cache a key and never pre-approve from a saved file
	-- (a saved-key pre-check would consume the key's first use on its own).
	SaveKey = false,
	Once = true,
	-- "Get Key" via JNKIE: fetch a fresh linkwall URL, copy it, and show it in
	-- the prompt (the library calls this function when the button is clicked).
	Link = function()
		if not Junkie then return nil, "CHECK_ERROR" end
		local ok, url, err = pcall(Junkie.get_key_link)
		if not ok then return nil, "Could not reach the key service." end
		return url, err
	end,
	Title = "Key Required",
	Note = "Validate your key with JNKIE to continue.",
	Placeholder = "Enter your key",
	Wrong = "That key is not valid.",
}

-- ArcticHub's own ice-blue theme. Registered per hub, not a library default.
ArcticHub:AddTheme("Arctic", {
	Background = "0E1524",
	Panel = "131C2E",
	Card = "192742",
	Field = "213452",
	Hover = "2A3F63",
	Popup = "10182A",
	Text = "EDF5FC",
	Label = "CBDDF1",
	Subtext = "8FA8C6",
	Dim = "5F7490",
	Off = "2B3D5A",
	Knob = "7C94B0",
	Accent = "5ED3FF",
})

-- CreateWindow is a singleton: calling it again returns the same window.
local win = ArcticHub:CreateWindow({
	Title = "ArcticHub",
	Theme = "Arctic",
	Size = Vector2.new(640, 470),
	Resizable = true,
	Search = true,
	Watermark = true,
	MenuKey = "RightShift",
	OpenOnLoad = true,
	KeySystem = KEY_SYSTEM,
})

-- win.Flags reads current values; win:SetFlag / win.Flags.x = v writes them.
-- You can also reach the same table directly through ArcticHub.Flags.

-- The library's built-in flags (ui_theme, ui_menukey, ...) are seeded when
-- start() runs, just after this script finishes. Read your own flags freely
-- here, but treat built-ins as "not ready yet" until the callbacks fire.
local MENU_KEY = "RightShift"

-- Roblox's built-in UI font families. ArcticHub:AddFont can register your own.
local AH_FONTS = {
	"BuilderSans", "GothamSSm", "Montserrat", "Arimo", "Roboto",
	"Ubuntu", "Nunito", "Oswald", "TitilliumWeb", "Michroma",
}

----------------------------------------------------------------------
-- 4. Main tab — a few working character features
----------------------------------------------------------------------

local main = win:Tab({ Name = "Main", Icon = "house" })
local character = main:Section("Character")

-- Infinite jump: a keybind listener plus a flag read.
ArcticHub:Connect(UIS.JumpRequest, function()
	if win.Flags.ah_infjump and humanoid() then
		humanoid():ChangeState(Enum.HumanoidStateType.Jumping)
	end
end)

character:Toggle({
	Flag = "ah_infjump",
	Name = "Infinite Jump",
	Description = "Jump again while in the air.",
	Icon = "arrow-up",
	Callback = function(on)
		ArcticHub:Notify({ Title = "Infinite Jump", Content = on and "Enabled." or "Disabled.", Duration = 2 })
	end,
})

-- Walk speed slider. Reapplies after respawn and restores on eject.
local BASE_SPEED = 16

ArcticHub:Connect(LP.CharacterAdded, function()
	task.wait(0.5)
	local h = humanoid()
	if h then h.WalkSpeed = win.Flags.ah_speed or BASE_SPEED end
end)

ArcticHub:OnEject(function()
	local h = humanoid()
	if h then h.WalkSpeed = BASE_SPEED end
end)

character:Slider({
	Flag = "ah_speed",
	Name = "Walk Speed",
	Icon = "gauge",
	Min = 8, Max = 200, Step = 1, Default = BASE_SPEED,
	Callback = function(v)
		local h = humanoid()
		if h then h.WalkSpeed = v end
	end,
})

-- Jump power slider.
character:Slider({
	Flag = "ah_jump",
	Name = "Jump Power",
	Min = 50, Max = 300, Step = 5, Default = 50,
	Callback = function(v)
		local h = humanoid()
		if h then
			h.UseJumpPower = true
			h.JumpPower = v
		end
	end,
})

-- A toggle with its own keybind. Mode "Toggle" gives the callback a boolean.
character:Keybind({
	Flag = "ah_flykey",
	Name = "Fly",
	Default = "F",
	Mode = "Toggle",
	Callback = function(state)
		ArcticHub:Notify({ Title = "Fly", Content = state and "On." or "Off.", Duration = 1.5 })
	end,
})

character:Segmented({
	Flag = "ah_boost",
	Name = "Boost",
	Values = { "Walk", "Run", "Sprint" },
	Default = "Walk",
	Callback = function(mode)
		local map = { Walk = BASE_SPEED, Run = 32, Sprint = 64 }
		local h = humanoid()
		if h and map[mode] then h.WalkSpeed = map[mode] end
	end,
})

local move = main:Section("Movement")

-- Dropdown auto-filled with the players in the server.
move:Dropdown({
	Flag = "ah_target",
	Name = "Target",
	Special = "Players",
	Placeholder = "Pick a player",
	Search = true,
})

move:Button({
	Name = "Teleport",
	Icon = "locate-fixed",
	Callback = function()
		local name = win.Flags.ah_target
		local target = name ~= "" and Players:FindFirstChild(name) or nil
		local myRoot = root()
		local theirRoot = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
		if myRoot and theirRoot then
			myRoot.CFrame = theirRoot.CFrame + Vector3.new(0, 3, 0)
			ArcticHub:Notify({ Title = "Teleport", Content = "Moved to " .. name .. ".", Duration = 2 })
		else
			ArcticHub:Notify({ Kind = "Error", Title = "Teleport", Content = "Nothing to teleport to.", Duration = 3 })
		end
	end,
})

move:Buttons({
	{
		Name = "Copy Position",
		Callback = function()
			local r = root()
			if not r then return end
			local p = r.Position
			local text = string.format("%.1f, %.1f, %.1f", p.X, p.Y, p.Z)
			if setclipboard then setclipboard(text) end
			ArcticHub:Notify({ Title = "Copied", Content = text, Duration = 2 })
		end,
	},
	{
		Name = "Respawn",
		Description = "Resets your character.",
		Callback = function()
			local h = humanoid()
			if h then h.Health = 0 end
		end,
	},
})

-- Live stats.
local fpsRow = move:Info({ Name = "FPS", Value = "0" })
local pingRow = move:Info({ Name = "Ping", Value = "0 ms" })

local frameCount, lastClock = 0, os.clock()
local lastFps = 0

ArcticHub:Connect(RunService.RenderStepped, function()
	frameCount += 1
end)

ArcticHub:Loop(function()
	local now = os.clock()
	local span = math.max(now - lastClock, 0.001)
	lastFps = math.floor(frameCount / span + 0.5)
	fpsRow:Set(lastFps)
	frameCount, lastClock = 0, now

	local ok, ping = pcall(function()
		return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
	end)
	pingRow:Set((ok and ping or 0) .. " ms")
end, 1)

----------------------------------------------------------------------
-- 5. Visuals tab — world tweaks and player highlights
----------------------------------------------------------------------

local visuals = win:Tab({ Name = "Visuals", Icon = "eye" })
local lightingSection = visuals:Section("Lighting")

-- Patch remembers the original value and restores it on eject.
local function applyLighting()
	if not win.Flags.ah_fullbright then
		ArcticHub:Restore(Lighting)
		return
	end
	ArcticHub:Patch(Lighting, "Brightness", win.Flags.ah_brightness)
	ArcticHub:Patch(Lighting, "Ambient", (ArcticHub:GetElement("ah_ambient"):GetColor()))
	ArcticHub:Patch(Lighting, "OutdoorAmbient", (ArcticHub:GetElement("ah_ambient"):GetColor()))
end

lightingSection:Toggle({
	Flag = "ah_fullbright",
	Name = "Full Bright",
	Icon = "sun",
	Callback = applyLighting,
})

lightingSection:Slider({
	Flag = "ah_brightness",
	Name = "Brightness",
	Min = 0, Max = 10, Step = 0.1, Default = 2,
	Callback = function()
		if win.Flags.ah_fullbright then applyLighting() end
	end,
})

lightingSection:ColorPicker({
	Flag = "ah_ambient",
	Name = "Ambient",
	Default = Color3.fromRGB(150, 150, 150),
	Callback = function()
		if win.Flags.ah_fullbright then applyLighting() end
	end,
})

-- Player highlight (ESP). Builds one Highlight per player and cleans up on eject.
local highlights = {}

local function refreshEsp()
	local on = win.Flags.ah_esp
	local colorEl = ArcticHub:GetElement("ah_esp_color")
	local color = (colorEl and colorEl:GetColor()) or Color3.fromRGB(255, 90, 90)
	local style = win.Flags.ah_esp_style
	local ignoreTeam = win.Flags.ah_esp_team

	for _, p in ipairs(Players:GetPlayers()) do
		local skip = p == LP or (ignoreTeam and p.Team and p.Team == LP.Team)
		local char = p.Character
		local hl = highlights[p]

		if on and not skip and char then
			if not hl or hl.Parent ~= char then
				if hl then hl:Destroy() end
				hl = Instance.new("Highlight")
				hl.Name = "ArcticHub_esp"
				hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				hl.Parent = char
				highlights[p] = hl
			end
			hl.FillColor = color
			hl.FillTransparency = style == "Outline" and 1 or 0.6
			hl.OutlineColor = color
			hl.OutlineTransparency = style == "Fill" and 1 or 0
			hl.Enabled = true
		elseif hl then
			hl:Destroy()
			highlights[p] = nil
		end
	end
end

ArcticHub:OnEject(function()
	for _, hl in pairs(highlights) do
		pcall(function() hl:Destroy() end)
	end
	table.clear(highlights)
end)

local esp = visuals:Section("Player Highlights")
esp:Toggle({ Flag = "ah_esp", Name = "Enable", Icon = "scan" })
esp:ColorPicker({ Flag = "ah_esp_color", Name = "Color", Default = Color3.fromRGB(255, 90, 90) })
esp:Segmented({ Flag = "ah_esp_style", Name = "Fill", Values = { "Outline", "Fill", "Both" }, Default = "Outline" })
esp:Toggle({ Flag = "ah_esp_team", Name = "Ignore Teammates", Default = true })

-- Start once the flags above exist.
ArcticHub:Loop(refreshEsp, 0.5)

-- Image element; the library resolves "headshot:<userId>" without extra assets.
local preview = visuals:Section("Preview")
preview:Image({
	Flag = "ah_avatar",
	Name = "Your avatar",
	Height = 140,
	Fit = "Crop",
	Source = "headshot:" .. LP.UserId,
})

----------------------------------------------------------------------
-- 6. Interface tab — look, feel, custom rows
----------------------------------------------------------------------

local iface = win:Tab({ Name = "Interface", Icon = "sliders-horizontal" })
local look = iface:Section("Appearance")

look:Dropdown({
	Flag = "ah_theme",
	Name = "Theme",
	Values = ArcticHub.Themes,
	Default = "Arctic",
	Callback = function(v) win:SetTheme(v) end,
})

look:Dropdown({
	Flag = "ah_font",
	Name = "Font",
	Values = AH_FONTS,
	Default = "BuilderSans",
	Callback = function(v) win:SetFont(v) end,
})

look:Slider({
	Flag = "ah_scale",
	Name = "Scale",
	Min = 70, Max = 130, Step = 5, Default = 100, Suffix = "%",
	Callback = function(v) win:SetScale(v) end,
})

look:ColorPicker({
	Flag = "ah_accent",
	Name = "Accent",
	Default = Color3.fromHex("5ED3FF"),
	Callback = function(c) win:SetAccent(c) end,
})

look:Toggle({
	Flag = "ah_wm",
	Name = "Watermark",
	Default = true,
	Callback = function(on) ArcticHub:SetWatermark({ Visible = on }) end,
})

-- Custom row: you get a holder plus a small drawing API. Everything you add
-- through api.Connect/api.Cleanup is torn down with the window.
local extras = iface:Section("Extras")
extras:Custom({
	Name = "Share",
	Height = 34,
	Build = function(holder, api)
		local b = api.Button({
			Text = "Copy share code",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = api.Theme.field,
			TextColor3 = api.Theme.text,
			TextSize = 13,
			FontFace = api.Font("semi"),
			Parent = holder,
		})
		api.Corner(b, api.Metrics.rField)
		api.Connect(b.MouseButton1Click, function()
			api.Play("click")
			local code = ArcticHub.Config:Export()
			if setclipboard then setclipboard(code) end
			ArcticHub:Notify({ Title = "Copied", Content = "Config share code copied.", Duration = 2 })
		end)
	end,
})

extras:Divider("Activity")
local log = extras:Console({ Name = "Log", Height = 150, Empty = "Nothing logged yet." })
log:Log("ArcticHub loaded.")

----------------------------------------------------------------------
-- 7. Configs tab
----------------------------------------------------------------------

local configs = win:Tab({ Name = "Configs", Icon = "save" })
local cfg = configs:Section("Saved configs")

local nameInput = cfg:Input({
	Flag = "ah_cfgname",
	Name = "Name",
	Placeholder = "my config",
})
-- nameInput is only used for its flag; grab the value with win.Flags.ah_cfgname.

cfg:Button({
	Name = "Save",
	Icon = "save",
	Callback = function()
		local name = win.Flags.ah_cfgname
		if name == "" then name = "default" end
		if ArcticHub.Config:Save(name) then
			ArcticHub:Notify({ Title = "Saved", Content = name, Duration = 2 })
			log:Success("Saved config " .. name)
		else
			ArcticHub:Notify({ Kind = "Error", Title = "Save failed", Content = "The executor may have no filesystem.", Duration = 3 })
			log:Error("Save failed for " .. name)
		end
	end,
})

cfg:Button({
	Name = "Load",
	Icon = "folder-open",
	Callback = function()
		local name = win.Flags.ah_cfgname
		if name ~= "" and ArcticHub.Config:Load(name) then
			ArcticHub:Notify({ Title = "Loaded", Content = name, Duration = 2 })
		else
			ArcticHub:Notify({ Kind = "Error", Title = "Load failed", Content = "No config named " .. name, Duration = 3 })
		end
	end,
})

local savedList = cfg:Dropdown({
	Flag = "ah_saved",
	Name = "Saved",
	Values = function() return ArcticHub.Config:List() end,
})

cfg:Button({
	Name = "Refresh list",
	Icon = "refresh-cw",
	Callback = function()
		savedList:SetValues(ArcticHub.Config:List(), false)
	end,
})

cfg:Button({
	Name = "Export to clipboard",
	Icon = "clipboard",
	Callback = function()
		local code = ArcticHub.Config:Export()
		if setclipboard then setclipboard(code) end
		ArcticHub:Notify({ Title = "Exported", Content = "Share code copied.", Duration = 2 })
	end,
})

cfg:Button({
	Name = "Import from clipboard",
	Icon = "file-text",
	Callback = function()
		local code = ""
		if getclipboard then code = getclipboard() end
		ArcticHub:Prompt({
			Title = "Import config",
			Placeholder = "AH1:...",
			Default = code,
			Callback = function(v)
				if ArcticHub.Config:Import(v) then
					ArcticHub:Notify({ Title = "Imported", Content = "Config applied.", Duration = 2 })
				else
					ArcticHub:Notify({ Kind = "Error", Title = "Import failed", Content = "That code did not parse.", Duration = 3 })
				end
			end,
		})
	end,
})

cfg:Spacer(6)
cfg:Button({
	Name = "Reset everything",
	Danger = true,
	Confirm = true,
	Callback = function()
		ArcticHub.Config:ResetAll()
		ArcticHub:Notify({ Title = "Reset", Content = "All flags are back to defaults.", Duration = 2 })
	end,
})

----------------------------------------------------------------------
-- 8. Overlays: a draggable widget plus a watermark part
----------------------------------------------------------------------

local startClock = os.clock()

local widget = ArcticHub:Widget({
	Name = "ArcticHub",
	Icon = "activity",
	Position = Vector2.new(16, 340),
	Empty = "No data",
	Rows = {
		{ "Uptime", "0s" },
	},
})

ArcticHub:Loop(function()
	widget:SetRow("Uptime", string.format("%.0fs", os.clock() - startClock))
end, 1)

ArcticHub:AddWatermarkPart("ah_fps", {
	Icon = "gauge",
	Get = function() return "FPS " .. lastFps end,
})

----------------------------------------------------------------------
-- 9. Window events and first-run notices
----------------------------------------------------------------------

win:OnOpen(function()
	-- fires whenever the menu is shown
end)

win:OnClose(function()
	-- fires whenever the menu is hidden
end)

-- Run the compiled per-game script once the key check passes: the menu first
-- opens only after a valid key, so this runs exactly after validation.
local gameLoaded = false
win:OnOpen(function()
	if gameLoaded or not gameFn then return end
	gameLoaded = true
	pcall(gameFn, ArcticHub)
end)

-- A dialog and a prompt, just to show they exist.
cfg:Button({
	Name = "About",
	Icon = "info",
	Callback = function()
		win:Dialog({
			Title = "ArcticHub",
			Content = "Arctic theme, JNKIE key check and a per-game loader. Press " .. MENU_KEY .. " to toggle the menu.",
			Icon = "sparkles",
			Buttons = {
				{ Name = "Close" },
			},
		})
	end,
})

log:Success("ArcticHub ready.")
