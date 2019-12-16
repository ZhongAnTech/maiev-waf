-- -*- coding: utf-8 -*-
-- 基于自定义规则过滤
local cfg = require('config')
--[[
local configs = cfg.configs
local rules = configs.rules
local filters = configs.filters
--]]
local log = require('log')
--local request_tester = require('request_tester')
local rule_engine = require('rule')
local actions = require('actions')

local _M = {}

--常量化魔法变量
local F_ON = 1
local F_OFF = -1
local F_LOG = 0
local ACCEPT = 'ACCEPT'
local DENY = 'DENY'
local DROP = 'DROP'
local REDIRECT = 'REDIRECT'
local REWRITE = 'REWRITE'
local RESPONSE_REPLACE = 'GSUB'

local function do_action(filter)
   local action = filter.action
   if actions.disruptive_lookup[action] then
      if action == REDIRECT and filter.action_vars and filter.action_vars.redirect_url then
         local redirect_url = filter.action_vars.redirect_url
         local rule_arg = 'aegis_rule_id=' .. filter.rule_id
         if string.find(redirect_url, '?') then
            redirect_url = redirect_url .. '&' .. rule_arg
         else
            redirect_url = redirect_url .. '?' .. rule_arg
         end
         print('-----redirect_url'..redirect_url)
         actions.disruptive_lookup[action](redirect_url)
      elseif action == RESPONSE_REPLACE then
         local pattern = filter.action_vars.pattern
         local new = filter.action_vars.new
         local pcre_flags = filter.action_vars.pcre_flags or 'ioj'
         print('reponse replace', ', pattern: ', pattern, ', new: ', new)
         actions.disruptive_lookup[action](pattern, new, pcre_flags)
      else
         actions.disruptive_lookup[action]()
      end
   else
      ngx.log(ngx.ERR, '---invalid action:'..tostring(action))
   end
end

local function _get_body_filters(host_cfg)
   local filters = {}
   local op = 'GET'
   if host_cfg and host_cfg.request_body_access == F_ON then
      local nofile_limit = host_cfg.request_body_nofile_limit
      print('request nofile limit: ', nofile_limit)
      filters[1] = {
         mode=1, action="MAX_BODY", rule_id="-2",
         rule={
            risk_level=3,
            attack_tag="Request Entity Nofile Too Big",
            desc="Request Entity Nofile Too Big",
            match={
               {
                  transforms={},
                  operator=op,
                  value=nofile_limit,
                  items={"BODY_NOFILE_SIZE"}
               }
            }
         }
      }
      if host_cfg.upload_file_access == F_ON then
         local body_limit = host_cfg.request_body_limit
         print('request full body limit: ', body_limit)
         filters[2] = {
            mode=1, action="MAX_BODY", rule_id="-3",
            rule={risk_level=3,
                  attack_tag="Request Entity Full Too Big",
                  desc="Request Entity Full Too Big",
                  match={
                     {
                        transforms={},
                        operator=op,
                        value=body_limit,
                        items={"UPLOAD_FILE_SIZE"}
                     }
            }}
         }
      end
   end
   return filters
end

local function filter(host_cfg, filter_phase)
   if filter_phase == 'body' then
      filters = host_cfg.body_filters
      print('=======filter body', ngx.ctx.response_body)
   elseif filter_phase == 'header' then
      filters = host_cfg.header_filters
   else
      filters = host_cfg.filters
      local body_filters = _get_body_filters(host_cfg)
      for idx, f in ipairs(body_filters) do
         table.insert(filters, idx, f)
      end
   end
   for _, filter in pairs(filters) do
      --filter设置3个状态是为了测试新加过滤器，生产环境调试规则会方便
      if filter and filter.mode >= F_LOG then
         local rule = filter.rule
         print('start match rule, id: ', filter.rule_id)
         --把rule id 放入ctx，后续创建ac_dicts需要
         ngx.ctx.rule_id = filter.rule_id
         local matcher = rule.match
         --ngx.log(ngx.ERR, 'rule'..cjson.encode(rule)..'match'..cjson.encode(matcher))
         if rule_engine.match(matcher) == true then
            --命中规则
            local log_only = true
            if host_cfg.waf_mode == cfg.WAF_ON and filter.mode == F_ON then
               log_only = false
            end
            print('----hit rule, log only is: ', log_only)
            log.log_attack(filter.rule_id, rule.desc, rule.attack_tag,
                           rule.risk_level, filter.action, log_only)
            if not log_only then
               do_action(filter)
            end
         end
      end

   end
end

_M.filter = filter
_M.body_filter = body_filter

return _M
