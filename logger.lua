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

---	Logging facility.</br>
--
-- A logger consists of a category (to distinct different modules etc.) and an appender which actually
-- writes the message (to console, file etc.)
--
-- <h3>Configuration</h3>
-- A sample configuration file looks like this:<br />
-- <code class="lua">
--      local logger = require("optivo.common.log4lua.logger")<br />
--      local console = require("optivo.common.log4lua.appenders.console")<br />
--      local file = require("optivo.common.log4lua.appenders.file")<br />
--      local config = {}<br />
--      <br />
--      -- ROOT category must be configured.<br />
--      config["ROOT"] = logger.Logger.new(console.new(), "ROOT", logger.FATAL)<br />
--      config["foo"] = logger.Logger.new(file.new("foo-%s.log", "%Y-%m-%d"), "foo", logger.INFO)<br />
--      config["bar"] = logger.Logger.new(file.new("bar.log", nil, "%LEVEL: %MESSAGE\n"), "bar", logger.INFO)<br />
--      <br />
--      -- The config table must be returned.<br />
--      return config
-- </code><br />
--
-- Then you can load this configuration file "by hand" calling <code>loadConfig(fileName)</code> or you
-- can set a default configuration file using the environment variable <code>LOG4LUA_CONFIG_FILE</code>.
--
-- <h3>Patterns</h3>
-- Patterns may contain the following placeholders:
-- <ul>
--     <li>%DATE - Ingame time</li>
--     <li>%RDATE - Real time</li>
--     <li>%LEVEL</li>
--     <li>%MESSAGE</li>
--     <li>%COUNTRY - Current in game country</li>
--     <li>%FILE - the source filename w/o path</li>
--     <li>%PATH - the source filename including the path</li>
--     <li>%LINE - the position in the source file</li>
--     <li>%FUNCTION - the function name</li>
--     <li>%STACKTRACE - the complete stack trace</li>
--     <li>%ERROR - an exception string like the one you get using pcall(...)</li>
-- </ul>
-- <em>Important performance note:</em> Using one of <code>%FILE, %PATH, %LINE, %FUNCTION, %STACKTRACE</code> implies a quite huge performance
-- hit because <code>debug.traceback()</code> has to be called for every message logged. Note that the default pattern uses these placeholders.
--
-- Default pattern for all appenders is <code>[%DATE] [%LEVEL] [%COUNTRY]: %MESSAGE at %FILE:%LINE(%METHOD)\n</code>
--
-- @author $Author: peter.romianowski $
-- @release $Date: 2008-09-23 08:20:56 +0200 (Di, 23 Sep 2008) $ $Rev: 90 $
module("log4lua.logger", package.seeall)

-- Class definition
local Logger = {}
Logger.__index = Logger

local _module = Logger

local console = require("log4lua.appenders.console")
local file = require("log4lua.appenders.file")
local utils = require("log4lua.utils")

--- Level constants.
_module.DEBUG = "DEBUG"
--- Level constants.
_module.INFO = "INFO"
--- Level constants.
_module.WARN = "WARN"
--- Level constants.
_module.ERROR = "ERROR"
--- Level constants.
_module.FATAL = "FATAL"
--- Level constants.
_module.OFF = "OFF"

_module.LOG_LEVELS = {
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4,
    FATAL = 5,
    OFF = 6
}

-- Default pattern used for all appenders.
_module.DEFAULT_PATTERN = "[%DATE] [%LEVEL] [%COUNTRY] %MESSAGE at %FILE:%LINE(%METHOD)\n"

-- Name of the environment variable that holds the path to the default config file.
local ENV_LOGGING_CONFIG_FILE = "LOG4LUA_CONFIG_FILE"

-- Map containing all configured loggers (key is category).
local _loggers = nil

-- Load default configuration found in environment variable.
local function initConfig()
    if (_loggers == nil) then
        local configFile = os.getenv(ENV_LOGGING_CONFIG_FILE)
        if (configFile ~= nil) then
            _module.loadConfig(configFile)
        else
            -- We need at least a root logger.
            _loggers = {}
            _loggers["ROOT"] = Logger.new(console.new(), "ROOT", _module.INFO)
        end
    end
end

--- Main method that returns a fully configured logger for the given category.<br />
-- The correct logger is found as follows:
-- <ul>
--    <li>If there is a configured logger with the exact category then use this.</li>
--    <li>Otherwise search for loggers with matching category.
--        Example: If there is a configured logger for category "test" then it is used for category "test.whatever", "testinger" etc.</li>
--    <li>Otherwise use the root category.</li>
-- </ul>
-- @param category the category of the desired logger.
function _module.getLogger(category)
	initConfig()
    local log = nil
    if (category ~= nil) then
        log = _loggers[category]
        if (log == nil) then
            for loggerCategory, logger in pairs(_loggers) do
                if (string.find(category, loggerCategory, 1, true) == 1) then
                    log = logger
                    break
                end
            end
        end
    end
    if (log == nil) then
        log = _loggers["ROOT"]
    end
    assert(log, "Logger cannot be empty. Check your configuration!")
    return log
end

--- Load a configuration file.
-- @param fileName path to a configuration file written in lua. The lua code must return a map (table) with loggers configured for each category.
function _module.loadConfig(fileName)
    local result, errorMsg = loadfile(fileName)

    if (result) then
		local loadedLoggers = result()
        assert(loadedLoggers ~= nil and loadedLoggers["ROOT"] ~= nil, "At least a log category 'ROOT' must be specified.")
        _loggers = loadedLoggers
    else
		-- Default configuration if no config file has been specified or it could not be loaded.
		_loggers = {}
        _loggers["ROOT"] = Logger.new(console.new(), "ROOT", _module.INFO)
        _module.getLogger("ROOT"):info("No logging configuration found in file '" .. fileName .. "' (Error: " .. tostring(errorMsg) .. "). Using default (INFO to console).")
    end
