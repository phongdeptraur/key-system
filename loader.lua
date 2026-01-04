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

    -- lấy LocalPlayer an toàn (không dùng :Wait())
    local lp = Players.LocalPlayer
    if not lp then
        for _ = 1, 50 do -- đợi tối đa ~5s
            lp = Players.LocalPlayer
            if lp then break end
            if task and task.wait then task.wait(0.1) else wait(0.1) end
        end
    end

    -- nếu vẫn chưa có player thì thôi (tránh crash)
    if not lp then
        warn("[KICK] No LocalPlayer to kick:", reason)
        return
    end

    -- Kick nếu có, không thì fallback Destroy
    local kickFn = lp.Kick
    if type(kickFn) == "function" then
        pcall(function() lp:Kick(reason) end)
        return
    end

    local destroyFn = lp.Destroy
    if type(destroyFn) == "function" then
        pcall(function() lp:Destroy() end)
        return
    end

    warn("[KICK] Neither Kick nor Destroy available:", reason)
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

-- hỗ trợ nhiều format API: ok/valid + reason/message
local pass =
    (data.ok == true) or
    (data.valid == true)

-- chuẩn hoá reason để chỗ khác dùng
if pass then
    data.reason = data.reason or data.message or "OK"
else
    data.reason = data.reason or data.message or "DENIED"
end

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
    local reason = "UNKNOWN"

    if type(data) == "table" then
        -- ưu tiên reason từ API
        if type(data.reason) == "string" and data.reason ~= "" then
            reason = data.reason
        else
            -- fallback theo ok nếu API không gửi reason
            if data.ok == false then
                reason = "DENIED"
            elseif type(data.ok) == "string" and data.ok ~= "" then
                -- phòng trường hợp data.ok bị string "ok"/"false" (bậy bạ)
                reason = data.ok
            end
        end
    elseif type(data) == "string" and data ~= "" then
        reason = data
    end

    safeKick("KEY DENIED: " .. reason)
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
