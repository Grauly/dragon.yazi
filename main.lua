local header_name = "dragon"

local options = {
    { on = "y", run = "export",     desc = "Drag files away with dragon" },
    { on = "Y", run = "export_all", desc = "Drag all files at once away with dragon" },
    { on = "d", run = "drop",       desc = "Drag files here with dragon" },
}

local quit_options = {
    { on = "q", run = "quit", desc = "Stop accepting files" }
}

local notify = function(content, level)
    ya.notify {
        title = header_name,
        content = content,
        level = level,
        timeout = 5
    }
end

local info = function(content)
    notify(content, "info")
end

local error = function(content)
    notify(content, "error")
end

function dump(o)
    if type(o) == 'table' then
        local s = '{ '
        for k, v in pairs(o) do
            if type(k) ~= 'number' then k = '"' .. k .. '"' end
            s = s .. '[' .. k .. '] = ' .. dump(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end

--shamelessly stolen from https://github.com/yazi-rs/plugins/tree/main/chmod.yazi
local selected_or_hovered = ya.sync(function()
    local tab, paths = cx.active, {}
    for _, u in pairs(tab.selected) do
        paths[#paths + 1] = tostring(u)
    end
    if #paths == 0 and tab.current.hovered then
        paths[1] = tostring(tab.current.hovered.url)
    end
    return paths
end)

local get_command = function(command)
    local optionalNixedModule = require(command)
    return optionalNixedModule.command or command
end

local handle_export = function(export_all)
    local paths = selected_or_hovered()
    local command = Command(get_command("dragon")):arg("--and-exit")
    if export_all then
        local all_command = ""
        if #paths > 10 then
            all_command = "--all-compact"
        else
            all_command = "--all"
        end
        command = command:arg(all_command)
    end
    command = command:args(paths)
    local child, err = command:spawn()
    if err then
        error(tostring(err))
    end
end

local handle_drop = function()
end


return {
    entry = function()
        local action = (options[ya.which { cands = options }] or { run = "invalid" }).run
        if action == "export" then
            handle_export(false)
        elseif action == "export_all" then
            handle_export(true)
        elseif action == "drop" then
            handle_drop()
        end
    end
}
