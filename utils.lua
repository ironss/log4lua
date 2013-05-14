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

--- Utility functions.
--
-- @author $Author: peter.romianowski $
-- @release $Date: 2008-09-19 21:59:49 +0200 (Fr, 19 Sep 2008) $ $Rev: 74 $

module("log4lua.utils", package.seeall)

local _module = {}

--- Convert the given table to a string.
-- @param maxDepth until this depth all tables contained as values in the table will be resolved.
-- @param valueDelimiter (optional) default is " = "
-- @param lineDelimiter (optional) default is "\n"
-- @param indent (optional) initial indentiation of sub tables
function _module.convertTableToString(tab, maxDepth, valueDelimiter, lineDelimiter, indent)
    local result = ""
    if (indent == nil) then
        indent = 0
    end
    if (valueDelimiter == nil) then
        valueDelimiter = " = "
    end
    if (lineDelimiter == nil) then
        lineDelimiter = "\n"
    end
    for k, v in pairs(tab) do
        if (result ~= "") then
            result = result .. lineDelimiter
        end
        result = result .. string.rep(" ", indent) .. tostring(k) .. valueDelimiter
        if (type(v) == "table") then
            if (maxDepth > 0) then
                result = result .. "{\n" .. _module.convertTableToString(v, maxDepth - 1, valueDelimiter, lineDelimiter, indent + 2) .. "\n"
                result = result .. string.rep(" ", indent) .. "}"
            else
                result = result .. "[... more table data ...]"
            end
        elseif (type(v) == "function") then
            result = result .. "[function]"
        else
            result = result .. tostring(v)
        end
    end
    return result
end

--- Calculate a checksum by simply summing up all byte values of the given value (treated as string).
-- @param maxValue (optional, 65535 is default) the maximum value to be returned
-- @return a value between 0 and maxValue
function _module.calculateSimpleChecksum(value, maxValue)
    value = tostring(value)
    if (maxValue == nil) then
        maxValue = 65535
    end
    local result = 0
    for a = 1, string.len(value) do
        result = result + string.byte(value, a)
        if (result > maxValue) then
            result = result - maxValue
        end
    end
    return result
end

--- Copy a file.
--
-- The file will be loaded into memory first so DO NOT USE THIS METHOD FOR LARGE FILES!
--
-- @param src filename of the source
-- @param dest filename of the destination
function _module.copyFile(src, dest)
	local srcFd = assert(io.open(src, "rb"))
	local content = srcFd:read("*a")
	srcFd:close();

	local destFd = assert(io.open(dest, "wb+"))
	destFd:write(content);
	destFd:close();
end

-- Helper function to iterator over both inj.resultset.rows and proxy.response.resultset.rows.
-- This is needed since both are of different type.
function _module.resultSetIterator(rows)
    local fun
    if (rows == nil) then
        fun =
            function()
            end
    elseif (type(rows) == "table") then
        local index = 1
        fun = function(tab)
            local value = nil
            if (index <= #tab) then
                value = tab[index]
            end
            index = index + 1
            return value
        end
    else
        fun = rows
    end
    return fun, rows, nil
end

--- Format the given string as hex.
-- @param prefixHey (optional)
-- @param match (optional) a pattern that denotes which characters to convert to hex.
function _module.formatAsHex(s, prefixHex, match)
    local result = nil
    if (s ~= nil) then
        result = string.gsub(
            s,
            match or ".",
            function(c)
                return (prefixHex or "") .. string.format("%X", string.byte(c))
            end
        )
    end
    return result
end

-- Sub-string for utf8 formatted strings.
-- Behaves much like string.sub(...).
function _module.utf8Sub(s, first, last)
    local result = nil
    if (s ~= nil) then
        local b = nil
        local byteIndex = 1
        local utf8Index = 1
        local subFirst = nil
        local subLast = nil
        local byteLen = string.len(s)
        while (byteIndex <= byteLen) do
            if (utf8Index == first) then
                subFirst = byteIndex
            end
            b = string.byte(s, byteIndex)
            --print(utf8Index .. ": " .. byteIndex .. " => " .. string.format("%X", b))
            if (b >= 128 + 64 + 32 + 16) then
                byteIndex = byteIndex + 4
            elseif (b >= 128 + 64 + 32) then
                byteIndex = byteIndex + 3
            elseif (b >= 128 + 64) then
                byteIndex = byteIndex + 2
            else
                byteIndex = byteIndex + 1
            end
            if (last ~= nil and utf8Index == last) then
                subLast = byteIndex - 1
            end
            utf8Index = utf8Index + 1
        end
        if (subFirst) then
            result = string.sub(s, subFirst, subLast)
        else
            result = ""
        end
    end
    return result
end

-- Simply sleep a bit.
-- @param millis number of milliseconds to sleep. NOTE: current implementation waits whole seconds!
function _module.sleep(millis)
    local sec = math.ceil(millis / 1000)
    local start = os.time()
    while (start + sec > os.time()) do
        -- Just nothing - busy wait!
    end
end

-- Return a function that get a table element by index and ensures that it is not out of bounds.
function _module.saveGetIndex(tab)
    return
        function (index)
	        if (index <= #tab) then
	            return tab[index]
	        end
	    end
end

return _module
