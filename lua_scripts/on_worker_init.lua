-- -*- coding: utf-8 -*-
local config = require('config')
if config.log_type == "kafka" then
   local kafka = require('kafka')
   kafka.init()
end
