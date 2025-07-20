require 'nokogiri'
require 'tempfile'
require 'fileutils'

class HtmlExtractor
  attr_reader :uploaded_files, :extracted_content

  def initialize
    @uploaded_files = {}
    @extracted_content = {}
    @uploads_dir = File.join(Dir.tmpdir, 'vercel_uploads')
    FileUtils.mkdir_p(@uploads_dir)
  end

  def handle_upload(file_param, original_filename = nil)
    return nil unless file_param

    file_id = SecureRandom.hex(16)
    filename = original_filename || "upload_#{file_id}.html"
    file_path = File.join(@uploads_dir, "#{file_id}_#{filename}")

    # Write file content
    if file_param.respond_to?(:read)
      File.open(file_path, 'wb') { |f| f.write(file_param.read) }
    elsif file_param.is_a?(String)
      File.open(file_path, 'w') { |f| f.write(file_param) }
    else
      return nil
    end

    @uploaded_files[file_id] = {
      path: file_path,
      original_name: filename,
      uploaded_at: Time.now,
      size: File.size(file_path)
    }

    # Extract HTML content if it's an HTML file
    if filename.downcase.end_with?('.html', '.htm')
      extract_html_content(file_id)
    end

    file_id
  end

  def extract_html_content(file_id)
    file_info = @uploaded_files[file_id]
    return nil unless file_info

    content = File.read(file_info[:path])
    
    begin
      doc = Nokogiri::HTML(content)
      
      @extracted_content[file_id] = {
        title: doc.at_css('title')&.text&.strip,
        headings: extract_headings(doc),
        paragraphs: extract_paragraphs(doc),
        links: extract_links(doc),
        images: extract_images(doc),
        forms: extract_forms(doc),
        meta_tags: extract_meta_tags(doc),
        raw_text: doc.text.strip,
        structure: analyze_structure(doc)
      }
    rescue => e
      @extracted_content[file_id] = { error: e.message }
    end

    @extracted_content[file_id]
  end

  def read_file(file_id)
    file_info = @uploaded_files[file_id]
    return nil unless file_info

    {
      content: File.read(file_info[:path]),
      metadata: file_info,
      extracted: @extracted_content[file_id]
    }
  end

  def list_files
    @uploaded_files.map do |id, info|
      {
        id: id,
        name: info[:original_name],
        size: info[:size],
        uploaded_at: info[:uploaded_at],
        has_extraction: @extracted_content.key?(id)
      }
    end
  end

  def delete_file(file_id)
    file_info = @uploaded_files[file_id]
    return false unless file_info

    File.delete(file_info[:path]) if File.exist?(file_info[:path])
    @uploaded_files.delete(file_id)
    @extracted_content.delete(file_id)
    true
  end

  private

  def extract_headings(doc)
    (1..6).map do |level|
      headings = doc.css("h#{level}").map(&:text).map(&:strip)
      [level, headings] if headings.any?
    end.compact.to_h
  end

  def extract_paragraphs(doc)
    doc.css('p').map(&:text).map(&:strip).reject(&:empty?)
  end

  def extract_links(doc)
    doc.css('a[href]').map do |link|
      {
        text: link.text.strip,
        href: link['href'],
        title: link['title']
      }
    end
  end

  def extract_images(doc)
    doc.css('img[src]').map do |img|
      {
        src: img['src'],
        alt: img['alt'],
        title: img['title'],
        width: img['width'],
        height: img['height']
      }
    end
  end

  def extract_forms(doc)
    doc.css('form').map do |form|
      {
        action: form['action'],
        method: form['method'] || 'GET',
        inputs: form.css('input, select, textarea').map do |input|
          {
            type: input['type'] || input.name,
            name: input['name'],
            id: input['id'],
            value: input['value']
          }
        end
      }
    end
  end

  def extract_meta_tags(doc)
    doc.css('meta').map do |meta|
      {
        name: meta['name'],
        property: meta['property'],
        content: meta['content'],
        charset: meta['charset']
      }
    end.reject { |m| m.values.all?(&:nil?) }
  end

  def analyze_structure(doc)
    {
      total_elements: doc.css('*').count,
      div_count: doc.css('div').count,
      span_count: doc.css('span').count,
      table_count: doc.css('table').count,
      list_count: doc.css('ul, ol').count,
      script_count: doc.css('script').count,
      style_count: doc.css('style').count
    }
  end
end