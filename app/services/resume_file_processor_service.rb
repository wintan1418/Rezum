class ResumeFileProcessorService
  include ActiveModel::Model
  include ActiveModel::Attributes
  
  attribute :file
  attribute :user_id, :integer
  
  validates :file, presence: true
  validates :user_id, presence: true
  
  SUPPORTED_FORMATS = %w[application/pdf application/vnd.openxmlformats-officedocument.wordprocessingml.document application/msword text/plain].freeze
  MAX_FILE_SIZE = 10.megabytes
  
  def initialize(attributes = {})
    super
    validate_file if file.present?
  end
  
  def process
    validate!
    
    Rails.logger.info "Processing file: #{file.original_filename}, Content-Type: #{file.content_type}, Size: #{file.size}"
    
    case file.content_type
    when 'application/pdf'
      extract_text_from_pdf
    when 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      extract_text_from_docx
    when 'application/msword'
      extract_text_from_doc
    when 'text/plain'
      extract_text_from_txt
    else
      raise ResumeProcessingError.new("Unsupported file format: #{file.content_type}. Supported formats: #{SUPPORTED_FORMATS.join(', ')}")
    end
  end
  
  def extract_metadata
    validate!
    
    {
      filename: file.original_filename,
      content_type: file.content_type,
      file_size: file.size,
      processed_at: Time.current,
      word_count: nil, # Will be populated after text extraction
      pages: nil # Will be populated for PDFs
    }
  end
  
  private
  
  def validate_file
    unless file.respond_to?(:content_type) && file.respond_to?(:size)
      errors.add(:file, 'Invalid file object')
      return
    end
    
    unless SUPPORTED_FORMATS.include?(file.content_type)
      errors.add(:file, "Unsupported format. Please upload PDF, DOCX, or TXT files.")
      return
    end
    
    if file.size > MAX_FILE_SIZE
      errors.add(:file, "File too large. Maximum size is #{MAX_FILE_SIZE / 1.megabyte}MB.")
      return
    end
  end
  
  def extract_text_from_pdf
    begin
      reader = PDF::Reader.new(file.tempfile)
      text_content = ""
      page_count = 0
      
      reader.pages.each do |page|
        text_content += page.text + "\n"
        page_count += 1
      end
      
      # Clean up the extracted text
      cleaned_text = clean_extracted_text(text_content)
      
      {
        text: cleaned_text,
        metadata: {
          pages: page_count,
          word_count: cleaned_text.split.size,
          extraction_method: 'pdf-reader'
        }
      }
    rescue => e
      Rails.logger.error "PDF extraction failed: #{e.message}"
      raise ResumeProcessingError.new("Failed to extract text from PDF. Please ensure the file is not corrupted or password-protected.")
    end
  end
  
  def extract_text_from_doc
    begin
      # For legacy DOC files, we'll try to read them as plain text
      # This is a fallback since proper DOC parsing requires more complex libraries
      content = File.read(file.tempfile, encoding: 'binary').force_encoding('utf-8')
      # Try to extract readable text, though it may be messy
      text = content.gsub(/[^\x20-\x7E\n\r\t]/, ' ').squeeze(' ')
      
      cleaned_text = clean_extracted_text(text)
      
      {
        text: cleaned_text.blank? ? "Unable to extract text from DOC file. Please convert to DOCX or PDF format." : cleaned_text,
        metadata: {
          word_count: cleaned_text.split.size,
          extraction_method: 'basic-text-extraction',
          note: 'DOC files may not extract perfectly. Consider converting to DOCX or PDF for best results.'
        }
      }
    rescue => e
      Rails.logger.error "Error extracting text from DOC file: #{e.message}"
      raise ResumeProcessingError.new("Failed to process DOC file: #{e.message}")
    end
  end
  
  def extract_text_from_docx
    begin
      doc = Docx::Document.open(file.tempfile)
      text_content = ""
      
      doc.paragraphs.each do |paragraph|
        text_content += paragraph.text + "\n"
      end
      
      # Also extract text from tables
      doc.tables.each do |table|
        table.rows.each do |row|
          row.cells.each do |cell|
            text_content += cell.text + " "
          end
          text_content += "\n"
        end
      end
      
      cleaned_text = clean_extracted_text(text_content)
      
      {
        text: cleaned_text,
        metadata: {
          word_count: cleaned_text.split.size,
          extraction_method: 'docx'
        }
      }
    rescue => e
      Rails.logger.error "DOCX extraction failed: #{e.message}"
      raise ResumeProcessingError.new("Failed to extract text from DOCX file. Please ensure the file is not corrupted or password-protected.")
    end
  end
  
  def extract_text_from_txt
    begin
      text_content = file.read.force_encoding('UTF-8')
      cleaned_text = clean_extracted_text(text_content)
      
      {
        text: cleaned_text,
        metadata: {
          word_count: cleaned_text.split.size,
          extraction_method: 'text'
        }
      }
    rescue => e
      Rails.logger.error "TXT extraction failed: #{e.message}"
      raise ResumeProcessingError.new("Failed to read text file. Please ensure the file encoding is UTF-8.")
    end
  end
  
  def clean_extracted_text(text)
    return "" if text.blank?
    
    # Remove excessive whitespace and normalize line breaks
    cleaned = text.gsub(/\r\n?/, "\n") # Normalize line breaks
                  .gsub(/\n{3,}/, "\n\n") # Reduce multiple line breaks
                  .gsub(/[ \t]+/, " ") # Normalize spaces and tabs
                  .strip
    
    # Remove common PDF artifacts
    cleaned = cleaned.gsub(/\f/, "") # Form feed characters
                    .gsub(/[\u0000-\u001F&&[^\n\t]]/, "") # Control characters except newline and tab
                    .gsub(/\u00A0/, " ") # Non-breaking spaces
    
    # Basic content validation
    if cleaned.length < 50
      raise ResumeProcessingError.new("Extracted text is too short. Please ensure your resume contains readable text.")
    end
    
    if cleaned.split.size < 20
      raise ResumeProcessingError.new("Not enough content detected. Please ensure your resume is properly formatted.")
    end
    
    cleaned
  end
  
  def validate!
    raise ResumeProcessingError.new(errors.full_messages.join(", ")) unless valid?
  end
end

class ResumeProcessingError < StandardError; end