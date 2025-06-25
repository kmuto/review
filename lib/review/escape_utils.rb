# frozen_string_literal: true

require 'cgi'

module ReVIEW
  module EscapeUtils
    # 基本HTMLエスケープ（CGI.escapeHTMLを直接使用）
    def escape_content(str)
      CGI.escapeHTML(str.to_s)
    end

    # 属性値専用エスケープ
    def escape_attribute(str)
      escape_content(str).gsub("'", '&#39;')
    end

    # HTMLコメント内エスケープ
    def escape_comment(str)
      str.to_s.gsub('-', '&#45;')
    end

    # URL用エスケープ
    def escape_url(str)
      CGI.escape(str.to_s)
    end

    # 統一エスケープ判定
    def needs_escape?(context)
      case context
      when :text, :inline, :attribute
        true
      when :url, :comment
        true
      when :raw, :pre_escaped
        false
      else
        true # デフォルトでエスケープ
      end
    end
  end
end
