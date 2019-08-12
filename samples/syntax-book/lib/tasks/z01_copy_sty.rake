desc 'copy sty/* files from current Re:VIEW source code (in git repos)'
task :copy_sty do
  review_rootdir = '../..'
  jsbook_dir = File.join(review_rootdir, 'templates/latex/review-jsbook')
  gentombow_dir = File.join(review_rootdir, 'vendor/gentombow')
  Dir.glob(File.join(jsbook_dir, '*.cls')) do |file|
    FileUtils.cp(file, 'sty')
  end
  Dir.glob(File.join(jsbook_dir, 'review-*.sty')) do |file|
    FileUtils.cp(file, 'sty')
  end
  FileUtils.cp(File.join(gentombow_dir, 'gentombow.sty'), 'sty/gentombow.sty')
end

CLEAN.include([Dir.glob('sty/review-*.sty'), 'sty/review-jsbook.cls', 'sty/gentombow.sty'])

Rake::Task[BOOK_PDF].enhance([:copy_sty])
