local _M = {}
local _pcre_flags = 'ioj'


_M.lookup = {
   compress_whitespace = function(value)
      local str = tostring(value)
      return ngx.re.gsub(str, [=[\s+]=], ' ', _pcre_flags)
   end,
   length = function(value)
      return string.len(tostring(value))
   end,
   count = function(value)
      if type(value) == 'table' then
         return #value
      else
         return string.len(tostring(value))
      end
   end,
   hex_decode = function(value)
      local value
      if (pcall(function()
                value = str:gsub('..', function (cc)
                                    return string.char(tonumber(cc, 16))
                end)
      end)) then
         return value
      else
         return str
      end
   end,
   hex_encode = function(value)
      return (value:gsub('.', function (c)
                            return string_format('%02x', string_byte(c))
      end))
   end,
   html_decode = function(value)
      local str = ngx.re.gsub(value, [=[&lt;]=], '<', _pcre_flags)
      str = ngx.re.gsub(str, [=[&gt;]=], '>', _pcre_flags)
      str = ngx.re.gsub(str, [=[&quot;]=], '"', _pcre_flags)
      str = ngx.re.gsub(str, [=[&apos;]=], "'", _pcre_flags)
      str = ngx.re.gsub(str, [=[&#(\d+);]=],
                        function(n) return string.char(n[1]) end, _pcre_flags)
      str = ngx.re.gsub(str, [=[&#x(\d+);]=],
                        function(n) return string.char(tonumber(n[1],16)) end, _pcre_flags)
      str = ngx.re.gsub(str, [=[&amp;]=], '&', _pcre_flags)
      return str
   end,
   cmd_line = function(value)
      local str = tostring(value)
      str = ngx.re.gsub(str, [=[[\\'"^]]=], '',  _pcre_flags)
      str = ngx.re.gsub(str, [=[\s+/]=],    '/', _pcre_flags)
      str = ngx.re.gsub(str, [=[\s+[(]]=],  '(', _pcre_flags)
      str = ngx.re.gsub(str, [=[[,;]]=],    ' ', _pcre_flags)
      str = ngx.re.gsub(str, [=[\s+]=],     ' ', _pcre_flags)
      return string.lower(str)
   end,
   base64_encode = function(value)
      return ngx.encode_base64(value)
   end,
   base64_decode = function(value)
      print('b64decode value: ', value)
      local t_val = ngx.decode_base64(tostring(value))
      print('b64decode value: ', t_val)
      return (t_val) or value
   end,
   lowercase = function(value)
      return string.lower(tostring(value))
   end,
   normalise_path = function(value)
      while (ngx.re.match(value, [=[[^/][^/]*/\.\./|/\./|/{2,}]=], _pcre_flags)) do
         value = ngx.re.gsub(value, [=[[^/][^/]*/\.\./|/\./|/{2,}]=], '/', _pcre_flags)
      end
      return value
   end,
   normalise_path_win = function(value)
      value = string_gsub(value, [[\]], [[/]])
      return _M.lookup['normalise_path'](value)
   end,
   remove_comments = function(value)
      return ngx.re.gsub(value, [=[\/\*(\*(?!\/)|[^\*])*\*\/]=], '', _pcre_flags)
   end,
   remove_comments_char = function(value)
      return ngx.re.gsub(value, [=[\/\*|\*\/|--|#]=], '', _pcre_flags)
   end,
   remove_whitespace = function(value)
      return ngx.re.gsub(value, [=[\s+]=], '', _pcre_flags)
   end,
   trim = function(value)
      return ngx.re.gsub(value, [=[^\s*|\s+$]=], '')
   end,
   trim_left = function(value)
      return ngx.re.sub(value, [=[^\s+]=], '')
   end,
   trim_right = function(value)
      return ngx.re.sub(value, [=[\s+$]=], '')
   end,
   uri_decode = function(value)
      return ngx.unescape_uri(value)
   end,
   sql_hex_decode = function(value)
      if (string.find(value, '0x', 1, true)) then
         value = string.sub(value, 3)
         return _M.hex_decode(value)
      else
         return value
      end
   end
}


return _M
