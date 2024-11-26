require 'sinatra'
require 'feedjira'
require 'open-uri'
require 'nokogiri'
require 'zip'
require 'sanitize'
require 'fileutils'
require 'ruby-pinyin'

# 创建临时目录用于存储markdown文件
TMP_DIR = './tmp'
FileUtils.mkdir_p(TMP_DIR) unless File.directory?(TMP_DIR)

get '/' do
  erb :index
end

post '/download' do
  language = params[:language]
  feed_url = "https://matcha-jp.com/#{language}/feed/"
  request_tmp_dir = File.join(TMP_DIR, Time.now.to_i.to_s)  
  zip_file_path = File.join(TMP_DIR, "matcha_articles_#{language}.zip")
  begin
    # 清理之前的临时文件
    FileUtils.rm_rf(Dir.glob(File.join(TMP_DIR, '*')))
    # 使用 Feedjira 替换 RSS::Parser
    puts "log url::#{feed_url}"
    xml = URI.open(feed_url).read
    feed = Feedjira.parse(xml)
    
    FileUtils.mkdir_p(request_tmp_dir)
    
    Zip::File.open(zip_file_path, Zip::File::CREATE) do |zipfile|
      feed.entries.each do |item|  # 使用 entries 替代 items
        content = Sanitize.fragment(item.content || item.summary || '')  # 更健壮的内容获取
        
        markdown_content = <<~MARKDOWN
          # #{item.title}
          
          发布日期: #{item.published}
          
          #{content}
          
          原文链接: #{item.url} 
        MARKDOWN
        
        # 将标题转换为拼音，如果包含汉字的话
        filename = if item.title =~ /\p{Han}/
          "#{PinYin.of_string(item.title).join('')}.md"
        else
          "#{item.title.gsub(/[^\w\s]/, '')}.md"
        end
        file_path = File.join(request_tmp_dir, filename)
        
        File.write(file_path, markdown_content)
        zipfile.add(filename, file_path)
      end
    end
    
    send_file zip_file_path, :filename => "matcha_articles_#{language}.zip",
                            :type => 'application/zip',
                            :disposition => 'attachment'
    
  rescue OpenURI::HTTPError => e
    error_message = "无法访问RSS源: #{e.message}\nBacktrace:\n#{e.backtrace.join("\n")}"
    puts error_message
    error_message
  rescue Feedjira::NoParserAvailable => e
    error_message = "RSS解析错误: #{e.message}\nBacktrace:\n#{e.backtrace.join("\n")}"
    puts error_message
    error_message
  rescue => e
    error_message = "Error: #{e.message}\nBacktrace:\n#{e.backtrace.join("\n")}"
    puts error_message
    error_message
    
  ensure
    # 清理临时文件
    #FileUtils.rm_rf(request_tmp_dir) if defined?(request_tmp_dir) && File.directory?(request_tmp_dir)
    #FileUtils.rm(zip_file_path) if defined?(zip_file_path) && File.exist?(zip_file_path)
  end
end