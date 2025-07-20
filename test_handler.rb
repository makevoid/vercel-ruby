class TestApp
  def call(env)
    request = Rack::Request.new(env)
    
    case request.path_info
    when '/'
      [200, {'Content-Type' => 'text/html'}, [index_html]]
    when '/api/rack/echo'
      handle_echo(request)
    when '/api/rack/upload'
      handle_rack_upload(request)
    when '/api/rack/form'
      handle_form(request)
    else
      [404, {'Content-Type' => 'text/plain'}, ['Not Found']]
    end
  end
  
  private
  
  def index_html
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
          <title>Rack Features Test</title>
          <style>
              body { font-family: Arial, sans-serif; margin: 40px; }
              .test-section { background: #f5f5f5; padding: 20px; margin: 20px 0; border-radius: 5px; }
              .btn { background: #007cba; color: white; padding: 10px 20px; border: none; border-radius: 4px; cursor: pointer; margin: 5px; }
              pre { background: #f4f4f4; padding: 10px; border-radius: 3px; overflow-x: auto; }
          </style>
      </head>
      <body>
          <h1>Rack Features Testing Interface</h1>
          
          <div class="test-section">
              <h2>File Upload & HTML Extraction</h2>
              <p>The enhanced handler provides built-in HTML file upload and extraction:</p>
              <ul>
                  <li><strong>POST /upload</strong> - Upload HTML files</li>
                  <li><strong>GET /view/{id}</strong> - View extracted content</li>
                  <li><strong>GET /raw/{id}</strong> - View raw file content</li>
                  <li><strong>DELETE /delete/{id}</strong> - Delete uploaded file</li>
              </ul>
              <button onclick="window.open('/', '_blank')" class="btn">Open Upload Interface</button>
          </div>
          
          <div class="test-section">
              <h2>API Testing Endpoints</h2>
              <p>Test various Rack features through these endpoints:</p>
              <ul>
                  <li><strong>GET /api/files</strong> - List uploaded files</li>
                  <li><strong>POST /api/files</strong> - Create test HTML file</li>
                  <li><strong>GET /api/test/headers</strong> - Test header handling</li>
                  <li><strong>GET/POST /api/test/methods</strong> - Test HTTP methods</li>
                  <li><strong>POST /api/test/json</strong> - Test JSON parsing</li>
                  <li><strong>GET /api/test/session</strong> - Test session handling</li>
                  <li><strong>GET /api/test/cookies</strong> - Test cookie handling</li>
                  <li><strong>GET /api/test/middleware</strong> - Test middleware simulation</li>
                  <li><strong>GET /api/test/params/{value}</strong> - Test path parameters</li>
              </ul>
          </div>
          
          <div class="test-section">
              <h2>Pure Rack Endpoints</h2>
              <p>These endpoints demonstrate standard Rack application features:</p>
              <ul>
                  <li><strong>POST /api/rack/echo</strong> - Echo request data</li>
                  <li><strong>POST /api/rack/upload</strong> - Handle file uploads via Rack</li>
                  <li><strong>GET/POST /api/rack/form</strong> - Form handling example</li>
              </ul>
          </div>
          
          <div class="test-section">
              <h2>Quick Tests</h2>
              <button onclick="testEndpoint('/api/test/headers', 'GET')" class="btn">Test Headers</button>
              <button onclick="testEndpoint('/api/test/methods', 'POST')" class="btn">Test Methods</button>
              <button onclick="testEndpoint('/api/test/session', 'GET')" class="btn">Test Session</button>
              <button onclick="testEndpoint('/api/test/cookies', 'GET')" class="btn">Test Cookies</button>
              <button onclick="testEndpoint('/api/files', 'GET')" class="btn">List Files</button>
              
              <div id="test-results" style="margin-top: 20px;"></div>
          </div>
          
          <script>
              async function testEndpoint(path, method) {
                  const resultsDiv = document.getElementById('test-results');
                  resultsDiv.innerHTML = '<p>Testing ' + method + ' ' + path + '...</p>';
                  
                  try {
                      const response = await fetch(path, { 
                          method: method,
                          headers: {
                              'Content-Type': 'application/json'
                          }
                      });
                      const data = await response.json();
                      resultsDiv.innerHTML = '<h3>Results for ' + method + ' ' + path + ':</h3><pre>' + 
                                           JSON.stringify(data, null, 2) + '</pre>';
                  } catch (error) {
                      resultsDiv.innerHTML = '<p style="color: red;">Error: ' + error.message + '</p>';
                  }
              }
          </script>
      </body>
      </html>
    HTML
  end
  
  def handle_echo(request)
    response_data = {
      method: request.request_method,
      path: request.path_info,
      query_string: request.query_string,
      headers: request.env.select { |k, v| k.start_with?('HTTP_') },
      params: request.params,
      body: request.body.read,
      content_type: request.content_type,
      content_length: request.content_length,
      timestamp: Time.now.iso8601
    }
    
    [200, {'Content-Type' => 'application/json'}, [response_data.to_json]]
  end
  
  def handle_rack_upload(request)
    if request.post?
      files = []
      
      request.params.each do |key, value|
        if value.is_a?(Hash) && value[:tempfile]
          # Handle uploaded file
          tempfile = value[:tempfile]
          filename = value[:filename]
          content_type = value[:type]
          
          file_content = tempfile.read
          tempfile.rewind
          
          files << {
            field_name: key,
            filename: filename,
            content_type: content_type,
            size: file_content.length,
            content_preview: file_content[0..100] + (file_content.length > 100 ? '...' : '')
          }
        end
      end
      
      response_data = {
        message: 'Files processed via Rack',
        files_count: files.length,
        files: files,
        all_params: request.params.keys,
        timestamp: Time.now.iso8601
      }
      
      [200, {'Content-Type' => 'application/json'}, [response_data.to_json]]
    else
      [405, {'Content-Type' => 'application/json'}, [{ error: 'Method not allowed' }.to_json]]
    end
  end
  
  def handle_form(request)
    if request.get?
      form_html = <<~HTML
        <!DOCTYPE html>
        <html>
        <head><title>Rack Form Test</title></head>
        <body>
            <h1>Rack Form Handling Test</h1>
            <form action="/api/rack/form" method="post" enctype="multipart/form-data">
                <p>
                    <label>Name: <input type="text" name="name" required></label>
                </p>
                <p>
                    <label>Email: <input type="email" name="email" required></label>
                </p>
                <p>
                    <label>Message: <textarea name="message" rows="4" cols="50"></textarea></label>
                </p>
                <p>
                    <label>File: <input type="file" name="attachment"></label>
                </p>
                <p>
                    <input type="submit" value="Submit via Rack">
                </p>
            </form>
        </body>
        </html>
      HTML
      
      [200, {'Content-Type' => 'text/html'}, [form_html]]
    elsif request.post?
      form_data = {
        name: request.params['name'],
        email: request.params['email'],
        message: request.params['message'],
        timestamp: Time.now.iso8601
      }
      
      # Handle file attachment if present
      if request.params['attachment'] && request.params['attachment'][:tempfile]
        attachment = request.params['attachment']
        form_data[:attachment] = {
          filename: attachment[:filename],
          content_type: attachment[:type],
          size: attachment[:tempfile].size
        }
      end
      
      response_html = <<~HTML
        <!DOCTYPE html>
        <html>
        <head><title>Form Submission Result</title></head>
        <body>
            <h1>Form Processed Successfully via Rack</h1>
            <pre>#{JSON.pretty_generate(form_data)}</pre>
            <a href="/api/rack/form">← Back to Form</a>
        </body>
        </html>
      HTML
      
      [200, {'Content-Type' => 'text/html'}, [response_html]]
    end
  end
end