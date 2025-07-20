require_relative 'vc_init'

# Example handler that demonstrates the enhanced Rack functionality
Handler = Proc.new do |request, response|
  case request.path_info
  when '/'
    response.status = 200
    response['Content-Type'] = 'text/html'
    response.body = <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
          <title>Enhanced Rack Handler Demo</title>
          <style>
              body { font-family: Arial, sans-serif; margin: 40px; line-height: 1.6; }
              .feature-box { background: #f5f5f5; padding: 20px; margin: 20px 0; border-radius: 5px; }
              .btn { background: #007cba; color: white; padding: 10px 20px; text-decoration: none; border-radius: 4px; display: inline-block; margin: 5px; }
              pre { background: #f4f4f4; padding: 10px; border-radius: 3px; overflow-x: auto; }
          </style>
      </head>
      <body>
          <h1>Enhanced Rack Handler Features</h1>
          
          <div class="feature-box">
              <h2>1. HTML File Upload & Extraction</h2>
              <p>Upload HTML files and extract content automatically:</p>
              <a href="/upload-demo" class="btn">Try Upload Feature</a>
              <ul>
                  <li>Extracts headings, links, images, forms</li>
                  <li>Analyzes document structure</li>
                  <li>Provides metadata and raw content access</li>
              </ul>
          </div>
          
          <div class="feature-box">
              <h2>2. Comprehensive API Testing</h2>
              <p>Test various Rack features:</p>
              <a href="/api/test/headers" class="btn">Test Headers</a>
              <a href="/api/test/methods" class="btn">Test Methods</a>
              <a href="/api/test/session" class="btn">Test Session</a>
              <a href="/api/test/cookies" class="btn">Test Cookies</a>
          </div>
          
          <div class="feature-box">
              <h2>3. File Management API</h2>
              <p>Manage uploaded files via API:</p>
              <a href="/api/files" class="btn">List Files</a>
              <button onclick="createTestFile()" class="btn">Create Test File</button>
          </div>
          
          <div class="feature-box">
              <h2>4. Custom Handler Response</h2>
              <p>This page is served by a custom Rack handler demonstrating:</p>
              <ul>
                  <li>Request routing</li>
                  <li>Response customization</li>
                  <li>Integration with enhanced features</li>
              </ul>
              <pre>Method: #{request.request_method}
Path: #{request.path_info}
Query: #{request.query_string}
User-Agent: #{request.get_header('HTTP_USER_AGENT')}</pre>
          </div>
          
          <script>
              async function createTestFile() {
                  try {
                      const response = await fetch('/api/files', {
                          method: 'POST',
                          headers: { 'Content-Type': 'text/html' },
                          body: '<html><head><title>Generated Test</title></head><body><h1>Test File</h1><p>This is a test file created via API.</p></body></html>'
                      });
                      const result = await response.json();
                      alert('Test file created with ID: ' + result.file_id);
                      window.open('/view/' + result.file_id, '_blank');
                  } catch (error) {
                      alert('Error creating test file: ' + error.message);
                  }
              }
          </script>
      </body>
      </html>
    HTML
    
  when '/upload-demo'
    response.status = 200
    response['Content-Type'] = 'text/html'
    response.body = <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
          <title>Upload Demo</title>
          <style>
              body { font-family: Arial, sans-serif; margin: 40px; }
              .upload-area { border: 2px dashed #ccc; padding: 40px; text-align: center; background: #f9f9f9; }
              .btn { background: #007cba; color: white; padding: 10px 20px; border: none; border-radius: 4px; cursor: pointer; }
          </style>
      </head>
      <body>
          <h1>HTML File Upload Demo</h1>
          <div class="upload-area">
              <form action="/upload" method="post" enctype="multipart/form-data">
                  <h3>Upload an HTML file to see extraction in action</h3>
                  <input type="file" name="file" accept=".html,.htm" required>
                  <br><br>
                  <button type="submit" class="btn">Upload & Extract Content</button>
              </form>
          </div>
          <p><a href="/">← Back to Main Demo</a></p>
      </body>
      </html>
    HTML
    
  when '/api/custom/demo'
    response.status = 200
    response['Content-Type'] = 'application/json'
    response.body = {
      message: 'Custom handler API endpoint',
      timestamp: Time.now.iso8601,
      request_info: {
        method: request.request_method,
        path: request.path_info,
        query: request.query_string,
        headers: request.env.select { |k, v| k.start_with?('HTTP_') }.transform_keys { |k| k.sub(/^HTTP_/, '').downcase },
        params: request.params
      },
      enhanced_features: [
        'HTML file upload and extraction',
        'Comprehensive API testing endpoints',
        'Session and cookie handling',
        'Middleware simulation',
        'File management API'
      ]
    }.to_json
    
  else
    # Fall back to enhanced handler for all other routes
    # This demonstrates how custom handlers can coexist with enhanced features
    response.status = 404
    response['Content-Type'] = 'text/html'
    response.body = <<~HTML
      <!DOCTYPE html>
      <html>
      <head><title>Not Found</title></head>
      <body>
          <h1>Custom Handler: Route Not Found</h1>
          <p>The requested path "#{request.path_info}" was not found in the custom handler.</p>
          <p>However, enhanced features are still available:</p>
          <ul>
              <li><a href="/">File Upload Interface</a></li>
              <li><a href="/api/test/headers">API Testing</a></li>
              <li><a href="/api/files">File Management</a></li>
          </ul>
          <p><a href="/">← Return to Demo</a></p>
      </body>
      </html>
    HTML
  end
end