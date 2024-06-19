local config = {}
local ld_chunk = assert(loadfile("./config.ld"))
setfenv(ld_chunk, config)
ld_chunk()
local guns4d_chunk = assert(loadfile("./config.guns4d"))
setfenv(guns4d_chunk, config)
guns4d_chunk()


function trim_leading_space(line)
    local white_space = 0
    while string.sub(line, 1, 1) == " " do
        line = string.sub(line, 2)
        white_space = white_space+1
    end
    return line, white_space
end
--there should be
function generate_field_hyperlink_string(name)
    return "<a name = \""..name.."\"></a>"
end

local field_tag = "<h3>Fields:</h3>"
for _, class in pairs(config.guns4d_classes) do

    --read the file, break down into a modifiable structure.
    local fp = config.dir.."/classes/"..class..".html"
    local file_stream = io.open(fp, "r")
    assert(file_stream, "file not found while generating class docs, check class '"..class.."' is tagged as an @class")
    local line = 0
    local file = {}
    for line_text in file_stream:lines("*a") do
        line=line+1
        file[line]=line_text
    end

    --find fields and their associated class (with their hyperlink)
    for i, text in pairs(file) do
        --print(i,text)
        local trm_text, indent = trim_leading_space(text)
        if trm_text==field_tag then
            local line = i
            while

            do

            end
        end
    end
end