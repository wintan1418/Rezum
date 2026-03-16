require "zip"

class PitchDeckExportService
  SLIDE_WIDTH = 12_192_000  # EMU (914400 per inch * 13.333 inches)
  SLIDE_HEIGHT = 6_858_000  # EMU (914400 per inch * 7.5 inches)

  def initialize(pitch_deck)
    @deck = pitch_deck
    @slides = pitch_deck.ordered_slides.to_a
  end

  def to_pptx
    file = Tempfile.new(["pitch_deck", ".pptx"])

    Zip::OutputStream.open(file.path) do |zip|
      write_content_types(zip)
      write_rels(zip)
      write_presentation(zip)
      write_presentation_rels(zip)
      write_slide_layouts(zip)
      write_theme(zip)

      @slides.each_with_index do |slide, i|
        write_slide(zip, slide, i + 1)
        write_slide_rels(zip, i + 1)
      end
    end

    file
  end

  private

  def write_content_types(zip)
    slide_entries = @slides.each_with_index.map { |_, i|
      %(<Override PartName="/ppt/slides/slide#{i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>)
    }.join("\n  ")

    zip.put_next_entry("[Content_Types].xml")
    zip.write <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/>
        <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
        <Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>
        <Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>
        <Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>
        #{slide_entries}
      </Types>
    XML
  end

  def write_rels(zip)
    zip.put_next_entry("_rels/.rels")
    zip.write <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
      </Relationships>
    XML
  end

  def write_presentation(zip)
    slide_list = @slides.each_with_index.map { |_, i|
      %(<p:sldId id="#{256 + i}" r:id="rId#{i + 2}"/>)
    }.join("\n      ")

    zip.put_next_entry("ppt/presentation.xml")
    zip.write <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
        xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
        xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
        <p:sldMasterIdLst>
          <p:sldMasterId id="2147483648" r:id="rId1"/>
        </p:sldMasterIdLst>
        <p:sldIdLst>
          #{slide_list}
        </p:sldIdLst>
        <p:sldSz cx="#{SLIDE_WIDTH}" cy="#{SLIDE_HEIGHT}"/>
        <p:notesSz cx="#{SLIDE_HEIGHT}" cy="#{SLIDE_WIDTH}"/>
      </p:presentation>
    XML
  end

  def write_presentation_rels(zip)
    slide_rels = @slides.each_with_index.map { |_, i|
      %(<Relationship Id="rId#{i + 2}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide#{i + 1}.xml"/>)
    }.join("\n  ")

    zip.put_next_entry("ppt/_rels/presentation.xml.rels")
    zip.write <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>
        #{slide_rels}
        <Relationship Id="rId#{@slides.length + 2}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="theme/theme1.xml"/>
      </Relationships>
    XML
  end

  def write_slide_layouts(zip)
    zip.put_next_entry("ppt/slideLayouts/slideLayout1.xml")
    zip.write <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <p:sldLayout xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
        xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
        xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" type="blank">
        <p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
        <p:grpSpPr/></p:spTree></p:cSld>
      </p:sldLayout>
    XML

    zip.put_next_entry("ppt/slideLayouts/_rels/slideLayout1.xml.rels")
    zip.write <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/>
      </Relationships>
    XML

    zip.put_next_entry("ppt/slideMasters/slideMaster1.xml")
    zip.write <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <p:sldMaster xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
        xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
        xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
        <p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
        <p:grpSpPr/></p:spTree></p:cSld>
        <p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst>
      </p:sldMaster>
    XML

    zip.put_next_entry("ppt/slideMasters/_rels/slideMaster1.xml.rels")
    zip.write <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
        <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/>
      </Relationships>
    XML
  end

  def write_theme(zip)
    zip.put_next_entry("ppt/theme/theme1.xml")
    zip.write <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="PitchDeck">
        <a:themeElements>
          <a:clrScheme name="Custom">
            <a:dk1><a:srgbClr val="1F2937"/></a:dk1>
            <a:lt1><a:srgbClr val="FFFFFF"/></a:lt1>
            <a:dk2><a:srgbClr val="374151"/></a:dk2>
            <a:lt2><a:srgbClr val="F9FAFB"/></a:lt2>
            <a:accent1><a:srgbClr val="7C3AED"/></a:accent1>
            <a:accent2><a:srgbClr val="EC4899"/></a:accent2>
            <a:accent3><a:srgbClr val="10B981"/></a:accent3>
            <a:accent4><a:srgbClr val="3B82F6"/></a:accent4>
            <a:accent5><a:srgbClr val="F59E0B"/></a:accent5>
            <a:accent6><a:srgbClr val="EF4444"/></a:accent6>
            <a:hlink><a:srgbClr val="7C3AED"/></a:hlink>
            <a:folHlink><a:srgbClr val="6B21A8"/></a:folHlink>
          </a:clrScheme>
          <a:fontScheme name="Custom">
            <a:majorFont><a:latin typeface="Calibri"/></a:majorFont>
            <a:minorFont><a:latin typeface="Calibri"/></a:minorFont>
          </a:fontScheme>
          <a:fmtScheme name="Custom">
            <a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:fillStyleLst>
            <a:lnStyleLst><a:ln w="9525"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln><a:ln w="9525"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln><a:ln w="9525"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln></a:lnStyleLst>
            <a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst>
            <a:bgFillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:bgFillStyleLst>
          </a:fmtScheme>
        </a:themeElements>
      </a:theme>
    XML
  end

  def write_slide(zip, slide, number)
    title = xml_escape(slide.title || slide.type_label)
    body_text = extract_body_text(slide)

    zip.put_next_entry("ppt/slides/slide#{number}.xml")
    zip.write <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
        xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
        xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
        <p:cSld>
          <p:spTree>
            <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
            <p:grpSpPr/>
            <!-- Title -->
            <p:sp>
              <p:nvSpPr><p:cNvPr id="2" name="Title"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr/></p:nvSpPr>
              <p:spPr>
                <a:xfrm><a:off x="609600" y="365125"/><a:ext cx="10972800" cy="857250"/></a:xfrm>
                <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
              </p:spPr>
              <p:txBody>
                <a:bodyPr anchor="b"/>
                <a:lstStyle/>
                <a:p><a:r><a:rPr lang="en-US" sz="3200" b="1" dirty="0">
                  <a:solidFill><a:srgbClr val="1F2937"/></a:solidFill>
                  <a:latin typeface="Calibri"/>
                </a:rPr><a:t>#{title}</a:t></a:r></a:p>
              </p:txBody>
            </p:sp>
            <!-- Body -->
            <p:sp>
              <p:nvSpPr><p:cNvPr id="3" name="Body"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr/></p:nvSpPr>
              <p:spPr>
                <a:xfrm><a:off x="609600" y="1371600"/><a:ext cx="10972800" cy="4800600"/></a:xfrm>
                <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
              </p:spPr>
              <p:txBody>
                <a:bodyPr anchor="t"/>
                <a:lstStyle/>
                #{body_paragraphs(body_text)}
              </p:txBody>
            </p:sp>
          </p:spTree>
        </p:cSld>
      </p:sld>
    XML
  end

  def write_slide_rels(zip, number)
    zip.put_next_entry("ppt/slides/_rels/slide#{number}.xml.rels")
    zip.write <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
      </Relationships>
    XML
  end

  def extract_body_text(slide)
    lines = []
    content = slide.content || {}

    content.each do |key, value|
      case value
      when String
        lines << value unless key.in?(%w[headline])
      when Array
        value.each do |item|
          if item.is_a?(Hash)
            label = item["title"] || item["name"] || item["stream"] || item["trend"] || item["category"] || item["label"] || item["milestone"] || item["year"]
            detail = item["description"] || item["detail"] || item["bio"] || item["value"] || item["revenue"]
            lines << "#{label}: #{detail}" if label.present?
          elsif item.is_a?(String)
            lines << item
          end
        end
      when Hash
        label = value["value"] || value["stat"] || value["before"]
        lines << "#{key.titleize}: #{label}" if label.present?
      end
    end

    lines.compact.reject(&:blank?)
  end

  def body_paragraphs(lines)
    lines.map { |line|
      text = xml_escape(line.to_s.truncate(200))
      <<~XML
        <a:p><a:r><a:rPr lang="en-US" sz="1600" dirty="0">
          <a:solidFill><a:srgbClr val="374151"/></a:solidFill>
          <a:latin typeface="Calibri"/>
        </a:rPr><a:t>#{text}</a:t></a:r></a:p>
      XML
    }.join
  end

  def xml_escape(text)
    text.to_s.encode(xml: :text)
  end
end
