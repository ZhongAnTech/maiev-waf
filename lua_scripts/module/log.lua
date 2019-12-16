-- -*- coding: utf-8 -*-
-- 调用log_attack保存攻击类型和攻击日志信息

local cjson = require('cjson')
local cfg = require('config')
local configs = cfg.configs
local is_micro = cfg.is_micro
local utils = require('utils')
local logger = require "resty.logger.socket"


local kafka = require('kafka')
local ngx_topic = cfg.kafka_topics.ngx_topic
local ngx_key = 'ngx_access_log|ngx_access_log|all|day|%d'
local waf_topic = cfg.kafka_topics.waf_topic
local waf_key = 'waf_log|waf_log|all|day|%d'

local _M = {}
local function init_syslogger()
   if not logger.initted() then
      local ok, err = logger.init{
         host = cfg.syslog_host,
         port = cfg.syslog_port,
         sock_type = cfg.syslog_sock_type or "tcp",
         flush_limit = cfg.syslog_flush_limit or 1000,
         drop_limit = cfg.syslog_drop_limit or 2000
      }
      if not ok then
         ngx.log(ngx.ERR, "-----failed to initialize the logger: ",
                 err)
         return
      else
         print("logger init ok:", ok, ", error", err)
      end
   end

end

local log_type = cfg['log_type'] or 'syslog'
if cfg.log_type == 'syslog' then
   init_syslogger()
end

local function get_server_addr()
   local KEY = "server_addr"
   local cache_cfg = ngx.shared.cfg
   local server_addr = cache_cfg:get(KEY)
   if server_addr == nil then
      server_addr = ngx.var.server_addr
      if server_addr then
         cache_cfg:set(KEY, server_addr, 0)
      end
   end
   return server_addr
end

local function log_attack(id, desc, tag, risk_level, action, log_only)
   --保存本次请求的攻击log信息 rule_id, rule_desc, rule_attack_tag, rule_risk_level, action
   local attack_log = {
      rule_id = id,
      rule_desc = desc,
      attack_tag = tag,
      risk_level = risk_level,
      action = action,
      log_only = log_only
   }
   ngx.ctx.attack_log = attack_log
end



local function write_file(filename, msg)
   local fd = io.open(filename, "ab")
   if fd == nil then
      return
   end
   fd:write(msg)
   fd:flush()
   fd:close()
end

local function send_to_logserver()
   --输出到log server
   local http = require "resty.http"
   local client = http.new()

   local log_server_uri = 'http://10.156.247.0/receiver/sendSecurity'
   local timeout = 10 --请求log服务器超时时间

   client:set_timeout()
   client:request_uri(log_server_uri)

end

local function write_log(msg)
   local logs_dir = configs.logs_dir
   -- logs_dir一定要以'\'或'/'结尾，否则文件路径不对
   if logs_dir then
      local server = ngx.var.server_name
      local filename = logs_dir..server..'_'..ngx.today()..'_sec.log'
      write_file(filename, table.concat(msg, '  '))
   else
      ngx.log(ngx.ERR, '----no logs dir'..msg)
   end
end

local function log_attack_to_kafka(msg)
   local _key = waf_key:format(ngx.now())
   kafka.send(waf_topic, _key, cjson.encode(msg))
end

local function log_access_to_kafka(msg)
   local _key = ngx_key:format(ngx.now())
   kafka.send(ngx_topic, _key, cjson.encode(msg))
end

local function log_to_syslog(msg)
   -- construct the custom access log message in
   -- the Lua variable "msg"
   local msg = cjson.encode(msg)
   local bytes, err = logger.log(msg)
   if err then
      ngx.log(ngx.ERR, "-------failed to log message: ", err)
      return
   else
      print("logger log bytes:", bytes, ", error", err)
   end
end

local function _log_access(msg)
   if log_type == 'kafka' then
      log_access_to_kafka(msg)
   else
      log_to_syslog(msg)
   end
end

local function _log_attack(msg)
   if log_type == 'kafka' then
      log_attack_to_kafka(msg)
   else
      log_to_syslog(msg)
   end
end

local function do_log()
   local log_info = {
      status = tonumber(ngx.var.status),
      body_bytes_sent = tonumber(ngx.var.body_bytes_sent) or 0,
      scheme = ngx.var.scheme,
      http_user_agent = ngx.var.http_user_agent,
      request_length = tonumber(ngx.var.request_length) or 0,
      request_body = ngx.var.request_body,
      remote_addr = ngx.var.remote_addr,
      request_time = tonumber(ngx.var.request_time) or 0,
      host  = ngx.var.host,
      server_port  = ngx.var.server_port,
      clientIp = utils.get_client_ip(),
      request_uri = ngx.var.request_uri,
      time = ngx.localtime(),
      http_referer = ngx.var.http_referer,
      x_forwarded_for = ngx.var.http_x_forwarded_for,
      x_real_ip = ngx.var.http_x_real_ip,
      upstream_addr = ngx.var.upstream_addr,
      method = ngx.req.get_method(),
      server_addr = get_server_addr(),
      is_micro = is_micro,
      appName = ngx.var.host,
      nid = ngx.var.nid or '',
      user_id = ngx.var.user_id or '',
      source = 'ngxAccess'
   }
   -- log nginx access
   _log_access(log_info)

   -- if has an attack
   local attack_log = ngx.ctx.attack_log
   --log attack
   if type(attack_log) == 'table' then
      for k, v in pairs(attack_log) do
         log_info[k] = v
      end
      log_info['source'] = 'wafAttack'
      _log_attack(log_info)
   end
end

_M.write_file = write_file
_M.log_attack = log_attack
_M.do_log = do_log

return _M
