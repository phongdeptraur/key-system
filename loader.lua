--[[ 
USAGE:
getgenv().Key = "VIP-999"
loadstring(game:HttpGet("https://raw.githubusercontent.com/phongdeptraur/key-system/main/loader.lua"))()
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

-- ====== CONFIG RAW URL (SỬA CHO ĐÚNG REPO) ======
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
        if ok and resp then
            local body = resp.Body or resp.body
            if type(body) == "string" then return body end
        end
    end

    return nil
end

-- ===== SAFE KICK (không crash executor) =====
local function safeKick(reason)
    reason = tostring(reason or "Access denied")

    local lp = Players.LocalPlayer
    if not lp then
        -- đợi tối đa ~5s (không dùng :Wait() để tránh nil ở vài executor)
        for _ = 1, 50 do
            lp = Players.LocalPlayer
            if lp then break end
            if task and task.wait then task.wait(0.1) else wait(0.1) end
        end
    end

    if not lp then
        warn("[KICK] No LocalPlayer:", reason)
        return
    end

    if type(lp.Kick) == "function" then
        pcall(function() lp:Kick(reason) end)
        return
    end

    if type(lp.Destroy) == "function" then
        pcall(function() lp:Destroy() end)
        return
    end

    warn("[KICK] Cannot kick/destroy:", reason)
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

    -- fallback từ file (nếu có)
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

-- ===== normalize response (HỖ TRỢ ok/valid) =====
local function normalizeApiResponse(data)
    -- data có thể là:
    -- {valid=true, reason="ok"}  hoặc  {ok=true, reason="OK", info={...}}
    local pass = false
    local reason = "UNKNOWN"

    if type(data) == "table" then
        pass = (data.valid == true) or (data.ok == true)

        -- reason/message
        reason = data.reason or data.message or (pass and "ok" or "denied")
        reason = tostring(reason)

        -- nếu pass=true thì KHÔNG được kick, dù reason có là gì đi nữa
        -- (tránh case "valid:true nhưng reason bị set bậy")
        return pass, reason, data
    end

    return false, "BAD_RESPONSE", { raw = data }
end

-- ===== checkKey =====
local function checkKey(key)
    local ttl = tonumber(Config.CACHE_TTL_SEC) or 0
    if cache.key == key and ttl > 0 and (os.time() - cache.t) <= ttl then
        local pass, reason, raw = normalizeApiResponse(cache.data)
        return pass, { pass = pass, reason = reason, raw = raw }
    end

    local api = tostring(Config.API or "")
    if api == "" then
        return false, { pass=false, reason="NO_API_IN_CONFIG" }
    end

    local url = api .. "?key=" .. HttpService:UrlEncode(key)
    local rawText = httpGet(url)
    if not rawText then
        return false, { pass=false, reason="API_HTTP_FAIL" }
    end

    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(rawText)
    end)
    if not ok then
        return false, { pass=false, reason="API_BAD_JSON", rawText=rawText }
    end

    cache = { key=key, t=os.time(), ok=true, data=decoded }

    local pass, reason, raw = normalizeApiResponse(decoded)
    return pass, { pass = pass, reason = reason, raw = raw }
end

-- ===== FLOW =====
local key = getKey()
if key == "" then
    safeKick("Missing key. Set getgenv().Key = \"YOUR_KEY\"")
    return
end

local pass, result = checkKey(key)
if not pass then
    safeKick("KEY DENIED: " .. tostring(result and result.reason or "UNKNOWN"))
    return
end

-- Key OK
saveKey(key)

-- Lưu info nếu API có trả info
-- (với format {valid:true, reason:"ok"} thì info có thể không có)
getgenv().License = (result and result.raw and result.raw.info) or {}

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
