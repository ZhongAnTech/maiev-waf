local actions = require('actions')
local log = require('log')
local cfg = require('config')

local cc_cache = ngx.shared.cc

local CC_ON = 1
local CC_LOG = 0
local CC_OFF = -1

local _M = {}

local function filter(host, host_cfg)
   local client_ip = ngx.var.remote_addr
   if client_ip then
      local key = host..client_ip..ngx.var.uri
      --print('-----cc key', key)
      if type(host_cfg.cc_max) == 'number' and
      type(host_cfg.cc_period) == 'number' then

         count = cc_cache:get(key)
         if count then
            if count >= host_cfg.cc_max then

               local log_only = true
               if host_cfg.waf_mode == cfg.WAF_ON and host_cfg.cc_mode == CC_ON then
                  log_only = false
               end
               log.log_attack(-1, 'cc attack', 'cc', 'unknow', 'DROP', log_only)
               if not log_only then
                  actions.disruptive_lookup.DROP()
               end
               return true
            else
               cc_cache:incr(key, 1)
            end
         else
            cc_cache:set(key, 1, host_cfg.cc_period)
         end
      end
   end
   return false
end

_M.filter = filter

return _M
