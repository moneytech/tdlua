local tdlua = require "tdlua"
local serpent = require "serpent"
local json = require 'dkjson'
local function vardump(wut)
    print(serpent.block(wut, {comment=false}))
end
local api_id = "6"
local api_hash = "eb06d4abfb49dc3eeb1aeb98ae0f581e"
local dbpassword = ""
tdlua.setLogLevel(0)
local client = tdlua()
client:send(
    (
        {_ = "getAuthorizationState"}
    )
)
local ready = false
local function authstate(state)
    if state._ == "authorizationStateClosed" then
        os.exit(0)
    elseif state._ == "authorizationStateWaitTdlibParameters" then
        client:send({
                _ = "setTdlibParameters",
                parameters = {
                    _ = "setTdlibParameters",
                    use_message_database = true,
                    api_id = api_id,
                    api_hash = api_hash,
                    system_language_code = "en",
                    device_model = "tdlua",
                    system_version = "unk",
                    application_version = "0.1",
                    enable_storage_optimizer = true,
                    use_pfs = true,
                    database_directory = "./call"
                }
            }
        )
    elseif state._ == "authorizationStateWaitEncryptionKey" then
        client:send({
                _ = "checkDatabaseEncryptionKey",
                encryption_key = dbpassword
            }
        )
    elseif state._ == "authorizationStateWaitPhoneNumber" then
        print("Do you want to login as a Bot or as an User? [U/b]")
        if io.read() == 'b' then
            print("Enter bot token: ")
            local token = io.read()
            client:send({
                    _ = "checkAuthenticationBotToken",
                    token = token
                }
            )
        else
            print("Enter phone: ")
            local phone = io.read()
            client:send({
                    _ = "setAuthenticationPhoneNumber",
                    phone_number = phone
                }
            )
        end
    elseif state._ == "authorizationStateWaitCode" then
        print("Enter code: ")
        local code = io.read()
        client:send({
                _ = "checkAuthenticationCode",
                code = code
            }
        )
    elseif state._ == "authorizationStateWaitPassword" then
        print("Enter password: ")
        local password = io.read()
        client:send({
                _ = "checkAuthenticationPassword",
                password = password
            }
        )
    elseif state._ == "authorizationStateReady" then
        ready = true
        print("ready")
        --os.exit(0)
    end
end

local calling = true

while true do
    local res = client:receive(1)
    if res then
        if (type(res) ~= "table") then
            print("GOT NT", res._)
            vardump(res)
            goto continue
        end
        if not ready or res._ == "updateAuthorizationState" then
            authstate(res.authorization_state and res.authorization_state or res)
            goto continue
        end
        if res._ == "connectionStateUpdating" then
          goto continue
        end
        if res._ == "updateNewMessage" then
            if not res.message.is_outgoing then
                local msg = res.message
                msg.text = (msg.content.text or msg.content.caption or {}).text or ''
                if msg.text then
                    local match = msg.text:match("!call (%d+)")
                    if match then
                        local call = client:getCall(match)
                        if call then
                            vardump(call:debug())
                        end
                    end
                end
            end
        end
        if res._ == "updateCall" then
            vardump(res)
            local call = res.call
            if call.state._ == "callStatePending" and not call.is_outgoing then
                ---[[
                vardump(client:acceptCall({
                    call_id = call.id,
                    protocol = {
                        _ = "callProtocol",
                        udp_p2p = true,
                        udp_reflector = true,
                        min_layer = 65,
                        max_layer = 74
                    }
                }))
                --]]
            elseif call.state._ == "callStateReady" then
                client:sendMessage({
                    chat_id = call.user_id,
                    input_message_content = {
                        ["@type"] = "inputMessageText",
                        text = {
                            ["@type"] = "formattedText",
                            text = "Playing from TDLua\n\nEmojis "..table.concat(call.state.emojis)
                        }
                    }
                }, true)
                local songs = {"example.raw", "example.wav"} -- must be Mono 16-bit 48000Hz
                call:play(songs)
                call:onHold({"hold.pcm"})
            end
        else
            print("GOT", res._)
        end
        ::continue::
    end
end
