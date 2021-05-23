REVIEW_TEMPLATE = ENV['REVIEW_TEMPLATE'] || 'review-jsbook'

desc 'copy sty/* files from current Re:VIEW source code (in git repos)'
task :copy_sty do
  review_rootdir = '../../..'
  template_dir = File.join(review_rootdir, "templates/latex/#{REVIEW_TEMPLATE}")
  Dir.glob(File.join(template_dir, '*.cls')) do |file|
    FileUtils.cp(file, 'sty')
  end
  Dir.glob(File.join(template_dir, 'review-*.sty')) do |file|
    FileUtils.cp(file, 'sty')
  end

  if REVIEW_TEMPLATE == 'review-jsbook'
    jsbook_dir = File.join(review_rootdir, 'vendor/jsclasses')
    FileUtils.cp(File.join(jsbook_dir, 'jsbook.cls'), 'sty/jsbook.cls')
    gentombow_dir = File.join(review_rootdir, 'vendor/gentombow')
    FileUtils.cp(File.join(gentombow_dir, 'gentombow.sty'), 'sty/gentombow.sty')
  end
end

CLEAN.include([Dir.glob('sty/review-*.sty'), 'sty/*.cls', 'sty/gentombow.sty'])

Rake::Task[BOOK_PDF].enhance([:copy_sty])
