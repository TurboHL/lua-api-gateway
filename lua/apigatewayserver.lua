local http = require "resty.http"
local cjson = require "cjson.safe"
local decode_json = cjson.decode
local encode_json = cjson.encode

cjson.encode_empty_table_as_object(false)

local _M={
    version = "0.0.1"
}

function _M.getServerIp()

    -- 1.获取服务名 获取查询参数
    local request_uri = ngx.var.request_uri
    --ngx.log(ngx.INFO,"request_uri =" .. request_uri)
    local idx_a = string.find(request_uri,"/")
    local idx_b = string.find(request_uri,"/",2)
    local server_name = string.sub(request_uri,idx_a + 1,idx_b - 1)
    --local server_name = string.gsub(request_uri, "(/)(/)", "", 2)
    ngx.log(ngx.INFO,"server_name =" .. server_name)

    local sub_url = string.sub(request_uri,idx_b + 1);
    ngx.log(ngx.INFO,"sub_url =" .. sub_url)


    -- 2.通过服务名获取注册的服务list
    local httpc = http.new()
    local res, err = httpc:request_uri("http://10.163.1.41:12000/eureka/apps/" .. server_name,{
            method = "GET",
            headers = {
                ["Accept"] = "application/json;charset=utf-8",
                ["Content-Type"] = "application/json;charset=utf-8",
                ["Cache-Control"] = "no-cache",
            },
            keepalive_timeout = 60,
            keepalive_pool = 10
            })
    if res.status == ngx.HTTP_OK then
        ngx.log(ngx.INFO,"请求成功")
        --ngx.log(ngx.INFO,res.body)
    else
        ngx.exit(res.status)
        ngx.log(ngx.ERR,err)
    end

    --- 解析字符获取IP-list
    local server_table = {}
    local ipAddr
    local port
    --- json字段串有转义符替换成正常的
    local newStr, n, err = ngx.re.gsub(res.body, [[\\/]], [[]])
    local obj = decode_json(newStr)
    for key, val in pairs(obj.application.instance) do

        if val['status'] == "UP" then
            ipAddr = val['ipAddr']
            port = val['port']['$']
        end
        server_table[key] = ipAddr .. ":" .. port
    end

    ngx.log(ngx.INFO,'服务组=' .. table.concat(server_table,"-"))

    --3.通过负载均衡模式算法请求后端服务
    local size = #server_table
    local idx = ngx.time()%size
    --ngx.log(ngx.INFO,"idx="..idx)
    --ngx.log(ngx.INFO,"idx="..server_table[idx + 1])

    -- 4.返回请求结果
    local serverIp = server_table[idx + 1]

    ngx.log(ngx.INFO,'服务IP=' .. serverIp)
    return serverIp
end

return _M