end

--- Constructor.
-- @param appenders a single function or a table of functions taking a string as parameter that is responsible for writing the log message.
-- @param category the category (== name) of this logger
-- @param level the threshold level. Only messages for equal or higher levels will be logged.
function Logger.new(appenders, category, level)
    local self = {}
    setmetatable(self, Logger)
    assert(appenders ~= nil and (type(appenders) == "function" or type(appenders) == "table"), "Invalid value for appenders.")
    if (type(appenders) == "function") then
        appenders = {appenders}
    end
    for _, appender in ipairs(appenders) do
        assert(type(appender) == "function", "First parameter (the appender) must be a function.")
    end
    assert(category ~= nil, "Category not set.")
    self._appenders = appenders
    self._level = level or _module.INFO
    self._category = category

    return self
end

--- Set the log level threshold.
function Logger:setLevel(level)
    assert(_module.LOG_LEVELS[level] ~= nil, "Unknown log level '" .. level .. "'")
    self._level = level
end

--- Log the given message at the given level.
function Logger:log(level, message, exception, country)
	assert(_module.LOG_LEVELS[level] ~= nil, "Unknown log level '" .. level .. "'")
    if (_module.LOG_LEVELS[level] >= _module.LOG_LEVELS[self._level] and level ~= _module.OFF) then
        for _, appender in ipairs(self._appenders) do
			appender(self, level, message, exception, country)
        end
    end
end

--- Test whether the given level is enabled.
-- @return true if messages of the given level will be logged.
function Logger:isLevel(level)
    local levelPos = _module.LOG_LEVELS[level]
    assert(levelPos, "Invalid level '" .. tostring(level) .. "'")
    return levelPos >= _module.LOG_LEVELS[self._level]
end

--- Log message at DEBUG level.
function Logger:debug(message, exception, country)
    self:log(_module.DEBUG, message, exception, country)
end

--- Log message at INFO level.
function Logger:info(message, exception, country)
    self:log(_module.INFO, message, exception, country)
end

--- Log message at WARN level.
function Logger:warn(message, exception, country)
    self:log(_module.WARN, message, exception, country)
end

--- Log message at ERROR level.
function Logger:error(message, exception, country)
    self:log(_module.ERROR, message, exception, country)
end

--- Log message at FATAL level.
function Logger:fatal(message, exception, country)
    self:log(_module.FATAL, message, exception, country)
end

function Logger:formatMessage(pattern, level, message, exception, country)
    local result = pattern or _module.DEFAULT_PATTERN
    if (type(message) == "table") then
        message = utils.convertTableToString(message, 5)
    end
    message = string.gsub(tostring(message), "%%", "%%%%")

    -- If the pattern contains any traceback relevant placeholders process them.
    if (
        string.match(result, "%%PATH")
        or string.match(result, "%%FILE")
        or string.match(result, "%%LINE")
        or string.match(result, "%%METHOD")
        or string.match(result, "%%STACKTRACE")
    ) then
        -- Take no risk - format the stacktrace using pcall to prevent ugly errors.
        _, result = pcall(Logger._formatStackTrace, self, result)
    end

	-- Test CCurrentGameState existance, this script may run from pure LUA without HOI3 bindings
	local inGameDate = ""
	if CCurrentGameState ~= nil then
		inGameDate = CCurrentGameState.GetCurrentDate()
		inGameDate = tostring(inGameDate:GetYear()) .. "-" .. tostring(inGameDate:GetMonthOfYear()+1) .. "-" .. tostring(inGameDate:GetDayOfMonth()+1)
	end

    result = string.gsub(result, "%%DATE", inGameDate)
	result = string.gsub(result, "%%RDATE", tostring(os.date()))
    result = string.gsub(result, "%%LEVEL", level)
    result = string.gsub(result, "%%MESSAGE", message)
	result = string.gsub(result, "%%COUNTRY", country)
    -- tweak for AIIP (log4lua is bugged)
	if exception ~= nil then
		result = string.gsub(result, "%%ERROR", exception)
	end

    return result
end

-- Format stack trace.
function Logger:_formatStackTrace(pattern)
    local result = pattern

    -- Handle stack trace and method.
    local stackTrace = debug.traceback()

    for line in string.gmatch(stackTrace, "[^\n]-\.lua:%d+: in [^\n]+") do
        if 	not string.match(line, ".-log4lua.-\.lua:%d+:") and
			-- AIIP added utils.lua in list not to refer to wrapper
			not string.match(line, "utils\.lua") and
			not string.match(line, ".-dtools.-\.lua:%d+:")
		then
            local _, _, sourcePath, sourceLine, sourceMethod = string.find(line, "(.-):(%d+): in (.*)")
			local _, _, sourceFile = string.find(sourcePath or "n/a", ".*\\(.*)")

			result = string.gsub(result, "%%PATH", sourcePath or "n/a")
			result = string.gsub(result, "%%FILE", sourceFile or "n/a")
			result = string.gsub(result, "%%LINE", sourceLine or "n/a")
			result = string.gsub(result, "%%METHOD", sourceMethod or "n/a")
            break
        end
    end
	
	result = string.gsub(result, "%%STACKTRACE", stackTrace)

    return result
end

return _module
