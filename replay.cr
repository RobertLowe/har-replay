require "http/client"
require "har" # these are just json files, but there's a library so lets use it, what could go wrong?

json = HAR.from_file("./replay.har") 

# track when all hars are processed
completed = 0;

ENV["SPAWN"] ||= "2"

ENV["SPAWN"].to_i.times do 
  spawn do
    # track when all entries for a har are processed
    entries_completed = 0
    entries = json.entries
    entries.each do |entry|
      if entry.websocket_messages
        entries_completed += 1 if reply_websocket(entry)
      else
        entries_completed += 1 if reply_http(entry)
      end    
    end
    completed += 1 if entries_completed == entries.size
  end
end

# wait until all spawns are complete
until completed >= 2
  sleep 0.1
end


def reply_http(entry)
  p entry.request.url
  headers = HTTP::Headers.new 
  entry.request.headers.each do |header|
    headers.add header.name, header.value
  end
  context = OpenSSL::SSL::Context::Client.insecure
  response = HTTP::Client.exec entry.request.method, entry.request.url, headers: headers, tls: context
  p "Reponse Code: " + response.status_code.to_s + " Bytes: " + response.body.size.to_s

  return true
end

def reply_websocket(entry)
  p entry.request.url
  headers = HTTP::Headers.new 
  entry.request.headers.each do |header|
    # accept-encoding can mess up responses, so only pluck a few headers
    if header.name == "Origin" || header.name == "Pragma" || header.name == "Host" || header.name == "User-Agent"
      headers.add header.name, header.value
    end
  end

  # WARN: lazy hack to ignore SSL failures due to `Unhandled exception: SSL_connect: error:1416F086:SSL routines:tls_process_server_certificate:certificate verify failed (OpenSSL::SSL::Error)`
  context = OpenSSL::SSL::Context::Client.insecure

  uri = URI.parse(entry.request.url)
  messages = entry.websocket_messages || Array(HAR::WebSocketMessage).new;

  websocket = HTTP::WebSocket.new(uri.host.to_s, uri.path, tls: context, headers: headers)
  websocket.on_message do |msg|
    p "<<<" + msg
  end
  # blocking so spawn in a thread
  spawn do
    websocket.run
  end
  sleep 0.25

  messages.each do |message|
    if message.type == "send"
      p ">>>" + message.data
      websocket.send(message.data)
    end
    sleep 0.25
  end

  sleep 1

  return true
end