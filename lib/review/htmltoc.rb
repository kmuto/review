module ReVIEW
  class HTMLToc
    def initialize(basedir)
      @tochtmltxt = 'toc-html.txt'
      @basedir = basedir
    end

    def add_item(level, filename, title, args)
      args_str = encode_args(args)
      line = [level, filename, title, args_str].join("\t")
      File.open(tocfilename, 'a') { |f| f.write "#{line}\n" }
    end

    def each_item
      File.open(tocfilename) do |f|
        f.each_line do |line|
          level, file, title, args_str = line.chomp.split("\t")
          args = decode_args(args_str)
          yield level, file, title, args
        end
      end
    end

    def tocfilename
      File.join(@basedir, @tochtmltxt)
    end

    def decode_args(args_str)
      args = {}
      args_str.split(/,\s*/).each do |pair|
        key, val = pair.split('=')
        args[key.to_sym] = val
      end
      args
    end

    def encode_args(args)
      args.delete_if { |_k, v| v.nil? }.map { |k, v| "#{k}=#{v}" }.join(',')
    end
  end
end
