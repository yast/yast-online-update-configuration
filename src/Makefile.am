# Sources for online-update-configuration

module_DATA = \
  modules/OnlineUpdateConfiguration.rb

client_DATA = \
  clients/online_update_configuration_auto.rb \
  clients/online_update_configuration.rb

ylibdir = @ylibdir@/online-update-configuration
ylib_DATA = \
  lib/online-update-configuration/zypp_config.rb

yncludedir = @yncludedir@/online-update-configuration
ynclude_DATA = \
  include/online-update-configuration/OUCDialogs.rb

schemafilesdir = $(schemadir)/autoyast/rnc
schemafiles_DATA = \
  autoyast-rnc/online_update_configuration.rnc

ybin_SCRIPTS = \
  bin/online_update

desktop_DATA = \
  desktop/online_update_configuration.desktop

fillup_DATA = \
  fillup/sysconfig.automatic_online_update-yast2-online-update-configuration

scalabledir = @icondir@/hicolor/scalable/apps
scalable_DATA = \
  icons/hicolor/scalable/apps/yast-update-online-configuration.svg

EXTRA_DIST = $(module_DATA) $(client_DATA) $(ynclude_DATA) $(schemafiles_DATA) $(ybin_SCRIPTS) $(desktop_DATA) $(fillup_DATA) $(ylib_DATA) $(scalable_DATA)

include $(top_srcdir)/Makefile.am.common
