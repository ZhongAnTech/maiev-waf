-- -*- coding: utf-8 -*-

local ip_cidr = require('ip_cidr')
local utils = require('utils')
local transform = require('transform')
local black_list = require('black_list')
local libinject = require('libinjection')
local cjson = require('cjson')
--local ac = require('ahocorasick')
local ac = require('load_ac')

local _M = {}
local _pcre_flags = 'ioj'

local function _starts_with(str, start)
   if type (start) == 'string' then
      return str:sub(1, #start) == start
   end
end

local function _ends_with(str, ending)
   if type (ending) == 'string' then
      return ending == "" or str:sub(-#ending) == ending
end
end

function _M.starts_with (i, r)
   local starts, value
   if type (i) == 'table' then
      for _, v in ipairs (i) do
         starts, value = _M.starts_with (v, r)
         if starts then
            break
         end
      end
   else
      if type(r) == 'table' then
         for _, v in ipairs (r) do
            starts = _starts_with(i, v)
            if starts then
               value = v
               break
            end
         end
      end
   end
   return starts, value
end

function _M.ends_with (i, r)
   local ends, value
   if type (i) == 'table' then
      for _, v in ipairs (i) do
         ends, value = _M.ends_with (v, r)
         if ends then
            break
         end
      end
   else
      if type(r) == 'table' then
         for _, v in ipairs (r) do
            ends = _ends_with(i, v)
            if ends then
               value = v
               break
            end
         end
      end
   end
   return ends, value
end


local _ac_dicts = {}
local function _get_ac_dict(dict_strs)
   local rule_id = ngx.ctx.rule_id
   if (not _ac_dicts[rule_id]) then
      _ac = ac.create_ac(dict_strs)
      _ac_dicts[rule_id] = _ac
   else
      _ac = _ac_dicts[rule_id]
   end
   return _ac
end

function _M.detect_sqli(input)
   if (type(input) == 'table') then
      for _, v in ipairs(input) do
         local match, value = _M.detect_sqli(v)

         if match then
            return true, value
         end
      end
   else
      -- yes this is really just one line
      -- libinjection.sqli has the same return values that lookup.operators expects
      if type(input) == 'string' then
         return libinject.sqli(tostring(input))
      else
         return false, nil
      end
   end

   return false, nil
end

function _M.detect_xss(input)
   if (type(input) == 'table') then
      for _, v in ipairs(input) do
         local match, value = _M.detect_xss(v)

         if match then
            return match, value
         end
      end
   else
      -- this function only returns a boolean value
      -- so we'll wrap the return values ourselves
      if type(input) == 'string' and (libinject.xss(input)) then
         return true, input
      else
         return false, nil
      end
   end

   return false, nil
end

-- i is input value, r is defined rule value, returned value means which value in i (case table)
function _M.equal(i, r)
   local eq, value
   if (type (i) == "table") then
      for _, v in ipairs (i) do
         eq, value = _M.equal (v, r)
         if eq then
            break
         end
      end
   else
      eq = i == r
      if eq then
         value = i
      end
   end
   return eq, value
end

function _M.not_equal(i, r)
   local result = _M.equal (i, r)
   return not result
end

function _M.greater_than(i, r)
   local gt, value
   if (type (i) == "table") then
      for _, v in ipairs (i) do
         gt, value = _M.greater_than (v, r)
         if gt then
            break
         end
      end
   else
      gt = i > r
      if gt then
         value = i
      end
   end
   return gt, value
end

function _M.less_than(i, r)
   local lt, value
   if (type (i) == "table") then
      for _, v in ipairs (i) do
         lt, value = _M.less_than (v, r)
         if lt then
            break
         end
      end
   else
      lt = i < r
      if lt then
         value = i
      end
   end
   return lt, value
end

function _M.greater_than_equal(i, r)
   local gte, value
   if (type (i) == "table") then
      for _, v in ipairs (i) do
         gte, value = _M.greater_than_equal (v, r)
         if gte then
            break
         end
      end
   else
      gte = i >= r
      if gte then
         value = i
      end
   end
   return gte, value
end

function _M.less_than_equal(i, r)
local lte, value
   if (type (i) == "table") then
      for _, v in ipairs (i) do
         lte, value = _M.less_than_equal (v, r)
         if lte then
            break
         end
      end
   else
      lte = i <= r
      if lte then
         value = i
      end
   end
   return lte, value
end

function _M.any()
   return true
end

function _M.not_any()
   return false
end

function _M.exists(i)
   local ex, value
   if type (i) == "table" then
      for _, v in ipairs (i) do
         ex, value = _M.exists (v)
         if ex then
            break
         end
      end
   else
      ex = i ~= nil
      if ex then
         value = i
      end
   end
   return ex, value
end

function _M.not_exists(i)
   local result = _M.exists (i)
   return not result
end
function _M.regex_wrap(i, r)
   -- rule value is base64 encode
   local rule_value = transform.lookup.base64_decode(r)
   return _M.regex(i, rule_value)
end

function _M.regex(i, r)
   local from, to, err, match
   if type(i) == "table" then
      for _, v in ipairs(i) do
         match, from = _M.regex(v, r)
         if match then
            break
         end
      end
   else
      from, to, err = ngx.re.find(i, r, _pcre_flags)
      if err then
         ngx.log(ngx.WARN, "error in ngx.re.find: " .. err)
      end

      if from then
         match = true
      end
   end

   return match, from
end

function _M.not_regex_wrap(i, r)
   return not _M.regex_wrap(i, r)
end

-- aho-corasick字符串多模匹配
function _M.contains(i, r)
   print('-----contains', ', input', i, ', rule value', r)
   local _ac = _get_ac_dict(r)
   return type(i) == 'string' and ac.match(_ac, i)
end

function _M.not_contains(i, r)
   return not _M.contains(i, r)
end

function _M.did_filter(i)
   return black_list.did_filter(i)
end

local _cidr_cache = {}
function _M.cidr(i, r)
   local t = {}
   local n = 1

   if (type(r) ~= "table") then
      r = { r }
   end

   for _, v in ipairs(r) do
      local cidr = _cidr_cache[v]
      -- if it wasn't there, compute and cache the value
      if (not cidr) then
         local lower, upper = ip_cidr.parse_cidr(v)
         cidr = { lower, upper }
         _cidr_cache[v] = cidr
      end

      t[n] = cidr
      n = n + 1
   end

   return ip_cidr.ip_in_cidrs(i, t), i
end


_M.lookup = {
   EQL = function (i, r) return _M.equal(i, r) end,
   NEQ = function (i, r) return _M.not_equal(i, r) end,
   GET = function (i, r) return _M.greater_than(i, r) end,
   GTE = function (i, r) return _M.greater_than_equal(i, r) end,
   LET = function (i, r) return _M.less_than(i, r) end,
   LTE = function (i, r) return _M.less_than_equal(i, r) end,
   REG = function (i, r) return _M.regex_wrap(i, r) end,
   NRE = function (i, r) return _M.not_regex_wrap(i, r) end,
   DID = function (i, r) return _M.did_filter(i) end,
   SQL = function (i, r) return _M.detect_sqli(i) end,
   XSS = function (i, r) return _M.detect_xss(i) end,
   ANY = function (i, r) return _M.any() end,
   NAN = function (i, r) return _M.not_any() end,
   EXT = function (i, r) return _M.exists(i) end,
   NEX = function (i, r) return _M.not_exists(i) end,
   STW = function (i, r) return _M.starts_with (i, r) end,
   EDW = function (i, r) return _M.ends_with (i, r) end,
   CDR = function (i, r) return _M.cidr (i, r) end,
   CTN = function (i, r) return _M.contains (i, r) end,
   NCT = function (i, r) return _M.not_contains (i, r) end,
}

return _M
