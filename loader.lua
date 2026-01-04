-- USAGE:
-- getgenv().Key = "TX-111"
-- loadstring(game:HttpGet("RAW_LOADER_URL"))()

local HttpService = game:GetService("HttpService")

-- ====== CONFIG RAW URL (SỬA CHỖ NÀY) ======
local CONFIG_URL = "https://raw.githubusercontent.com/phongdeptraur/key-system/refs/heads/main/src/config.lua"

-- ====== Load config ======
local Config = loadstring(game:HttpGet(CONFIG_URL))()

-- ====== File save/load key (optional) ======
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

-- ====== Cache ======
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

-- ====== Flow ======
local key = getKey()
if key == "" then
    warn("❌ Missing key. Set: getgenv().Key = \"YOUR_KEY\"")
    return
end

local ok, data = checkKey(key)
if not ok then
    warn("❌ KEY DENIED:", data and data.reason or "UNKNOWN")
    return
end

saveKey(key)
getgenv().License = data.info or {}

-- Load main
local mainSrc = game:HttpGet(Config.MAIN_RAW)
local f, err = loadstring(mainSrc)
if not f then
    warn("❌ Main compile error:", err)
    return
end
return f()
