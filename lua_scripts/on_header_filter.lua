-- -*- coding: utf-8 -*-
local filter = require('filter')
local PHASE_HEADER = 'header'
_M = {}
local ctx = ngx.ctx
local host_cfg = ctx.host_cfg
local content_type = ngx.header["content-type"]

local function _modify_body(host_cfg)
   return host_cfg and host_cfg['response_body_access'] and content_type and host_cfg['response_body_mime_type']:find(content_type) and host_cfg['body_filters'] and ngx.header.content_length
end

--check body maybe modified
if _modify_body(host_cfg) then
   print('delete content-length in response header')
   ngx.header.content_length = nil
end

local function _header_filte(host_cfg)
   return host_cfg and host_cfg['header_filters']
end

if _header_filte(host_cfg) then
   print('header filtering')
   filter.filter(host_cfg, PHASE_HEADER)
else
   print('no header filters config')
end
