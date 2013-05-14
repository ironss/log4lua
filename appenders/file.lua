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

---	File appender.<br/>
--
-- <h3>Log rotation</h3>
-- Optionally the appender can be created with a date pattern to enable log file rotation. If you want to enable
-- this feature you have to put the placeholder "%s" into your file name. As an example this creates a daily
-- rotating file:<br />
-- <code class="lua">
--     local fileAppender = require("log4lua.appenders.file")<br/>
--     fileAppender.create("myFile-%s.log", "%Y-%m-%d")<br />
-- </code>
--
-- @author $Author: peter.romianowski $
-- @release $Date: 2008-09-06 03:57:01 +0200 (Sa, 06 Sep 2008) $ $Rev: 68 $

module("log4lua.appenders.file", package.seeall)

local _module = {}

--- An appender that logs to a file.
-- @param fileName path to the log file. It must be writeable otherwise the appender will be disabled.
-- @param datePattern (optional) the pattern to be used to format (os.date) a date which is then substituted in the file name.
-- @param pattern (optional) the message pattern.
function _module.new(fileName, datePattern, pattern)
    assert(fileName ~= nil and type(fileName) == "string", "Invalid filename '" .. tostring(fileName) .. "'")
    local file = nil
    local currentDate = nil
    return
        function(logger, level, message, exception, country)
            local date = os.date(datePattern)
            if (date ~= currentDate or file == nil) then
                currentDate = date
                -- Rotate the file.
                if (file ~= nil) then
                    file:close()
                end
                file = io.open(string.format(fileName, currentDate), "a")
                if (not file) then
                    io.stderr:write(string.format("Log4LUA ERROR: File '%s' cannot be opened for writing. Disabling appender.\n", fileName))
                else
                    file:setvbuf ("line")
                end
            end
            if (file ~= nil) then
                file:write(logger:formatMessage(pattern, level, message, exception, country))

				-- Sync the file to avoid buffer overlap
				file:flush()
            end
        end
end

return _module
