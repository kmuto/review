require 'fileutils'
require 'rake/clean'

BOOK = "book"
BOOK_PDF = BOOK+".pdf"
BOOK_EPUB = BOOK+".epub"
CONFIG_FILE = "config.yml"
WEBROOT = "webroot"

def build(mode, chapter)
  sh "review-compile --target=#{mode} --footnotetext --stylesheet=style.css #{chapter} > tmp"
  mode_ext = {"html" => "html", "latex" => "tex",
              "idgxml" => "xml"}
  FileUtils.mv "tmp", chapter.gsub(/re\z/, mode_ext[mode])
end

def build_all(mode)
  sh "review-compile --target=#{mode} --footnotetext --stylesheet=style.css"
end

task :default => :html_all

desc "build html (Usage: rake build re=target.re)"
task :html do
  if ENV['re'].nil?
    puts "Usage: rake build re=target.re"
    exit
  end
  build("html", ENV['re'])
end

desc "build all html"
task :html_all do
  build_all("html")
end

desc 'generate PDF and EPUB file'
task :all => [:pdf, :epub]

desc 'generate PDF file'
task :pdf => BOOK_PDF

desc 'generate stagic HTML file for web'
task :web => WEBROOT

desc 'generate EPUB file'
task :epub => BOOK_EPUB

SRC = FileList['*.re'] + [CONFIG_FILE]

file BOOK_PDF => SRC do
  FileUtils.rm_rf [BOOK_PDF, BOOK, BOOK+"-pdf"]
  sh "review-pdfmaker #{CONFIG_FILE}"
end

file BOOK_EPUB => SRC do
  FileUtils.rm_rf [BOOK_EPUB, BOOK, BOOK+"-epub"]
  sh "review-epubmaker #{CONFIG_FILE}"
end

file WEBROOT => SRC do
  FileUtils.rm_rf [WEBROOT]
  sh "review-webmaker #{CONFIG_FILE}"
end

CLEAN.include([BOOK, BOOK_PDF, BOOK_EPUB, BOOK+"-pdf", BOOK+"-epub", WEBROOT])
