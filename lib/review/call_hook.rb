module ReVIEW
  module CallHook
    def call_hook(hook_name, *params, base_dir: nil)
      maker = @config.maker
      filename = @config.dig(maker, hook_name)
      return unless filename

      hook = File.absolute_path(filename, base_dir)
      @logger.debug("Call #{hook_name}. (#{hook})")

      return if !File.exist?(hook) || !FileTest.executable?(hook)

      if ENV['REVIEW_SAFE_MODE'].to_i & 1 > 0
        warn 'hook configuration is prohibited in safe mode. ignored.'
      else
        system(hook, *params)
      end
    end
  end
end
