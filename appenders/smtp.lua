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

---	SMTP appender sending the log messages as an email.<br/>
--
-- This appender requires <a href="http://luaforge.net/projects/luasocket/">LuaSocket</a>.
--
-- <h3>Configuration</h3>
-- This appender takes a table formatted according to <a href="http://www.tecgraf.puc-rio.br/~diego/professional/luasocket/smtp.html">socket.smtp</a>
-- as smtp/email configuration. The table must be like this:<br />
-- <code class="lua">
--      local params = {<br />
--          headers = {<br />
--              from = "sender@domain.tld",<br />
--              to = "recipient@domain.tld",<br />
--              subject = "May contain placeholders like %LEVEL, %MESSAGE and so on"<br />
--          },<br />
--          body = "The body of the message. May contain placeholders like %LEVEL, %MESSAGE and so on."<br />
--      }
-- </code>
-- If <code>params.headers.subject</code> or <code>params.body</code>
--
-- <h3>Log level threshold</h3>
-- In order to be able to use the smtp appender even for categories configured to level <code>DEBUG</code> a level threshold is used. Only messages
-- higher or equal than that threshold will be send.
-- @author $Author: peter.romianowski $
-- @release $Date: 2008-09-06 03:57:01 +0200 (Sa, 06 Sep 2008) $ $Rev: 68 $

module("log4lua.appenders.smtp", package.seeall)

local _module = {}

local smtp = require("socket.smtp")
local log = require("log4lua.logger")

--- An appender that sends emails.
-- @param mail a table containing the smpt and mail configuration
-- @param levelThreshold (optional) a level constant (logger.DEBUG, logger.WARN etc.) If given then only messages with a higher or equal level are sent.
-- @param smtpHost optional
-- @param smtpPort optional
-- @param smtpUser optional
-- @param smtpPassword optional
-- @param smtpImpl is only used in tests and defaults to socket.smtp
function _module.new(mail, levelThreshold, smtpHost, smtpPort, smtpUser, smtpPassword, smtpImpl)
    assert(mail ~= nil and type(mail) == "table", "Invalid mail configuration.")
    assert(mail.body, "No body given.")
    assert(type(mail.body) == "string", "Body can only be a string. Sending of HTML or Multipart emails is not implemented. Who needs this anyway?")
    assert(mail.headers, "No headers given.")
    assert(mail.headers.from, "No sender given.")
    assert(mail.headers.to, "No recipients given.")
    assert(mail.headers.subject, "No subject given.")
    assert(levelThreshold == nil or log.LOG_LEVELS[levelThreshold] ~= nil, "Invalid log threshold level '" .. tostring(levelThreshold) .. "'")
    smtpImpl = smtpImpl or smtp
    local subjectPattern = mail.headers.subject
    local bodyPattern = mail.body
    return
        function(logger, level, message, exception, country)
            if (levelThreshold == nil or log.LOG_LEVELS[level] >= log.LOG_LEVELS[levelThreshold]) then
                mail.headers.subject = logger:formatMessage(subjectPattern, level, message, exception, country)
                mail.body = logger:formatMessage(bodyPattern, level, message, exception, country)
                -- Replace plain \n by \r\n to comply to RFC 822
                mail.body = string.gsub(mail.body, "(\r\n", "\n")
                mail.body = string.gsub(mail.body, "(\n", "\r\n")
                local result, err = smtpImpl.send{
                    from = mail.headers.from,
                    rcpt = mail.headers.to,
                    source = smtpImpl.message(mail),
                    server = smtpHost,
                    port = smtpPort,
                    user = smtpUser,
                    password = smtpPassword
                }
                if (not result) then
                    print("Log4LUA Error: Sending of email with body '" .. tostring(mail.body) .. "' failed. Reason: " .. tostring(err))
                end
            end
        end
end

return _module