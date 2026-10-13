--[[
	ArcticHub — loader

	Shared resources live in the ArcticHub repo; this loader only pulls them
	together for the current game:

	  1. fetch library.lua        (UI framework, used by every game)
	  2. fetch games/<PlaceId>.lua (that game's script = supported-game gate)
	  3. prompt for a JNKIE key   (one-time)
	  4. run the per-game script once the key is accepted

	Both the library and the game scripts are published obfuscated, so they're
	distributed as-is and nothing here needs a copy of them.
]]

----------------------------------------------------------------------
-- endpoints
----------------------------------------------------------------------

local REPO = "https://raw.githubusercontent.com/ArcticHub0/ArcticHub/refs/heads/main/"
local LIB_URL = REPO .. "library.lua"
local GAME_URL = REPO .. "games/" .. game.PlaceId .. ".lua"

local httpReq = (syn and syn.request) or request or http_request

-- Roblox scripts get `request` / `syn.request` / `http_request`; fall back to
-- HttpGet. Returns the body, or nil (including 404s) so callers can gate.
local function get(url)
	if httpReq then
		local ok, res = pcall(httpReq, { Url = url, Method = "GET" })
		if ok and type(res) == "table" then
			local code = res.StatusCode
			if (code == nil or code == 200) and type(res.Body) == "string" and res.Body ~= "" then
				return res.Body
			end
			return nil
		end
	end
	local ok, body = pcall(function() return game:HttpGet(url, true) end)
	if ok and type(body) == "string" and body ~= "" and not string.find(string.lower(body), "404: not found") then
		return body
	end
	return nil
end

local function notify(text)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = "ArcticHub",
			Text = text,
			Duration = 5,
		})
	end)
end

----------------------------------------------------------------------
-- 1. shared library
----------------------------------------------------------------------

local libBody = get(LIB_URL)
local libChunk = libBody and loadstring(libBody)
if not libChunk then
	notify("Could not load the ArcticHub library.")
	return
end
local libOk, ArcticHub = pcall(libChunk)
if not libOk or not ArcticHub then
	notify("ArcticHub failed to start: " .. tostring(ArcticHub))
	return
end

-- Game scripts in the repo refer to the plain global `ArcticHub`; also hand it
-- in as the call argument below for scripts that prefer that.
_G.ArcticHub = ArcticHub
if getgenv then getgenv().ArcticHub = ArcticHub end

----------------------------------------------------------------------
-- 2. supported-game gate (before the key prompt)
----------------------------------------------------------------------

-- Fetch + compile the per-game script now so unsupported games fail before a
-- key is requested (a one-time key must not be burned on a 404).
local gameBody = get(GAME_URL)
if not gameBody then
	notify("This game is not supported yet.")
	return
end

local gameFn, gameErr = loadstring(gameBody)
if not gameFn then
	notify("Could not load the game script: " .. tostring(gameErr))
	return
end

----------------------------------------------------------------------
-- 3. JNKIE key system (validator only; the key gates the window, which
--    gates running the game script)
----------------------------------------------------------------------

-- These are per-account values from your jnkie.com dashboard:
--   service / identifier / provider
local Junkie
pcall(function()
	Junkie = loadstring(game:HttpGet("https://jnkie.com/sdk/library.lua"))()
	Junkie.service = 103774
	Junkie.identifier = "1216330"
	Junkie.provider = 27381
end)

local KEY_SYSTEM = {
	-- Validate against JNKIE; return false + a code the library maps to
	-- a friendly message ("KEY_EXPIRED", "ALREADY_USED", ...).
	Check = function(key)
		if not Junkie then return false, "CHECK_ERROR" end
		local ok, r = pcall(Junkie.check_key, key)
		if not ok then return false, "CHECK_ERROR" end
		if r and r.valid then return true end
		return false, (r and r.error) or "KEY_INVALID"
	end,
	-- One-time keys: never cache and never pre-approve from a saved file (a
	-- saved-key pre-check would consume the key's first use on its own).
	SaveKey = false,
	Once = true,
	-- "Get Key" fetches a fresh linkwall URL.
	Link = function()
		if not Junkie then return nil, "CHECK_ERROR" end
		local ok, url, err = pcall(Junkie.get_key_link)
		if ok then return url, err end
		return nil, "Could not reach the key service."
	end,
	Title = "Key Required",
	Note = "Validate your key with JNKIE to continue.",
	Placeholder = "Enter your key",
	Wrong = "That key is not valid.",
}

----------------------------------------------------------------------
-- 4. window (its key prompt is the gate)
----------------------------------------------------------------------

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

-- CreateWindow is a singleton: the per-game script adds its own tabs to this
-- same window, so the loader only builds the shell + key system.
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

----------------------------------------------------------------------
-- 5. run the game script after the key is accepted
----------------------------------------------------------------------

-- The key prompt is a window; the window only opens after a valid key, so
-- this fires once, right after validation.
local started = false
win:OnOpen(function()
	if started then return end
	started = true
	pcall(gameFn, ArcticHub)
end)
