-- USAGE:
-- getgenv().Key = "TX-111"
-- loadstring(game:HttpGet("RAW_LOADER_URL"))()

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

-- ===== SAFE KICK =====
local Players = game:GetService("Players")

local function safeKick(reason)
    reason = tostring(reason or "Access denied")

    local lp = Players.LocalPlayer
    if not lp then
        Players.PlayerAdded:Wait()
        lp = Players.LocalPlayer
    end

    -- tương thích executor: ưu tiên task.delay, không có thì dùng delay/spawn
    local function later(sec, fn)
        if task and task.delay then
            task.delay(sec, fn)
        elseif delay then
            delay(sec, fn)
        else
            spawn(fn)
        end
    end

    later(0.5, function()
        pcall(function()
            lp:Kick(reason)
        end)
    end)
end


-- ===== CONFIG =====
local CONFIG_URL = "https://raw.githubusercontent.com/USER/REPO/main/src/config.lua"
local Config = loadstring(game:HttpGet(CONFIG_URL))()

-- ===== FILE KEY SAVE =====
local KEY_FILE = "tx_key.txt"

local function canFile()
    return (type(isfile) == "function" and type(readfile) == "function" and type(writefile) == "function")
end

local function trim(s)
    s = tostring(s or "")
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function getKey()
    local k = trim(getgenv().Key)
    if k ~= "" then return k end

    if canFile() and isfile(KEY_FILE) then
        local saved = trim(readfile(KEY_FILE))
        if saved ~= "" then
            getgenv().Key = saved
            return saved
        end
    end
    return ""
end

local function saveKey(k)
    if canFile() then pcall(function() writefile(KEY_FILE, k) end) end
end

-- ===== CACHE =====
local cache = { key=nil, t=0, data=nil, ok=false }

local function checkKey(key)
    if cache.key == key and (os.time() - cache.t) <= (Config.CACHE_TTL_SEC or 60) then
        return cache.ok, cache.data
    end

    local url = Config.API .. "?key=" .. HttpService:UrlEncode(key)
    local raw = game:HttpGet(url)
    local data = HttpService:JSONDecode(raw)

    local ok = (data.ok == true)
    cache = { key=key, t=os.time(), data=data, ok=ok }
    return ok, data
end

-- ===== FLOW =====
local key = getKey()
if key == "" then
    safeKick("❌ Missing key\nUse: getgenv().Key = \"YOUR_KEY\"")
    return
end

local ok, data = checkKey(key)
if not ok then
    local reason = (data and data.reason) or "UNKNOWN"
    safeKick("❌ KEY DENIED: " .. reason)
    return
end

-- ===== OK =====
saveKey(key)
getgenv().License = data.info or {}

local mainSrc = game:HttpGet(Config.MAIN_RAW)
local f, err = loadstring(mainSrc)
if not f then
    safeKick("❌ Main script error")
    return
end

return f()
