-- -*- coding: utf-8 -*-
local _M = {}

_M.disruptive_lookup = {
   APPEND = function(content)
      local response_body = ngx.ctx.response_body
      if response_body then
         ngx.ctx.response_body = response_body .. content
      end
   end,
   EMPTY = function(content)
      ngx.ctx.response_body = nil
      return
      [[ local response_body = ngx.ctx.response_body
      if response_body then
         --error('detect reponse error')
         return
      end
]]
   end,
   GSUB = function(pattern, new, pcre_flags)
      local response_body = ngx.ctx.response_body
      if type(response_body) == 'string' then
         print('reponse to replace: ', response_body, ', pattern: ', pattern, ', new: ', new)
         ngx.ctx.response_body = ngx.re.gsub(response_body, pattern, new, pcre_flags)
      end
   end,
   ACCEPT = function()
      --ngx.exit(ngx.OK)
      return
   end,
   DENY = function()
      ngx.exit(ngx.HTTP_FORBIDDEN)
   end,
   DROP = function()
      --ngx.exit(ngx.HTTP_CLOSE)
      ngx.exit(444)
   end,
   MAX_BODY = function()
      ngx.exit(413)
   end,
   REDIRECT = function(redirect_url, status)
      ngx.redirect(redirect_url, status or ngx.HTTP_MOVED_TEMPORARILY)
   end
   --[[-该动作可能不生效，需测试，正常rewrite执行是在rewrite_by_lua阶段执行
   REWRITE = function(rewirte_uri)
      --local url = ngx.re.sub(ngx.var.url, src, desc)
      ngx.req.set_uri(rewrite_uri, true)
   end
   --]]
}

return _M
