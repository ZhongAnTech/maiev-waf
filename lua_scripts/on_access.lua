-- -*- coding: utf-8 -*-
local cfg = require('config')
local configs = cfg.configs
local PHASE_ACCESS = 'access'

if not configs then
   print('waf configs', tostring(configs))
   return
end

local host_cfg = nil
local host = ngx.var.host
if host then
   host_cfg = configs[host]
   if not host_cfg then
      print('host config', tostring(host_cfg))
      return ngx.exit(ngx.HTTP_FORBIDDEN)
   end
   ngx.ctx.host_cfg = host_cfg
else
   return ngx.exit(ngx.HTTP_FORBIDDEN)
end

local white_list = require('white_list')
local cc = require('cc')
local filter = require('filter')

if host_cfg.waf_mode == cfg.WAF_OFF then -- waf关闭，跳过,否则执行过滤
   print('----waf mode off')
elseif white_list.filter(host_cfg.white_list) then
   print('------come to white_list')
elseif host_cfg.cc_mode >= cfg.WAF_LOG and cc.filter(
   host, host_cfg) then
   print('------come to cc_deny')
elseif filter.filter(host_cfg, PHASE_ACCESS) then
   print('------come to filter')
else
   --print('------go ahead')
   return
end
