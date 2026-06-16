if not _G.__ArcticHubRunning then
    warn("[ArcticHub] Blocked: script was not launched via the loader")
    return
end

local savedKey = _G.__ArcticHubKey

if type(savedKey) ~= "string" or #savedKey == 0 then
    warn("[ArcticHub] Blocked: no valid key found in session")
    _G.__ArcticHubRunning = nil
    return
end

local httpReq =
    (typeof(request) == "function" and request)
    or (typeof(http_request) == "function" and http_request)
    or (typeof(httprequest) == "function" and httprequest)
    or (syn and typeof(syn.request) == "function" and syn.request)
    or (http and typeof(http.request) == "function" and http.request)
    or (fluxus and typeof(fluxus.request) == "function" and fluxus.request)

if not httpReq then
    warn("[ArcticHub] Blocked: no HTTP support for re-validation")
    _G.__ArcticHubRunning = nil
    return
end

local libOk, libRes = pcall(httpReq, {
    Url    = "https://secure.pandauth.com/cv4/lib",
    Method = "GET"
})

if not libOk or type(libRes) ~= "table" then
    warn("[ArcticHub] Blocked: auth library unreachable")
    _G.__ArcticHubRunning = nil
    return
end

local libBody = libRes.Body or libRes.body or ""
local libCode = libRes.StatusCode or libRes.statusCode or 0

if libCode < 200 or libCode >= 300 or #libBody < 100 then
    warn("[ArcticHub] Blocked: bad response from auth library")
    _G.__ArcticHubRunning = nil
    return
end

local Cookies
local fnOk, fnErr = pcall(function()
    Cookies = loadstring(libBody)()
end)

if not fnOk or type(Cookies) ~= "table" then
    warn("[ArcticHub] Blocked: auth library failed to init — " .. tostring(fnErr))
    _G.__ArcticHubRunning = nil
    return
end

local required = { "configure", "validate", "saveKey", "clearSavedKey" }
for _, fn in ipairs(required) do
    if type(Cookies[fn]) ~= "function" then
        warn("[ArcticHub] Blocked: auth library missing function: " .. fn)
        _G.__ArcticHubRunning = nil
        return
    end
end

pcall(Cookies.configure, {
    serviceId         = "arctichub",
    kickOnDetect      = false,
    openDashboard     = false,
    validationTimeout = 600,
})

local validOk, validResult = pcall(Cookies.validate, savedKey)

if not validOk then
    warn("[ArcticHub] Blocked: validation call threw an error")
    _G.__ArcticHubRunning = nil
    return
end

if type(validResult) ~= "table" then
    warn("[ArcticHub] Blocked: unexpected validation response type")
    _G.__ArcticHubRunning = nil
    return
end

if not validResult.success then
    warn("[ArcticHub] Blocked: key rejected by auth server — " .. tostring(validResult.error or "unknown"))
    _G.__ArcticHubRunning = nil
    _G.__ArcticHubKey = nil
    return
end

local isPremium = validResult.isPremium == true

print("[ArcticHub] Auth verified — loading game features")
print("[ArcticHub] Tier: " .. (isPremium and "Premium" or "Free"))

-- ============================================================
--  Load UI library for the game window
-- ============================================================

local uiSrc
local uiOk = pcall(function()
    uiSrc = game:HttpGetAsync(
        "https://raw.githubusercontent.com/ArcticHub0/ArcticHub/refs/heads/main/library.lua"
    )
end)

if not uiOk or not uiSrc then
    warn("[ArcticHub] Failed to fetch UI library")
    return
end

local UI
local loadOk = pcall(function()
    UI = loadstring(uiSrc)()
end)

if not loadOk or type(UI) ~= "table" then
    warn("[ArcticHub] UI library failed to init")
    return
end

local Notification = UI.Notification()

local function notify(t, d)
    pcall(function()
        Notification.new({
            Title       = t,
            Description = d,
            Duration    = 3.5,
            Icon        = "rbxassetid://8997385628"
        })
    end)
end

local Windows = UI.new({
    Title       = "ArcticHub",
    Description = "Baseplate",
    Keybind     = Enum.KeyCode.LeftAlt,
    Logo        = "http://www.roblox.com/asset/?id=100776375646681"
})

notify("Welcome", "ArcticHub loaded successfully")

local MainTab = Windows:NewTab({
    Title       = "Main",
    Description = "Features",
    Icon        = "rbxassetid://7733960981"
})

local Section = MainTab:NewSection({
    Title    = "Features",
    Icon     = "rbxassetid://7743869054",
    Position = "Left"
})

Section:NewToggle({
    Title    = "Auto Farm",
    Default  = false,
    Callback = function(v)
        print("Auto Farm:", v)
    end
})

Section:NewSlider({
    Title    = "WalkSpeed",
    Min      = 16,
    Max      = 100,
    Default  = 16,
    Callback = function(v)
        local char = game.Players.LocalPlayer.Character
        if char and char:FindFirstChild("Humanoid") then
            char.Humanoid.WalkSpeed = v
        end
    end
})

Section:NewSlider({
    Title    = "JumpPower",
    Min      = 50,
    Max      = 300,
    Default  = 50,
    Callback = function(v)
        local char = game.Players.LocalPlayer.Character
        if char and char:FindFirstChild("Humanoid") then
            char.Humanoid.JumpPower = v
        end
    end
})

-- premium-only section, shown but locked for free tier
local PremiumSection = MainTab:NewSection({
    Title    = isPremium and "Premium Features" or "Premium Features (Locked)",
    Icon     = "rbxassetid://7733964719",
    Position = "Left"
})

if isPremium then
    PremiumSection:NewToggle({
        Title    = "Fly",
        Default  = false,
        Callback = function(v)
            print("Fly:", v)
        end
    })

    PremiumSection:NewButton({
        Title    = "Teleport to 0,0,0",
        Callback = function()
            local char = game.Players.LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                char.HumanoidRootPart.CFrame = CFrame.new(0, 5, 0)
            end
        end
    })
else
    PremiumSection:NewTitle("Upgrade to Premium to unlock these features")
    PremiumSection:NewButton({
        Title    = "Get Premium",
        Callback = function()
            if setclipboard then
                pcall(setclipboard, "discord.gg/BH6pE7jesa")
                notify("Premium", "Discord link copied — ask for Premium in our server")
            end
        end
    })
end

local InfoSection = MainTab:NewSection({
    Title    = "Session",
    Icon     = "rbxassetid://7733964719",
    Position = "Right"
})

local player = game.Players.LocalPlayer
InfoSection:NewTitle((player and player.DisplayName or "Unknown") .. " (@" .. (player and player.Name or "Unknown") .. ")")
InfoSection:NewTitle("Tier: " .. (isPremium and "Premium" or "Free"))
InfoSection:NewTitle("Key: Verified")
InfoSection:NewTitle("─────────────────────")
InfoSection:NewTitle("CoreGuard: Active")

InfoSection:NewButton({
    Title    = "Discord",
    Icon     = "rbxassetid://7734053495",
    Callback = function()
        if setclipboard then
            pcall(setclipboard, "discord.gg/pFWmd65Wsf")
            notify("Discord", "Invite link copied to clipboard")
        end
    end
})
