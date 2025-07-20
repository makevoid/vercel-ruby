require 'tmpdir'
require 'net/http'
require 'base64'
require 'json'
require 'webrick'
require 'securerandom'
require_relative 'views/uploads/html_extractor'
require_relative 'views/uploads/upload_view'

$entrypoint = '__VC_HANDLER_FILENAME'

ENV['RAILS_ENV'] ||= 'production'
ENV['RACK_ENV'] ||= 'production'
ENV['RAILS_LOG_TO_STDOUT'] ||= '1'

def rack_mock_handler(httpMethod, path, body, headers)
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
  status_display = case response.status
  when 200..299 then "✓ #{response.status}"
  when 300..399 then "→ #{response.status}"
  when 400..499 then "✗ #{response.status}"
  when 500..599 then "! #{response.status}"
  else response.status.to_s
  end

  # Format and print log as one line
  puts "[#{timestamp}] #{request.request_method} #{request.path_info} #{status_display} #{duration_ms}ms#{params_str}"

  # Return the response
  {
    :statusCode => response.status,
    :headers => response.header,
    :body => response.body,
  }
end

# Global instances for file handling
$html_extractor = HtmlExtractor.new
$upload_view = UploadView.new($html_extractor)

def enhanced_rack_handler(httpMethod, path, body, headers)
  # Handle built-in routes for file upload and testing
  case path
  when '/'
    return {
      :statusCode => 200,
      :headers => { 'Content-Type' => 'text/html' },
      :body => $upload_view.upload_form_html
    }
  
  when '/upload'
    if httpMethod == 'POST'
      return handle_file_upload(body, headers)
    else
      return {
        :statusCode => 405,
        :headers => { 'Content-Type' => 'text/plain' },
        :body => 'Method Not Allowed'
      }
    end
  
  when %r{^/view/(.+)$}
    file_id = $1
    return {
      :statusCode => 200,
      :headers => { 'Content-Type' => 'text/html' },
      :body => $upload_view.file_view_html(file_id)
    }
  
  when %r{^/raw/(.+)$}
    file_id = $1
    return {
      :statusCode => 200,
      :headers => { 'Content-Type' => 'text/html' },
      :body => $upload_view.raw_content_html(file_id)
    }
  
  when %r{^/delete/(.+)$}
    if httpMethod == 'DELETE'
      file_id = $1
      success = $html_extractor.delete_file(file_id)
      return {
        :statusCode => success ? 200 : 404,
        :headers => { 'Content-Type' => 'application/json' },
        :body => { success: success }.to_json
      }
    end
  
  # API endpoints for testing Rack features
  when '/api/files'
    return handle_files_api(httpMethod, body)
  
  when '/api/test/headers'
    return test_headers_api(headers)
  
  when '/api/test/methods'
    return test_methods_api(httpMethod)
  
  when '/api/test/json'
    return test_json_api(httpMethod, body, headers)
  
  when '/api/test/session'
    return test_session_api(httpMethod, headers)
  
  when '/api/test/cookies'
    return test_cookies_api(httpMethod, headers)
  
  when '/api/test/middleware'
    return test_middleware_api(httpMethod, path, headers)
  
  when %r{^/api/test/params/(.+)$}
    param_value = $1
    return test_params_api(param_value, headers)
  
  end

  # If no built-in route matches, fall back to original rack_handler
  rack_handler(httpMethod, path, body, headers)
end

def handle_file_upload(body, headers)
  content_type = headers['content-type'] || headers['Content-Type']
  
  unless content_type&.include?('multipart/form-data')
    return {
      :statusCode => 400,
      :headers => { 'Content-Type' => 'application/json' },
      :body => { error: 'Invalid content type. Expected multipart/form-data' }.to_json
    }
  end

  begin
    # Parse multipart data (simplified)
    boundary = content_type.match(/boundary=(.+)$/)[1]
    parts = body.split("--#{boundary}")
    
    file_part = parts.find { |part| part.include?('filename=') }
    
    if file_part
      # Extract filename
      filename_match = file_part.match(/filename="([^"]+)"/)
      filename = filename_match ? filename_match[1] : 'uploaded_file.html'
      
      # Extract file content (simplified extraction)
      content_start = file_part.index("\r\n\r\n")
      if content_start
        file_content = file_part[(content_start + 4)..-1]
        file_content = file_content.gsub(/\r\n--.*\z/, '') # Remove trailing boundary
        
        file_id = $html_extractor.handle_upload(file_content, filename)
        
        if file_id
          return {
            :statusCode => 302,
            :headers => { 'Location' => "/view/#{file_id}" },
            :body => ''
          }
        end
      end
    end
    
    return {
      :statusCode => 400,
      :headers => { 'Content-Type' => 'application/json' },
      :body => { error: 'No file uploaded or invalid file format' }.to_json
    }
    
  rescue => e
    return {
      :statusCode => 500,
      :headers => { 'Content-Type' => 'application/json' },
      :body => { error: "Upload failed: #{e.message}" }.to_json
    }
  end
end

