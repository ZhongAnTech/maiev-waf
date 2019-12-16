local _M = {}

function _M.get_client_ip()
   local ip = ngx.var.remote_addr
   local xff = ngx.req.get_headers()['X-Forwarded-For']
   if xff then
      local ips = {}
      for i in xff:gmatch(',') do
         ips[#ips+1] = i
      end
      if #ips >= 2 then
         ip = ips[#ips-1]
      elseif #ips == 1 then
         ip = ips[1]
      end
   end
   return ip
end

-- io
function _M.over_write_file(file_name, data)
   local file = io.open(file_name, 'w+')
   if file then
      file:write(data)
      file:close()
      return true
   else
      ngx.log(ngx.ERR, 'over write file failed: ', file_name)
   end
end

function _M.read_small_file(file_name)
   local file, err = io.open(file_name)
   local data = {}
   if file then
      for line in file:lines() do
         data[#data+1] = line
      end
      file:close()
      return table.concat(data, '\n')
   else
      ngx.log(ngx.ERR, '---failed open file: '..file_name)
   end
end

function _M.check_did(did)
   if did then
      local bs = ngx.decode_base64(did)
      if not bs then
         return
      end
      local t = {}
      for token in string.gmatch(bs, '[^-]+') do
         t[#t+1] = token
      end
      --ngx.log(ngx.ERR, '---raw', table.concat(t, '-'))
      local key='\xf9\xfdQ"\xe7\x9fU\xc85\xa4{\xe0\x9d\x9d\x1b\xa5'
      local msg = t[2] .. t[1]
      local digest = ngx.encode_base64(ngx.hmac_sha1(key, msg))
      if digest==t[3] then
         return true
      end
   end
end

function _M.table_values(t)
   local rt = {}
   if type(t) == 'table' and #t > 0 then
      for k, v in pairs(t) do
         rt[#rt+1] = v
      end
      return rt
   --else
   --   print('no table found')
   end
end

function _M.table_keys(t)
   local rt = {}
   if type(t) == 'table' and #t > 0 then
      for k, v in pairs(t) do
         rt[#rt+1] = k
      end
      return rt
   --else
   --   print('no table found')
   end
end

return _M
