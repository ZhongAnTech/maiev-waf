-- -*- coding: utf-8 -*-
-- kafka client
local config = require('config')
local cjson= require('cjson')
local producer = require('resty.kafka.producer')
local broker_list = config.kafka_broker_list

local _M = {}

local function init()
   --[[
   local client = require('resty.kafka.client')
   local topic = 'tst_security_waf_attack_log'
   local cli = client:new(broker_list)
   local brokers, partitions = cli:fetch_metadata(topic)
   if not brokers then
      ngx.log(ngx.ERR, 'fetch_metadata failed, err:'..partitions)
   end
   --]]
   -- this is async producer_type and bp will be reused in the whole nginx worker
   local bp = producer:new(broker_list, { producer_type = "async" })
   if bp == nil then
      ngx.log(ngx.ERR, '------new producer error---')
      return
   end
   _M.bp = bp
end

local function test()
   local bp = _M.bp
   local topic = 'tst_security_waf_attack_log'
   local ok, err = bp:send(topick, "test", "hello")
   if not ok then
      ngx.log(ngx.ERR, "send err:"..err)
      return
   end
   ngx.say('test successful')
end

local function send(topic, key, msg)
   --[[
   if bp == nil then
      ngx.log(ngx.ERR, 'no producer avail.')
      return
   end
   --]]
   local bp = _M.bp
   if bp then
      local ok, err = bp:send(topic, key, msg)
      if not ok then
         ngx.log(ngx.ERR, "send kafka topic: "..topic.." err: "..err)
         return
      end
   else
      ngx.log(ngx.ERR, "get producer error")
   end
end


_M.init = init
_M.test = test
_M.send = send

return _M