def handle_files_api(method, body)
  case method
  when 'GET'
    files = $html_extractor.list_files
    return {
      :statusCode => 200,
      :headers => { 'Content-Type' => 'application/json' },
      :body => { files: files }.to_json
    }
  
  when 'POST'
    # Create a test HTML file
    test_content = body || '<html><head><title>Test</title></head><body><h1>Test Content</h1></body></html>'
    file_id = $html_extractor.handle_upload(test_content, 'test.html')
    
    return {
      :statusCode => 201,
      :headers => { 'Content-Type' => 'application/json' },
      :body => { file_id: file_id, message: 'File created successfully' }.to_json
    }
  
  else
    return {
      :statusCode => 405,
      :headers => { 'Content-Type' => 'application/json' },
      :body => { error: 'Method not allowed' }.to_json
    }
  end
end

def test_headers_api(headers)
  {
    :statusCode => 200,
    :headers => { 'Content-Type' => 'application/json' },
    :body => {
      message: 'Headers received successfully',
      received_headers: headers,
      header_count: headers&.length || 0,
      timestamp: Time.now.iso8601
    }.to_json
  }
end

def test_methods_api(method)
  {
    :statusCode => 200,
    :headers => { 'Content-Type' => 'application/json' },
    :body => {
      method: method,
      supported_methods: %w[GET POST PUT DELETE PATCH HEAD OPTIONS],
      is_safe: %w[GET HEAD OPTIONS].include?(method),
      is_idempotent: %w[GET HEAD PUT DELETE OPTIONS].include?(method),
      timestamp: Time.now.iso8601
    }.to_json
  }
end

def test_json_api(method, body, headers)
  content_type = headers['content-type'] || headers['Content-Type'] || ''
  
  response_data = {
    method: method,
    content_type: content_type,
    timestamp: Time.now.iso8601
  }

  if method == 'POST' || method == 'PUT' || method == 'PATCH'
    if content_type.include?('application/json') && body
      begin
        parsed_body = JSON.parse(body)
        response_data[:received_json] = parsed_body
        response_data[:json_valid] = true
      rescue JSON::ParserError => e
        response_data[:json_error] = e.message
        response_data[:json_valid] = false
        response_data[:raw_body] = body
      end
    else
      response_data[:raw_body] = body
      response_data[:message] = 'Body received but not parsed as JSON'
    end
  end

  {
    :statusCode => 200,
    :headers => { 'Content-Type' => 'application/json' },
    :body => response_data.to_json
  }
end

def test_session_api(method, headers)
  # Simulate session handling
  session_id = headers['cookie']&.match(/session_id=([^;]+)/)&.captures&.first || SecureRandom.hex(16)
  
  response_headers = { 'Content-Type' => 'application/json' }
  
  # Set session cookie if not present
  unless headers['cookie']&.include?('session_id=')
    response_headers['Set-Cookie'] = "session_id=#{session_id}; Path=/; HttpOnly"
  end

  {
    :statusCode => 200,
    :headers => response_headers,
    :body => {
      session_id: session_id,
      method: method,
      message: 'Session handling test',
      has_existing_session: !!(headers['cookie']&.include?('session_id=')),
      timestamp: Time.now.iso8601
    }.to_json
  }
end

def test_cookies_api(method, headers)
  cookies = {}
  if headers['cookie']
    headers['cookie'].split(';').each do |cookie|
      key, value = cookie.strip.split('=', 2)
      cookies[key] = value if key && value
    end
  end

  response_headers = { 'Content-Type' => 'application/json' }
  
  # Set a test cookie
  test_cookie_value = Time.now.to_i.to_s
  response_headers['Set-Cookie'] = "test_cookie=#{test_cookie_value}; Path=/; Max-Age=3600"

  {
    :statusCode => 200,
    :headers => response_headers,
    :body => {
      received_cookies: cookies,
      cookie_count: cookies.length,
      test_cookie_set: test_cookie_value,
      method: method,
      timestamp: Time.now.iso8601
    }.to_json
  }
end

def test_middleware_api(method, path, headers)
  # Simulate middleware behavior
  middleware_data = {
    request_id: SecureRandom.hex(8),
    method: method,
    path: path,
    user_agent: headers['user-agent'] || headers['User-Agent'],
    accept: headers['accept'] || headers['Accept'],
    middleware_stack: [
      'LoggingMiddleware',
      'AuthenticationMiddleware', 
      'CORSMiddleware',
      'RateLimitMiddleware'
    ],
    processing_time_ms: rand(10..100),
    timestamp: Time.now.iso8601
  }

  {
    :statusCode => 200,
    :headers => { 
      'Content-Type' => 'application/json',
      'X-Request-ID' => middleware_data[:request_id],
      'X-Processing-Time' => "#{middleware_data[:processing_time_ms]}ms"
    },
    :body => middleware_data.to_json
  }
end

def test_params_api(param_value, headers)
  {
    :statusCode => 200,
    :headers => { 'Content-Type' => 'application/json' },
    :body => {
      path_param: param_value,
      param_length: param_value.length,
      param_type: param_value.match?(/^\d+$/) ? 'numeric' : 'string',
      query_params_note: 'Query params would be parsed from request URL',
      timestamp: Time.now.iso8601
    }.to_json
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

  return enhanced_rack_handler(httpMethod, path, body, headers)
end
