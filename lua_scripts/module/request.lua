-- -*- coding: utf-8 -*-
local upload = require "resty.upload"
local _M = {}
local utils = require('utils')
local cookie = require "cookie"
local ACCESS_ON = 1
local _pcre_flags = 'ioj'
local _truncated = 1

local function _parse_uri_args()
   local args, err = ngx.req.get_uri_args()
   if err == "truncated" then
      -- one can choose to ignore or reject the current request here
      ngx.log(ngx.CRIT, 'exceeds MAXIMUM 100 uri args')
      ngx.ctx.uri_args_truncated = _truncated
   end
   return args
end

local function _parse_body_args()
   local body_access = ngx.ctx.host_cfg.request_body_access
   if body_access ~= ACCESS_ON then
      return
   end
   local _body = ngx.ctx.request_body
   if _body then
      return _body
   end
   ngx.log(ngx.CRIT, 'should exec *** ONCE *** per request')
   ngx.req.read_body()
   local args, err = ngx.req.get_post_args()
   if err == "truncated" then
      -- one can choose to ignore or reject the current request here
      ngx.log(ngx.CRIT, 'exceeds MAXIMUM 100 body args')
      ngx.ctx.body_args_truncated = _truncated
   end
   if not args then
      print("failed to get request body: ", err)
      return
   end
   ngx.ctx.request_body = args
   return args
end

local function _parse_cookies()
   local cookie_obj, err = cookie:new()
   return cookie_obj:get_all() or {}
end
local function _parse_headers()
   --local headers, err = ngx.req.get_headers(0)
   local headers, err = ngx.req.get_headers()
   if err == "truncated" then
      -- one can choose to ignore or reject the current request here
      ngx.log(ngx.CRIT, 'exceeds MAXIMUM 100 headers')
      ngx.ctx.req_headers_truncated = _truncated
   end
   if not headers then
      print("failed to get request headers: ", err)
      return
   end
   return headers
end

local function _get_nofile_size()
   local _body = ngx.ctx.request_body_size
   if _body then
      return _body
   end
   local content_type = ngx.req.get_headers()["content-type"]
   if not content_type or not ngx.re.find(content_type, [=[^application/x-www-form-urlencoded]=], _pcre_flags) then
      return
   end
   ngx.req.read_body()
   local body = ngx.req.get_body_data()
   if body then
      _body = #body
      ngx.ctx.request_body_size = _body
      print('get request nofile size: ', _body, ', body: ', body)
      return _body
   end
end

local function _parse_upload_file()
   local upload_file_access = ngx.ctx.host_cfg.upload_file_access
   local upload_file_limit = ngx.ctx.host_cfg.request_body_limit
   if upload_file_access ~= ACCESS_ON then
      return
   end
   local content_type = ngx.req.get_headers()["content-type"]
   print('upload file content type: ', content_type)
   if not content_type or not ngx.re.find(content_type, [=[^multipart/form-data; boundary=]=], _pcre_flags) then
      return
   end
   local chunk_size = 4096 -- should be set to 4096 or 8192 for real-world settings
   local file_size = 0
   local form, err = upload:new(chunk_size)
   if not form then
      ngx.log(ngx.ERR, "failed to new upload: ", err)
      return
   end
   form:set_timeout(1000) -- 1 sec
   local FILES_NAMES = {}
   while true do
      local typ, res, err = form:read()
      if not typ then
         ngx.log(ngx.ERR, "failed to stream request body: ", err)
         return
      end
      if typ == "header" then
         if res[1]:lower() == 'content-disposition' then
            local header = res[2]
            local s, f = header:find(' name="([^"]+")')
            file = header:sub(s + 7, f - 1)
            table.insert(FILES_NAMES, file)
            s, f = header:find('filename="([^"]+")')
            if s then table.insert(FILES, header:sub(s + 10, f - 1))
            end
         end
      end
      print('upload file body type: ', typ, ', res type: ', type(res))
      if type(res) == 'string' then
         file_size = file_size + #res
      end
      if typ == "eof" then
         break
      end
      if file_size > upload_file_limit then
         print('exceeds upload file limit, return instant', file_size, ':', upload_file_limit)
         break
      end
   end
   print('get request upload file names', cjson.encode(FILES_NAMES))
   ngx.ctx.upload_file_names = FILES_NAMES
   print('get request upload file size: ', file_size)
   return file_size
end

local function _get_upload_file_size()
   local file_size = _parse_upload_file() or 0
   return file_size
end

local function _parse_body_headers()
   local headers, err = ngx.resp.get_headers()

   if err == "truncated" then
      -- one can choose to ignore or reject the current response here
      ngx.log(ngx.CRIT, 'exceeds MAXIMUM 100 headers')
      ngx.ctx.resp_headers_truncated = _truncated
   end
   if not headers then
      print("failed to get response headers: ", err)
      return
   end
   return headers
end


_M.lookup = {
   body_args = function() return _parse_body_args() end,
   body_nofile_size = function() return _get_nofile_size() end,
   upload_file_size = function() return _get_upload_file_size() end,
   uri_args = function() return _parse_uri_args() end,
   uri = function() return ngx.req.uri end,
   uri_args_size = function() return #ngx.var.args end,
   method = function() return ngx.req.get_method() end,
   ip = function() return utils.get_client_ip() end,
   host = function() return ngx.var.host end,
   cookies = function() return _parse_cookies() end,
   ua = function() return ngx.var.http_user_agent end,
   refer = function() return ngx.var.http_referer end,
   headers = function() return _parse_headers() end,
   body_headers = function() return _parse_body_headers() end
}
return _M
