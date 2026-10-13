--[[
	ArcticHub — loader

	This is only a gate: it carries no game code of its own, and it loads
	nothing but what it fetches from the repo URL.

	  1. fetch library.lua        (shared UI framework, used by every game)
	  2. prompt for a JNKIE key   (one-time)
	  3. after the key is valid: fetch games/<PlaceId>.lua from the URL and
	     run it
	  4. close

	Nothing is embedded and nothing is read from disk — the library and the
	per-game scripts are pulled from their URLs, and only after the key is
	accepted is the game script fetched and run.
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
-- 2. JNKIE key system (validator only; the key gates the window, which
--    gates loading the game script)
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
-- 3. window (its key prompt is the gate; nothing else happens until it
--    is satisfied)
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
-- 4. after the key: load the game script from the URL, run it, close
----------------------------------------------------------------------

-- The key prompt is a window; the window only opens after a valid key, so
-- this fires once, right after validation. Nothing game-specific was fetched
-- before now — the script comes straight from its repo URL.
local started = false
win:OnOpen(function()
	if started then return end
	started = true

	local body = get(GAME_URL)
	if not body then
		notify("This game is not supported yet.")
		return
	end

	local fn, err = loadstring(body)
	if not fn then
		notify("Could not load the game script: " .. tostring(err))
		return
	end

	local ok, e = pcall(fn, ArcticHub)
	if not ok then
		notify("Game script error: " .. tostring(e))
	end
	-- Loader's job is done: it only validated the key and handed the script
	-- over. The game script owns everything from here.
end)
