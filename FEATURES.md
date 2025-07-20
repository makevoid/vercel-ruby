# Enhanced Rack Handler Features

This document describes the enhanced features added to the Vercel Ruby runtime for HTML extraction and comprehensive Rack API testing.

## Overview

The enhanced Rack handler extends the original functionality with:

1. **HTML File Upload & Extraction** - Upload HTML files and automatically extract content structure
2. **Comprehensive API Testing** - Test various Rack features through dedicated endpoints
3. **File Management** - Manage uploaded files through API
4. **Session & Cookie Handling** - Test session and cookie functionality
5. **Middleware Simulation** - Simulate middleware behavior for testing

## File Structure

```
├── views/
│   └── uploads/
│       ├── html_extractor.rb    # HTML content extraction logic
│       └── upload_view.rb       # Web interface for file uploads
├── vc_init.rb                   # Enhanced main runtime with new features
├── test.ru                      # Example Rack application
├── test_handler.rb              # Example Rack app implementation
├── example_handler.rb           # Example custom handler
└── Gemfile                      # Ruby dependencies
```

## HTML File Upload & Extraction

### Features

- Upload HTML files via web interface
- Extract structured content including:
  - Document title and headings (H1-H6)
  - Links and images with metadata
  - Forms and input elements
  - Meta tags and document structure
  - Raw text content
- View extracted content in organized format
- Access raw file content
- Delete uploaded files

### Endpoints

- `GET /` - Upload interface
- `POST /upload` - Handle file uploads
- `GET /view/{file_id}` - View extracted content
- `GET /raw/{file_id}` - View raw file content
- `DELETE /delete/{file_id}` - Delete file

### Usage Example

```ruby
# Access the global HTML extractor
html_extractor = $html_extractor

# Upload a file
file_id = html_extractor.handle_upload(file_content, 'example.html')

# Read extracted content
file_data = html_extractor.read_file(file_id)
extracted = file_data[:extracted]

# Access specific extracted elements
title = extracted[:title]
headings = extracted[:headings]
links = extracted[:links]
```

## API Testing Endpoints

### Available Endpoints

#### File Management
- `GET /api/files` - List all uploaded files
- `POST /api/files` - Create a test HTML file

#### Request Testing
- `GET /api/test/headers` - Test header handling
- `GET/POST /api/test/methods` - Test HTTP method handling
- `POST /api/test/json` - Test JSON request/response parsing

#### Session & Cookies
- `GET /api/test/session` - Test session handling with automatic session ID generation
- `GET /api/test/cookies` - Test cookie setting and reading

#### Advanced Features
- `GET /api/test/middleware` - Simulate middleware stack behavior
- `GET /api/test/params/{value}` - Test path parameter extraction

### Example API Responses

#### Headers Test
```bash
curl -H "Custom-Header: test-value" http://localhost/api/test/headers
```

```json
{
  "message": "Headers received successfully",
  "received_headers": {
    "custom-header": "test-value",
    "user-agent": "curl/7.68.0"
  },
  "header_count": 2,
  "timestamp": "2024-01-20T10:30:00Z"
}
```

#### JSON Test
```bash
curl -X POST -H "Content-Type: application/json" \
  -d '{"name": "test", "value": 123}' \
  http://localhost/api/test/json
```

```json
{
  "method": "POST",
  "content_type": "application/json",
  "received_json": {
    "name": "test",
    "value": 123
  },
  "json_valid": true,
  "timestamp": "2024-01-20T10:30:00Z"
}
```

#### Session Test
```bash
curl -c cookies.txt -b cookies.txt http://localhost/api/test/session
```

```json
{
  "session_id": "abc123def456",
  "method": "GET",
  "message": "Session handling test",
  "has_existing_session": false,
  "timestamp": "2024-01-20T10:30:00Z"
}
```

## Custom Handler Integration

The enhanced handler is backward compatible and can be used alongside custom handlers:

```ruby
# In your custom handler file
Handler = Proc.new do |request, response|
  case request.path_info
  when '/custom'
    # Your custom logic
    response.status = 200
    response.body = 'Custom response'
  else
    # Enhanced features are still available
    # The enhanced_rack_handler will handle built-in routes
  end
end
```

## Dependencies

Add these gems to your Gemfile:

```ruby
gem 'rack', '~> 2.2'
gem 'nokogiri', '~> 1.13'  # For HTML parsing
gem 'webrick', '~> 1.7'   # For WEBrick compatibility
```

## Testing with Rack Applications

Example Rack application (`test.ru`):

```ruby
require_relative 'test_handler'

run TestApp.new
```

The test handler provides additional endpoints for pure Rack feature testing:

- `POST /api/rack/echo` - Echo all request data
- `POST /api/rack/upload` - Handle file uploads via Rack
- `GET/POST /api/rack/form` - Form handling example

## Usage Scenarios

### 1. HTML Content Analysis
Upload HTML files to analyze their structure, extract metadata, and identify elements for processing.

### 2. API Development & Testing
Use the comprehensive testing endpoints to verify HTTP method handling, header processing, JSON parsing, and session management.

### 3. Middleware Development
Test middleware behavior using the simulation endpoints to verify request processing pipelines.

### 4. File Processing Workflows
Build file upload and processing workflows with automatic content extraction and metadata generation.

## Error Handling

The enhanced handler includes comprehensive error handling:

- Invalid content types return appropriate HTTP status codes
- File upload errors are caught and returned as JSON responses
- Missing files return 404 responses
- Malformed requests return 400 responses with error details

## Security Considerations

- File uploads are stored in temporary directories
- Sensitive parameters are filtered from logs
- File content is escaped when displayed in HTML
- Session IDs are generated securely using SecureRandom

## Performance Notes

- HTML extraction uses Nokogiri for efficient parsing
- File storage uses temporary directories for automatic cleanup
- Request logging includes timing information
- Large files are handled with streaming where possible