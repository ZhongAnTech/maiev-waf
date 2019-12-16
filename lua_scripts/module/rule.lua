-- -*- coding: utf-8 -*-
-- rule engine
local _M = {}
local ops = require('operators')
local request = require('request')
local utils = require('utils')
local transform = require('transform')
local cjson = require('cjson')

local function _get_items_value(items)
   local ls = {}
   for _, item in ipairs(items) do
      local lm = _M.lookup [item]
      if not lm then
         print ('invalid item: ', item)
         break
      end
      local result = lm()
      print ('get item: ', item, ', value: ', result)
      if type (result) == 'table' and #result > 0 then
         print('items input values: ', cjson.encode(result))
         ls[#ls+1] = result
      else
         ls [#ls+1] = result
      end
   end
   print('items values: ', cjson.encode(ls))
   return ls
end

local function _value_transform(value, t)
   if type(value) == 'table' and next(value) ~= nil then
      for k, v in ipairs(value) do
         for _, tr in ipairs(t) do
            print('value to be tranform: ', v)
            print('tranform: ', tr)
            value[k] = transform.lookup[tr](v)
            print('after tranform: ', v)
         end
      end
      return value
   else
      for _, tr in ipairs(t) do
            print('value to be tranform: ', value)
            print('tranform: ', tr)
            value = transform.lookup[tr](value)
            print('after tranform: ', value)
      end
      return value
   end
end
-- m, one in rule match list, ||
local function _match(m)
   op = m['operator']
   input = _get_items_value(m['items'])
   t = m['transforms']
   rule_value = m['value']
   print('input: ', cjson.encode(input), ', op: ', op, ', rule value: ', tostring(rule_value))
   for _, item in ipairs(input) do
      if t then
         print('start transform')
         item = _value_transform(item, t)
      end
      print('******item: ', item, ', op: ', op, ', rule value: ', tostring(rule_value))
      matched, value = ops.lookup[op](item, rule_value)
      print('match result: ', matched, ', matched value: ', value)
      if matched then
         return true
      end
   end
end

-- matcher, match list in rule, &&
function _M.match(matcher)
   if matcher == nil or type(matcher) ~= 'table' or next(matcher) == nil then
      return false
   end
   for _, m in ipairs(matcher) do
      if _match(m) ~= true then
         print('not match rule condition ', _)
         return false
      end
   end
   return true
end

_M.lookup = {
   ALL_ARGS = function() return utils.table_values(request.lookup.uri_args()) end,
   URI = function() return request.lookup.uri() end,
   ALL_ARGS_NAMES = function() return utils.table_keys(request.lookup.uri_args()) end,
   ALL_ARGS_COMBINED_SIZE = function() return request.lookup.uri_args_size() end,
   BODY_ARGS = function() return utils.table_values(request.lookup.body_args()) end,
   BODY_ARGS_NAMES = function() return utils.table_keys(request.lookup.body_args()) end,
   METHOD = function() return request.lookup.method() end,
   HOST = function() return request.lookup.host() end,
   UserAgent = function() return request.lookup.ua end,
   REFER = function() return request.lookup.refer end,
   IP = function() return request.lookup.ip() end,
   HEADERS = function() return utils.table_values(request.lookup.headers()) end,
   HEADERS_NAMES = function() return utils.table_keys(request.lookup.headers()) end,
   COOKIES = function() return utils.table_values(request.lookup.cookies()) end,
   COOKIES_NAMES = function() return utils.table_keys(request.lookup.cookies()) end,
   RESPONSE_STATUS = function () return ngx.var.status end,
   RESPONSE_BODY = function () return ngx.ctx.response_body end,
   -- 可通过加转换length来达到
   -- RESPONSE_BODY_LENGTH = function () return #ngx.ctx.response_body  end,
   RESPONSE_HEADERS = function () return utils.table_values(request.lookup.body_headers ()) end,
   RESPONSE_HEADERS_NAMES = function () return utils.table_keys(request.lookup.body_headers ()) end,
   -- request protocol, usually “HTTP/1.0”, “HTTP/1.1”, or “HTTP/2.0” 
   RESPONSE_PROTOCOL = function () return ngx.var.server_protocol end,
   UPLOAD_FILE_SIZE = function () return request.lookup.upload_file_size() end,
   UPLOAD_FILE_NAMES = function () return ngx.ctx.upload_file_names end,
   URI_ARGS_OF = function () return ngx.ctx.uri_args_truncated or 0 end,
   BODY_ARGS_OF = function () return ngx.ctx.body_args_truncated or 0 end,
   REQ_HEADERS_OF = function () return ngx.ctx.req_headers_truncated or 0 end,
   RESP_HEADERS_OF = function () return ngx.ctx.resp_headers_truncated or 0 end,
   BODY_NOFILE_SIZE = function () return request.lookup.body_nofile_size() end
}

return _M

