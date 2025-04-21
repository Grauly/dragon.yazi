package.cpath = package.cpath .. ";./?.lua"

local header_name = "dragon"

local options = {
    { on = "y", run = "export",     desc = "Drag files away with dragon" },
    { on = "Y", run = "export_all", desc = "Drag all files at once away with dragon" },
    { on = "d", run = "drop",       desc = "Drag files here with dragon" },
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

--needs a plugin named "nix-commands" with a database of commands
local get_nix_command = function(command)
    local loaded, content = pcall(require, "nix-commands")
    if not loaded then
        ya.err(content)
        return command
    end
    if not content.commands then
        ya.err("nix-commands does not have a commands section, defaulting")
        return command
    end
    local nix_command = content.commands[command]
    if not nix_command then
        ya.err("nix-commands does not have a \""..command.."\" defined")
        return command
    end
    return nix_command
end

local handle_export = function(export_all)
    local paths = selected_or_hovered()
    local command = Command(get_nix_command("dragon")):arg("--and-exit")
    if export_all then
        local all_command = ""
        if #paths > 10 then
            all_command = "--all-compact"
        else
            all_command = "--all"
        end
        command = command:arg(all_command)
    end
    local out, err = command:args(paths):output()
    if err then
        error(tostring(err))
        return
    end
end

local get_cwd = ya.sync(function()
    return cx.active.current.cwd
end)

local copy_file_to_cwd = function(location)
    local cwd = get_cwd()
    --todo: differntiate between local Url and web Url
    info(tostring(cwd))
end

local handle_drop = function()
    local command = Command(get_nix_command("dragon")):args { "--target", "--keep" }
    local running = true
    local child, err = command:spawn()
    if err then
        error(tostring(err))
        return
    end
    while (running and (not err)) do
        local line, event = child:read_line_with { timeout = 50 }
        if event == 0 then
            copy_file_to_cwd(line)
        end

    end
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
    end,
    handle = "this is the main file"
}
