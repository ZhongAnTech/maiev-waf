-- -*- coding: utf-8 -*-
local filter = require('filter')
local cjson = require('cjson')
local gzip = require('gzipd')
local PHASE_BODY = 'body'
local GZIP = 'gzip'
-- keep in mind, this module may be called multiple times in a request

local ctx = ngx.ctx
local host_cfg = ctx.host_cfg
local content_type = ngx.header.content_type
print('Content-Type: ', content_type)


local function _decompress(response_body)
   local content_encoding = ngx.header["Content-Encoding"]
   if content_encoding == GZIP then
      local success, data = pcall(gzip.decompress, gzip_data)
      if success then
         return data
      end
   end
   return response_body
end

local function _access_body(host_cfg)
   return host_cfg and host_cfg['response_body_access'] and host_cfg['response_body_mime_type']:find(content_type) and host_cfg['body_filters']
end

-- filter only when configed to access body
if _access_body(host_cfg) then
   print('start filter response body')
   local chunk, eof = ngx.arg[1], ngx.arg[2]
   local buf = ngx.ctx.response_body
   if eof then
      if buf then
         -- filter all buffered output, this should be execute once
         ngx.ctx.response_body = _decompress(buf .. chunk)
         print('=======', ngx.ctx.response_body)
         filter.filter(host_cfg, PHASE_BODY)
         ngx.arg[1] = ngx.ctx.response_body
         return
      end
      return
   end
   if buf then
      ngx.ctx.response_body = buf .. chunk
   else
      ngx.ctx.response_body = chunk
   end

   ngx.arg[1] = nil
end
