--[[
   Copyright (C) 2008 optivo GmbH

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; version 2 of the License.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
--]]

---	Console appender.
--
-- @author $Author: peter.romianowski $
-- @release $Date: 2008-09-06 03:57:01 +0200 (Sa, 06 Sep 2008) $ $Rev: 68 $

module("log4lua.appenders.console", package.seeall)

local _module = {}

--- A console appender that simply prints the message to STDOUT.
-- @param pattern (optional) the message pattern.
function _module.new(pattern)
    return
    function(logger, level, message, excpetion, country)
        io.stdout:write(logger:formatMessage(pattern, level, message, excpetion, country))
    end
end

return _module