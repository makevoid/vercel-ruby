require_relative 'html_extractor'

class UploadView
  def initialize(html_extractor)
    @extractor = html_extractor
  end

  def upload_form_html
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
          <title>HTML File Upload & Extraction</title>
          <style>
              body { font-family: Arial, sans-serif; margin: 40px; line-height: 1.6; }
              .container { max-width: 800px; margin: 0 auto; }
              .upload-area { 
                  border: 2px dashed #ccc; 
                  padding: 40px; 
                  text-align: center; 
                  margin: 20px 0;
                  background: #f9f9f9;
              }
              .file-list { margin: 20px 0; }
              .file-item { 
                  background: #f5f5f5; 
                  padding: 15px; 
                  margin: 10px 0; 
                  border-radius: 5px;
                  border-left: 4px solid #007cba;
              }
              .btn { 
                  background: #007cba; 
                  color: white; 
                  padding: 10px 20px; 
                  border: none; 
                  border-radius: 4px; 
                  cursor: pointer; 
                  margin: 5px;
              }
              .btn:hover { background: #005a87; }
              .btn-danger { background: #dc3545; }
              .btn-danger:hover { background: #c82333; }
              .extraction-content { 
                  background: #e9f7ff; 
                  padding: 15px; 
                  border-radius: 5px; 
                  margin: 10px 0; 
              }
              .meta-info { color: #666; font-size: 0.9em; }
              pre { background: #f4f4f4; padding: 10px; overflow-x: auto; }
          </style>
      </head>
      <body>
          <div class="container">
              <h1>HTML File Upload & Content Extraction</h1>
              
              <div class="upload-area">
                  <form action="/upload" method="post" enctype="multipart/form-data">
                      <h3>Upload HTML File</h3>
                      <input type="file" name="file" accept=".html,.htm" required>
                      <br><br>
                      <button type="submit" class="btn">Upload & Extract</button>
                  </form>
              </div>

              <div class="file-list">
                  <h2>Uploaded Files</h2>
                  <div id="files-container">
                      #{render_file_list}
                  </div>
              </div>
          </div>

          <script>
              function deleteFile(fileId) {
                  if (confirm('Are you sure you want to delete this file?')) {
                      fetch('/delete/' + fileId, { method: 'DELETE' })
                          .then(() => location.reload());
                  }
              }

              function viewFile(fileId) {
                  window.open('/view/' + fileId, '_blank');
              }
          </script>
      </body>
      </html>
    HTML
  end

  def file_view_html(file_id)
    file_data = @extractor.read_file(file_id)
    return not_found_html unless file_data

    metadata = file_data[:metadata]
    extracted = file_data[:extracted] || {}

    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
          <title>File View: #{metadata[:original_name]}</title>
          <style>
              body { font-family: Arial, sans-serif; margin: 40px; line-height: 1.6; }
              .container { max-width: 1000px; margin: 0 auto; }
              .section { 
                  background: #f9f9f9; 
                  padding: 20px; 
                  margin: 20px 0; 
                  border-radius: 5px; 
                  border-left: 4px solid #007cba;
              }
              .meta-info { color: #666; font-size: 0.9em; }
              pre { background: #f4f4f4; padding: 15px; overflow-x: auto; border-radius: 3px; }
              .btn { 
                  background: #007cba; 
                  color: white; 
                  padding: 8px 16px; 
                  text-decoration: none; 
                  border-radius: 4px; 
                  display: inline-block;
                  margin: 5px 0;
              }
              .extraction-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; }
              @media (max-width: 768px) { .extraction-grid { grid-template-columns: 1fr; } }
              .content-box { background: white; padding: 15px; border-radius: 5px; border: 1px solid #ddd; }
              ul { margin: 10px 0; padding-left: 20px; }
              .error { color: #dc3545; background: #f8d7da; padding: 10px; border-radius: 4px; }
          </style>
      </head>
      <body>
          <div class="container">
              <h1>File: #{metadata[:original_name]}</h1>
              
              <div class="meta-info">
                  <p><strong>Size:</strong> #{metadata[:size]} bytes</p>
                  <p><strong>Uploaded:</strong> #{metadata[:uploaded_at]}</p>
                  <a href="/" class="btn">← Back to Upload</a>
                  <a href="/raw/#{file_id}" class="btn">View Raw Content</a>
              </div>

              #{render_extraction_content(extracted)}
          </div>
      </body>
      </html>
    HTML
  end

  def raw_content_html(file_id)
    file_data = @extractor.read_file(file_id)
    return not_found_html unless file_data

    content = file_data[:content]
    metadata = file_data[:metadata]

    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
          <title>Raw Content: #{metadata[:original_name]}</title>
          <style>
              body { font-family: monospace; margin: 20px; line-height: 1.4; }
              .header { font-family: Arial, sans-serif; margin-bottom: 20px; }
              .btn { 
                  background: #007cba; 
                  color: white; 
                  padding: 8px 16px; 
                  text-decoration: none; 
                  border-radius: 4px; 
                  font-family: Arial, sans-serif;
              }
              pre { white-space: pre-wrap; word-wrap: break-word; }
          </style>
      </head>
      <body>
          <div class="header">
              <h1>Raw Content: #{metadata[:original_name]}</h1>
              <a href="/view/#{file_id}" class="btn">← Back to Extraction View</a>
          </div>
          <pre>#{escape_html(content)}</pre>
      </body>
      </html>
    HTML
  end

  def not_found_html
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
          <title>File Not Found</title>
          <style>
              body { font-family: Arial, sans-serif; margin: 40px; text-align: center; }
              .error { color: #dc3545; }
              .btn { 
                  background: #007cba; 
                  color: white; 
                  padding: 10px 20px; 
                  text-decoration: none; 
                  border-radius: 4px; 
              }
          </style>
      </head>
      <body>
          <h1 class="error">File Not Found</h1>
          <p>The requested file could not be found.</p>
          <a href="/" class="btn">← Back to Upload</a>
      </body>
      </html>
    HTML
  end

  private

  def render_file_list
    files = @extractor.list_files
    return "<p>No files uploaded yet.</p>" if files.empty?

    files.map do |file|
      extraction_status = file[:has_extraction] ? "✓ Extracted" : "No extraction"
      <<~HTML
        <div class="file-item">
            <h4>#{file[:name]}</h4>
            <div class="meta-info">
                Size: #{file[:size]} bytes | 
                Uploaded: #{file[:uploaded_at]} | 
                Status: #{extraction_status}
            </div>
            <button onclick="viewFile('#{file[:id]}')" class="btn">View</button>
            <button onclick="deleteFile('#{file[:id]}')" class="btn btn-danger">Delete</button>
        </div>
      HTML
    end.join
  end

  def render_extraction_content(extracted)
    return '<div class="error">No extraction data available</div>' if extracted.nil? || extracted.empty?

    if extracted[:error]
      return <<~HTML
        <div class="section">
            <h2>Extraction Error</h2>
            <div class="error">#{extracted[:error]}</div>
        </div>
      HTML
    end

    <<~HTML
      <div class="section">
          <h2>Extracted Content</h2>
          <div class="extraction-grid">
              <div class="content-box">
                  <h3>Basic Information</h3>
                  <p><strong>Title:</strong> #{extracted[:title] || 'No title'}</p>
                  <p><strong>Total Elements:</strong> #{extracted.dig(:structure, :total_elements) || 'Unknown'}</p>
              </div>
              
              <div class="content-box">
                  <h3>Structure Analysis</h3>
                  #{render_structure_info(extracted[:structure])}
              </div>
          </div>
          
          #{render_headings(extracted[:headings])}
          #{render_links(extracted[:links])}
          #{render_images(extracted[:images])}
          #{render_forms(extracted[:forms])}
          #{render_meta_tags(extracted[:meta_tags])}
      </div>
    HTML
  end

  def render_structure_info(structure)
    return "<p>No structure information</p>" unless structure

    <<~HTML
      <ul>
          <li>Divs: #{structure[:div_count] || 0}</li>
          <li>Spans: #{structure[:span_count] || 0}</li>
          <li>Tables: #{structure[:table_count] || 0}</li>
          <li>Lists: #{structure[:list_count] || 0}</li>
          <li>Scripts: #{structure[:script_count] || 0}</li>
          <li>Styles: #{structure[:style_count] || 0}</li>
      </ul>
    HTML
  end

  def render_headings(headings)
    return "" unless headings && headings.any?

    content = headings.map do |level, texts|
      "<h#{level + 2}>H#{level} Headings (#{texts.length})</h#{level + 2}><ul>" +
      texts.map { |text| "<li>#{escape_html(text)}</li>" }.join +
      "</ul>"
    end.join

    "<div class=\"content-box\"><h3>Headings</h3>#{content}</div>"
  end

  def render_links(links)
    return "" unless links && links.any?

    content = "<ul>" + links.first(10).map do |link|
      "<li><a href=\"#{escape_html(link[:href])}\">#{escape_html(link[:text])}</a></li>"
    end.join + "</ul>"

    content += "<p><em>Showing first 10 of #{links.length} links</em></p>" if links.length > 10

    "<div class=\"content-box\"><h3>Links (#{links.length})</h3>#{content}</div>"
  end

  def render_images(images)
    return "" unless images && images.any?

    content = "<ul>" + images.first(5).map do |img|
      "<li>#{escape_html(img[:src])} #{img[:alt] ? "(alt: #{escape_html(img[:alt])})" : ""}</li>"
    end.join + "</ul>"

    content += "<p><em>Showing first 5 of #{images.length} images</em></p>" if images.length > 5

    "<div class=\"content-box\"><h3>Images (#{images.length})</h3>#{content}</div>"
  end

  def render_forms(forms)
    return "" unless forms && forms.any?

    content = forms.map.with_index do |form, i|
      inputs = form[:inputs].map { |input| "#{input[:type]} (#{input[:name]})" }.join(", ")
      "<div><strong>Form #{i + 1}:</strong> #{form[:method]} #{form[:action]}<br>Inputs: #{inputs}</div>"
    end.join

    "<div class=\"content-box\"><h3>Forms (#{forms.length})</h3>#{content}</div>"
  end

  def render_meta_tags(meta_tags)
    return "" unless meta_tags && meta_tags.any?

    content = "<ul>" + meta_tags.first(10).map do |meta|
      identifier = meta[:name] || meta[:property] || 'charset'
      value = meta[:content] || meta[:charset] || 'N/A'
      "<li><strong>#{escape_html(identifier)}:</strong> #{escape_html(value)}</li>"
    end.join + "</ul>"

    "<div class=\"content-box\"><h3>Meta Tags (#{meta_tags.length})</h3>#{content}</div>"
  end

  def escape_html(text)
    return "" unless text
    text.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;').gsub('"', '&quot;').gsub("'", '&#39;')
  end
end