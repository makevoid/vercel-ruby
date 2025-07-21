require 'tmpdir'
require 'net/http'
require 'base64'
require 'json'
require 'webrick'

$entrypoint = '__VC_HANDLER_FILENAME'

ENV['RAILS_ENV'] ||= 'production'
ENV['RACK_ENV'] ||= 'production'
ENV['RAILS_LOG_TO_STDOUT'] ||= '1'

def rack_mock_handler(httpMethod, path, body, headers)
  require 'rack'

  app, _ = Rack::Builder.parse_file($entrypoint)
  
  # Build proper Rack environment
  env = Rack::MockRequest.env_for(path, {
    :method => httpMethod,
    :input => body
  })
  
  # Add headers to environment
  if headers
    headers.each do |key, value|
      env_key = "HTTP_#{key.upcase.gsub('-', '_')}"
      env[env_key] = value
    end
  end
  
  # Call the Rack app
  status, response_headers, response_body = app.call(env)
  
  # Collect body if it's an enumerable
  body_string = ""
  response_body.each { |part| body_string << part.to_s }
  response_body.close if response_body.respond_to?(:close)
  
  {
    :statusCode => status,
    :headers => response_headers,
    :body => body_string,
  }
end

def rack_handler(httpMethod, path, body, headers)
  require_relative $entrypoint
  require 'rack'
  require 'stringio'

  if not Object.const_defined?('Handler')
    return { :statusCode => 500, :body => 'Handler not defined in lambda' }
  end

  # Parse query string from path
  uri = URI.parse(path)
  query_string = uri.query || ''
  path_info = uri.path

  # Build Rack environment
  env = {
    'REQUEST_METHOD' => httpMethod,
    'PATH_INFO' => path_info,
    'QUERY_STRING' => query_string,
    'SERVER_NAME' => 'localhost',
    'SERVER_PORT' => '80',
    'rack.version' => [1, 3],
    'rack.url_scheme' => 'http',
    'rack.input' => StringIO.new(body || ''),
    'rack.errors' => $stderr,
    'rack.multithread' => false,
    'rack.multiprocess' => true,
    'rack.run_once' => false
  }

  # Add headers to environment
  if headers
    headers.each do |key, value|
      # Convert header names to CGI format
      env_key = "HTTP_#{key.upcase.gsub('-', '_')}"
      env[env_key] = value
    end
  end

  # Create Rack::Request
  request = Rack::Request.new(env)

  # Add WEBrick-compatible query method
  request.define_singleton_method(:query) do
    @webrick_query ||= begin
      if @env['REQUEST_METHOD'] == "GET" || @env['REQUEST_METHOD'] == "HEAD"
        WEBrick::HTTPUtils::parse_query(@env['QUERY_STRING'] || '')
      elsif get_header('CONTENT_TYPE') =~ /^application\/x-www-form-urlencoded/
        body_content = body.read
        body.rewind
        WEBrick::HTTPUtils::parse_query(body_content)
      elsif get_header('CONTENT_TYPE') =~ /^multipart\/form-data; boundary=(.+)/
        # For multipart, just return params from Rack
        params
      else
        {}
      end
    rescue => ex
      {}
    end
  end

  # Support both [] and get_header methods for header access
  request.define_singleton_method(:[]) do |key|
    if key =~ /^content-type$/i
      get_header('CONTENT_TYPE')
    else
      get_header("HTTP_#{key.upcase.gsub('-', '_')}")
    end
  end

  # Create Rack::Response object
  response = Rack::Response.new
  
  # Add WEBrick-compatible methods to Rack::Response
  response.define_singleton_method(:header) do
    headers
  end
  
  # Override []= to work with both Rack::Response and WEBrick style
  response.define_singleton_method(:[]=) do |key, value|
    set_header(key, value)
  end
  
  response.define_singleton_method(:[]) do |key|
    get_header(key)
  end

  # Log request start
  request_start = Time.now

  # Call the handler directly
  Handler.call(request, response)

  # Log request completion
  request_end = Time.now
  duration_ms = ((request_end - request_start) * 1000).round(2)

  # Filter sensitive parameters
  sensitive_keys = %w[password pass secret token key api_key access_token refresh_token auth authorization session csrf]
  filtered_params = {}

  begin
    params_to_filter = request.params || {}
    params_to_filter.each do |key, value|
      if sensitive_keys.any? { |sensitive| key.to_s.downcase.include?(sensitive) }
        filtered_params[key] = "[FILTERED]"
      elsif value.is_a?(Hash)
        # Recursively filter nested hashes
        filtered_params[key] = value.transform_keys(&:to_s).transform_values do |v|
          if v.is_a?(String) && sensitive_keys.any? { |sensitive| key.to_s.downcase.include?(sensitive) }
            "[FILTERED]"
          else
            v
          end
        end
      else
        filtered_params[key] = value
      end
    end
  rescue => e
    filtered_params = { "error_filtering_params" => e.message }
  end

  # Format params for logging
  params_str = if !filtered_params.empty?
    # Convert params to compact string representation
    params_display = filtered_params.map { |k, v|
      value = if v.is_a?(Hash)
        "{...}"
      else
        str = v.to_s
        str.length > 20 ? "#{str[0..17]}..." : str
      end
      "#{k}=#{value}"
    }.join(" ")
    " | #{params_display}"
  else
    ""
  end

  # Format timestamp
  timestamp = request_start.strftime("%H:%M:%S")

  # Status color codes (for terminal output)
  current_status = response.status
  status_display = case current_status
  when 200..299 then "✓ #{current_status}"
  when 300..399 then "→ #{current_status}"
  when 400..499 then "✗ #{current_status}"
  when 500..599 then "! #{current_status}"
  else current_status.to_s
  end

  # Format and print log as one line
  puts "[#{timestamp}] #{request.request_method} #{request.path_info} #{status_display} #{duration_ms}ms#{params_str}"

  # Return the response
  # Finalize the Rack::Response to get headers and body
  status, headers, body_parts = response.finish
  
  # Collect body parts into a string
  body_string = ""
  body_parts.each { |part| body_string << part.to_s }
  
  {
    :statusCode => status,
    :headers => headers,
    :body => body_string,
  }
end

def vc__handler(event:, context:)
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
    return rack_mock_handler(httpMethod, path, body, headers)
  end

  return rack_handler(httpMethod, path, body, headers)
end
