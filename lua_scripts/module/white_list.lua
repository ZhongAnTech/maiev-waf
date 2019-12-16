--local request_tester = require('request_tester')
local rule = require('rule')

local _M = {}

local function filter(white_list)
   if white_list ~= nil and next(white_list) ~= nil then
      for _, rule in pairs(white_list) do
         local match = {}
         for key, value in pairs(rule) do
               if key == 'IP' then
                  match['IP'] = {
                     ['operator'] = 'EQL',
                     ['value'] = value
                  }
               elseif key == 'URI' then
                  match['URI'] = {
                     ['operator'] = 'REG',
                     ['value'] = value
                  }
               end
         end
         if rule.match({match}) == true then
            return true
         end
      end
   end
   return false
end

_M.filter = filter

return _M
