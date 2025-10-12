# frozen_string_literal: true

require 'cgi'

module ReVIEW
  module EscapeUtils
    # 基本HTMLエスケープ（CGI.escapeHTMLを直接使用）
    def escape_content(str)
      CGI.escapeHTML(str.to_s)
    end

    # HTMLコメント内エスケープ
    def escape_comment(str)
      str.to_s.gsub('-', '&#45;')
    end

    # URL用エスケープ
    def escape_url(str)
      CGI.escape(str.to_s)
    end
  end
end
