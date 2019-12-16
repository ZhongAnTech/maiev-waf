-- -*- coding: utf-8 -*-
local cjson = require 'cjson.safe' or require 'cjson'
local utils = require('utils')
local cfg_cache = ngx.shared.cfg

local _M = {}

if env == 'prod' then
   -- rule config.json path
   _M.cfg_backup_file = '/usr/local/oprensty/nginx/config.json'
   -- log type: syslog|kafka
   _M.log_type = 'syslog'
   _M.syslog_host = 'your_rsyslog_server_ip'
   _M.syslog_port = 514
   _M.syslog_sock_type = "udp"
   _M.kafka_broker_list = {
      {host = "your_kafka_broker_list", port=9092}
   }
   _M.kafka_topics = {
      ngx_topic = 'ngx-access-topic',
      waf_topic = 'waf-attack-topic'
   }
end

_M.configs = nil

local function is_valid_cfg(configs)
   local result = configs.code == 200 and configs.rules ~= nil and configs.version ~= nil and  configs.datas ~= nil
   print('waf cfg check ', tostring(result))
   return result
end

local function get_cfg_from_backup_file()
   local configs = utils.read_small_file(_M.cfg_backup_file)
   if configs then
      configs = cjson.decode(configs)
      if configs and is_valid_cfg(configs) then
         local hosts_config = {}
         for _, d in ipairs(configs.datas) do
            -- add rule detail in filters
            for _, f in ipairs(d.data.filters) do
               if configs.rules[f.rule_id] ~= nil then
                  f['rule'] = configs.rules[f.rule_id]
               else
                  ngx.log(ngx.ERR, 'invalid rule id in cfg:' .. f.rule_id)
                  print('invalid rule_id in filters:' .. cjson.encode(f))
                  return
               end
            end
            -- add rule detail in body filters
            for _, f in ipairs(d.data.body_filters) do
               if configs.rules[f.rule_id] ~= nil then
                  f['rule'] = configs.rules[f.rule_id]
               else
                  ngx.log(ngx.ERR, 'invalid rule id in cfg:' .. f.rule_id)
                  print('invalid rule_id in body filters:' .. cjson.encode(f))
                  return
               end
            end
            -- add rule detail in header filters
            for _, f in ipairs(d.data.header_filters) do
               if configs.rules[f.rule_id] ~= nil then
                  f['rule'] = configs.rules[f.rule_id]
               else
                  ngx.log(ngx.ERR, 'invalid rule id in cfg:' .. f.rule_id)
                  print('invalid rule_id in header filters:' .. cjson.encode(f))
                  return
               end
            end
            hosts_config[d.site_name] = d.data
         end
         return hosts_config
      end
   end
end

local function init()
   --cosocket disabled in init_by_lua, init_worker_by_lua
   --local configs, hash = get_cfg_from_console()
   --[[ nginx HUP指令并不会清空shared.dict
   if configs ~= nil then
      cfg:set('waf_configs', nil)
   end
   --]]
   local configs = get_cfg_from_backup_file()
   if configs then
      print('waf cfg is valid', cjson.encode(configs))
      _M.configs = configs
   else
      ngx.log(ngx.ERR, 'waf cfg is invalid')
   end
end

_M.init = init
_M.WAF_ON = 1
_M.WAF_LOG = 0
_M.WAF_OFF = -1

return _M
