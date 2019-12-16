local zlib = require "zlib.zlib"
local ffi  = require "ffi"

local _M = {}

local function reader(s)
    local done
    return function()
        if done then return end
        done = true
        return s
    end
end

local function writer()
    local t = {}
    return function(data, sz)
        if not data then return table.concat(t) end
        t[#t + 1] = ffi.string(data, sz)
    end
end

function _M.decompress(gzip_data)
   --ngx.log(ngx.ERR, '----raw', gzip_data)
   local write = writer()
   local format = 'gzip'
   zlib.inflate(reader(gzip_data), write, nil, format)
   return write()
end

return _M
