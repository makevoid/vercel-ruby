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

  # Parse query string from path
  uri = URI.parse(path)
  query_string = uri.query || ''
  path_info = uri.path

  # Create WEBrick-compatible request object
  request = Object.new
  request.instance_variable_set(:@header, headers || {})
  request.instance_variable_set(:@query, Rack::Utils.parse_query(query_string))
  request.instance_variable_set(:@body, body)
  request.instance_variable_set(:@method, httpMethod)
  request.instance_variable_set(:@path, path_info)
  
  request.define_singleton_method(:query) do
    @query
  end
  request.define_singleton_method(:body) do
    @body
  end
  request.define_singleton_method(:request_method) do
    @method
  end
  request.define_singleton_method(:path) do
    @path
  end
  request.define_singleton_method(:header) do
    @header
  end
  
  # Create WEBrick-compatible response object
  response = Object.new
  response.instance_variable_set(:@header, {})
  response.instance_variable_set(:@status, 200)
  response.instance_variable_set(:@body, '')
  
  response.define_singleton_method(:status=) do |code|
    @status = code
  end
  response.define_singleton_method(:status) do
    @status
  end
  response.define_singleton_method(:header) do
    @header
  end
  response.define_singleton_method(:body=) do |content|
    @body = content
  end
  response.define_singleton_method(:body) do
    @body
  end
  response.define_singleton_method(:[]=) do |key, value|
    @header[key] = value
  end
  response.define_singleton_method(:[]) do |key|
    @header[key]
  end
  
  # Call the handler directly
  Handler.call(request, response)
  
  # Return the response
  {
    :statusCode => response.status,
    :headers => response.header,
    :body => response.body,
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
