module ZyppConfiguration
  SCR_TARGET = '.etc.zypp_conf'
  CONFIG_USE_DELTA_RPM = "#{SCR_TARGET}.value.main.\"download.use_deltarpm\""

  def zypp_config
    @config ||= ZyppConfig.new
  end

  class ZyppConfig
    def initialize
      current_config = delta_rpm_config_value
      # Default settings in zypp.conf for using delta rpms is true
      @use_delta_rpm = current_config == nil || current_config == 'true'
    end

    def use_delta_rpm?
      @use_delta_rpm
    end

    def activate_delta_rpm
      Yast::Builtins.y2milestone("Activating delta rpms for online update..")
      set_config_value(true)
    end

    def deactivate_delta_rpm
      Yast::Builtins.y2milestone("Deactivating delta rpms for online update..")
      set_config_value(false)
    end

    private

    def set_config_value new_value
      return if new_value == use_delta_rpm?
      Yast::SCR.Write(Yast::Path.new(CONFIG_USE_DELTA_RPM), new_value)
    end

    def delta_rpm_config_value
      Yast::Builtins.y2milestone("Reading zypp configuration for deltarpms")
      Yast::SCR.Read(Yast::Path.new(CONFIG_USE_DELTA_RPM))
    end
  end
end

