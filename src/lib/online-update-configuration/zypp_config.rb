class ZyppConfig
  CONFIG_USE_DELTA_RPM = Yast::Path.new(".etc.zypp_conf.value.main.\"download.use_deltarpm\"")

  def initialize
    @use_deltarpm = true
    current_config = get_delta_rpm_config_value
    # Default config for delta rpms in zypp.conf is true
    @use_deltarpm = !['0', 'no', 'false', 'off', '-'].include?(current_config.downcase) if current_config
  end

  def use_deltarpm?
    @use_deltarpm
  end

  def activate_deltarpm
    Yast::Builtins.y2milestone("Activating delta rpms for online update..")
    set_delta_rpm_config_value(true)
  end

  def deactivate_deltarpm
    Yast::Builtins.y2milestone("Deactivating delta rpms for online update..")
    set_delta_rpm_config_value(false)
  end

  private

  def set_delta_rpm_config_value new_value
    return if new_value == use_deltarpm?
    Yast::SCR.Write(CONFIG_USE_DELTA_RPM, new_value)
  end

  def get_delta_rpm_config_value
    Yast::SCR.Read(CONFIG_USE_DELTA_RPM)
  end
end
