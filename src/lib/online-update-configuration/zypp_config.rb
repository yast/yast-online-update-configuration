module ZyppConfiguration
  CONFIG_USE_DELTA_RPM = '.etc.zypp_conf.value.main.\"download.use_deltarpm\"'

  def zypp_config
    @config ||= ZyppConfig.new
  end

  class ZyppConfig
    def use_delta_rpm?
      current_config = delta_rpm_config_value
      # Default settings in zypp.conf for using delta rpms is true
      current_config == nil || current_config == 'true'
    end

    def activate_delta_rpm
      set_config_value(true)
    end

    def deactivate_delta_rpm
      set_config_value(false)
    end

    private

    def set_config_value new_value
      return if new_value == use_delta_rpm?
      Yast::SCR.Write(Yast::Path.new(CONFIG_USE_DELTA_RPM), new_value)
    end

    def delta_rpm_config_value
      Yast::SCR.Read(Yast::Path.new(CONFIG_USE_DELTA_RPM))
    end
  end
end

