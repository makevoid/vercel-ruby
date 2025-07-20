require 'tmpdir'
require 'net/http'
require 'base64'
require 'json'
require 'thin'

Thin

$entrypoint = '__VC_HANDLER_FILENAME'

ENV['RAILS_ENV'] ||= 'production'
ENV['RACK_ENV'] ||= 'production'
ENV['RAILS_LOG_TO_STDOUT'] ||= '1'

def rack_handler(httpMethod, path, body, headers)
  require 'rack'

  app, _ = Rack::Builder.parse_file($entrypoint)
  server = Rack::MockRequest.new app

  env = headers.transform_keys { |k| k.split('-').join('_').prepend('HTTP_').upcase }
  res = server.request(httpMethod, path, env.merge({ :input => body }))

  {
    :statusCode => res.status,
    :headers => res.original_headers,
    :body => res.body,
  }
end

def thin_handler(httpMethod, path, body, headers)
  require_relative $entrypoint
  require 'rack'

  if not Object.const_defined?('Handler')
    return { :statusCode => 500, :body => 'Handler not defined in lambda' }
  end

  host = '0.0.0.0'
  port = 3000

  # Create a Rack app wrapper for the Handler
  rack_app = if Handler.is_a?(Proc)
    lambda do |env|
      # Create WEBrick-compatible request object
      webrick_req = Object.new
      webrick_req.instance_variable_set(:@header, env.select { |k, v| k.start_with?('HTTP_') }.transform_keys { |k| k.sub(/^HTTP_/, '').downcase })
      webrick_req.define_singleton_method(:query) do
        Rack::Utils.parse_query(env['QUERY_STRING'] || '')
      end
      webrick_req.define_singleton_method(:body) do
        env['rack.input'].read if env['rack.input']
      end
      webrick_req.define_singleton_method(:request_method) do
        env['REQUEST_METHOD']
      end
      webrick_req.define_singleton_method(:path) do
        env['PATH_INFO']
      end
      webrick_req.define_singleton_method(:header) do
        @header
      end
      
      # Create WEBrick-compatible response object
      webrick_res = Object.new
      webrick_res.instance_variable_set(:@header, {})
      webrick_res.define_singleton_method(:status=) do |code|
        @status = code
      end
      webrick_res.define_singleton_method(:status) do
        @status ||= 200
      end
      webrick_res.define_singleton_method(:header) do
        @header
      end
      webrick_res.define_singleton_method(:body=) do |content|
        @body = content
      end
      webrick_res.define_singleton_method(:body) do
        @body ||= ''
      end
      webrick_res.define_singleton_method(:[]=) do |key, value|
        @header[key] = value
      end
      webrick_res.define_singleton_method(:[]) do |key|
        @header[key]
      end
      
      # Call the original handler
      Handler.call(webrick_req, webrick_res)
      
      # Return Rack response
      [webrick_res.status, webrick_res.header, [webrick_res.body]]
    end
  else
    Handler
  end

  # Create Thin server instance
  server = Thin::Server.new(host, port, rack_app)

  # Start server in a thread
  server_thread = Thread.new do
    server.start
  end

  # Give the server time to start
  sleep 0.1

  # Make the HTTP request
  http = Net::HTTP.new(host, port)
  res = http.send_request(httpMethod, path, body, headers)

  # Stop the server
  server.stop
  server_thread.join(1) # Wait up to 1 second for thread to finish
  server_thread.kill if server_thread.alive?

  # Net::HTTP doesn't read the set the encoding so we must set manually.
  # Bug: https://bugs.ruby-lang.org/issues/15517
  # More: https://yehudakatz.com/2010/05/17/encodings-unabridged/
  res_headers = res.each_capitalized.to_h
  if res_headers["Content-Type"] && res_headers["Content-Type"].include?("charset=")
    res_encoding = res_headers["Content-Type"].match(/charset=([^;]*)/)[1]
    res.body.force_encoding(res_encoding)
    res.body = res.body.encode(res_encoding)
  end

  {
    :statusCode => res.code.to_i,
    :headers => res_headers,
    :body => res.body.nil? ? "" : res.body,
  }
end

def vc__handler(event:, context:)
  puts "MK HANDLER"
  payload = JSON.parse(event['body'])
  path = payload['path']
  headers = payload['headers']

  if ENV['VERCEL_DEBUG']
    puts 'Request Headers: '
    puts headers
  end

  httpMethod = payload['method']
  encoding = payload['encoding']
  body = payload['body']

  if (not body.nil? and not body.empty?) and (not encoding.nil? and encoding == 'base64')
    body = Base64.decode64(body)
  end

  if $entrypoint.end_with? '.ru'
    return rack_handler(httpMethod, path, body, headers)
  end

  return thin_handler(httpMethod, path, body, headers)
end
