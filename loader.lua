local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

-- ====== CONFIG RAW URL (SỬA) ======
local CONFIG_URL = "https://raw.githubusercontent.com/phongdeptraur/key-system/main/src/config.lua"

-- ====== debug helper ======
local function dbg(...)
    warn("[LOADER]", ...)
end

-- ====== httpGet compatible ======
local function httpGet(url)
    -- 1) game:HttpGet
    if game and type(game.HttpGet) == "function" then
        local ok, res = pcall(function() return game:HttpGet(url) end)
        if ok and type(res) == "string" then return res end
    end

    -- 2) syn.request / http_request / request
    local req = (syn and syn.request) or http_request or request
    if type(req) == "function" then
        local ok, resp = pcall(function()
            return req({ Url = url, Method = "GET" })
        end)
        if ok and resp and (resp.Body or resp.body) then
            return resp.Body or resp.body
        end
    end

    return nil
end

-- ===== SAFE KICK =====
local function safeKick(reason)
    reason = tostring(reason or "Access denied")
    local lp = Players.LocalPlayer
    if not lp then
        Players.PlayerAdded:Wait()
        lp = Players.LocalPlayer
    end
    pcall(function()
        lp:Kick(reason)
    end)
end

-- ===== load config =====
local cfgSrc = httpGet(CONFIG_URL)
if not cfgSrc then
    dbg("Failed to fetch config:", CONFIG_URL)
    safeKick("Failed to load config")
    return
end

local cfgFn, cfgErr = loadstring(cfgSrc)
if not cfgFn then
    dbg("Config loadstring error:", cfgErr)
    safeKick("Config parse error")
    return
end

local Config = cfgFn()
if type(Config) ~= "table" then
    dbg("Config returned non-table")
    safeKick("Bad config")
    return
end

-- ===== key read/save =====
local KEY_FILE = "tx_key.txt"
local function canFile()
    return (type(isfile)=="function" and type(readfile)=="function" and type(writefile)=="function")
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

-- ===== cache =====
local cache = { key=nil, t=0, ok=false, data=nil }

local function checkKey(key)
    if cache.key == key and (os.time() - cache.t) <= (Config.CACHE_TTL_SEC or 60) then
        return cache.ok, cache.data
    end

    local api = tostring(Config.API or "")
    if api == "" then
        return false, { ok=false, reason="NO_API_IN_CONFIG" }
    end

    local url = api .. "?key=" .. HttpService:UrlEncode(key)
    local raw = httpGet(url)
    if not raw then
        return false, { ok=false, reason="API_HTTP_FAIL" }
    end

    local ok, data = pcall(function()
        return HttpService:JSONDecode(raw)
    end)
    if not ok then
        return false, { ok=false, reason="API_BAD_JSON", raw=raw }
    end

    local pass = (data.ok == true)
    cache = { key=key, t=os.time(), ok=pass, data=data }
    return pass, data
end

-- ===== FLOW =====
local key = getKey()
if key == "" then
    safeKick("Missing key. Set getgenv().Key = \"YOUR_KEY\"")
    return
end

local ok, data = checkKey(key)
if not ok then
    safeKick("KEY DENIED: " .. tostring(data and data.reason or "UNKNOWN"))
    return
end

saveKey(key)
getgenv().License = data.info or {}

local mainUrl = tostring(Config.MAIN_RAW or "")
if mainUrl == "" then
    safeKick("No MAIN_RAW in config")
    return
end

local mainSrc = httpGet(mainUrl)
if not mainSrc then
    dbg("Failed to fetch main:", mainUrl)
    safeKick("Failed to load main")
    return
end

local f, err = loadstring(mainSrc)
if not f then
    dbg("Main loadstring error:", err)
    safeKick("Main compile error")
    return
end

return f()
