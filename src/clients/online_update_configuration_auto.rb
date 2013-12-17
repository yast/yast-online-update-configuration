# encoding: utf-8

# ***************************************************************************
#
# Copyright (c) 2006 - 2012 Novell, Inc.
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail,
# you may find current contact information at www.novell.com
#
# ***************************************************************************
# File:        online_update_configuration
# Module:      Online Update Configuration
# Summary:     Configure Online Update
# Authors:     J. Daniel Schmidt <jdsn@suse.de>
#
# Configure Online Update Settings
#
# $Id: online_update_configuration.ycp 1 2008-09-10 13:20:02Z jdsn $
module Yast
  class OnlineUpdateConfigurationAutoClient < Client
    def main
      Yast.import "UI"
      textdomain "online-update-configuration"

      Yast.import "OnlineUpdateConfiguration"
      Yast.import "Wizard"
      Yast.import "Popup"
      Yast.import "Label"
      Yast.import "URL"
      Yast.import "Mode"
      Yast.import "Summary"
      #     import "FileUtils";
      #     import "SourceManager";
      #     import "Package";
      #     import "PackageCallbacks";

      Yast.include self, "online-update-configuration/OUCDialogs.rb"





      #---------------------------------------------------------------------------
      # MAIN
      #---------------------------------------------------------------------------
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("online_update_configuration_auto started")


      @ret = nil
      @func = ""
      @param = {}

      # Check arguments
      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        @func = Convert.to_string(WFM.Args(0))
        if Ops.greater_than(Builtins.size(WFM.Args), 1) &&
            Ops.is_map?(WFM.Args(1))
          @param = Convert.to_map(WFM.Args(1))
        end
      end

      Builtins.y2milestone("func=%1", @func)
      Builtins.y2milestone("param=%1", @param)

      # Create a summary
      if @func == "Summary"
        @ret = Summary()
      # Reset configuration
      elsif @func == "Reset"
        Import({})
        @ret = {}
      # Change configuration (run AutoSequence)
      elsif @func == "Change"
        @ret = OUC_configure()
      # Import configuration
      elsif @func == "Import"
        @ret = Import(@param)
      # Return actual state
      elsif @func == "Export"
        @ret = Export()
      # Return needed packages
      elsif @func == "Packages"
        @ret = AutoPackages()
      # Write given settings
      elsif @func == "Write"
        Yast.import "Progress"
        Progress.off
        @ret = Write()
        Progress.on
      elsif @func == "GetModified"
        @ret = OnlineUpdateConfiguration.OUCmodified
      elsif @func == "SetModified"
        OnlineUpdateConfiguration.OUCmodified = true
      else
        Builtins.y2error("Unknown function: %1", @func)
        @ret = false
      end

      Builtins.y2milestone("ret=%1", @ret)
      Builtins.y2milestone("online_update_configuration_auto finished")
      Builtins.y2milestone("----------------------------------------")

      deep_copy(@ret)

      # EOF
    end

    # Get all setting
    # @param [Hash] settings The YCP structure to be imported.
    # @return [Boolean] True on success
    def Import(settings)
      settings = deep_copy(settings)
      Builtins.y2debug("Import called, settings: %1", settings)
      OnlineUpdateConfiguration.Import(settings)
    end


    # Export the settings to a single map
    # (For use by autoinstallation.)
    def Export
      Builtins.y2debug("Export called")
      OnlineUpdateConfiguration.Export
    end


    # Write all settings
    # @return true on success
    def Write
      OnlineUpdateConfiguration.Write
    end


    def Read
      OnlineUpdateConfiguration.Read

      nil
    end

    def AutoPackages
      { "install" => [], "remove" => [] }
    end




    # Create a textual summary and a list of unconfigured cards
    # @return summary of the current configuration
    def Summary
      summary = ""

      summary = Summary.AddHeader(summary, @automaticOnlineUpdate)
      summary = Summary.AddLine(
        summary,
        OnlineUpdateConfiguration.enableAOU ? @enabledMsg : @disabledMsg
      )

      if OnlineUpdateConfiguration.enableAOU
        summary = Summary.AddHeader(summary, @interval)
        summary = Summary.AddLine(
          summary,
          OnlineUpdateConfiguration.intervalSymbolToString(
            OnlineUpdateConfiguration.updateInterval,
            :trans
          )
        )

        summary = Summary.AddHeader(summary, @skipInteractivePatches)
        summary = Summary.AddLine(
          summary,
          OnlineUpdateConfiguration.skipInteractivePatches ? @enabledMsg : @disabledMsg
        )

        summary = Summary.AddHeader(summary, @autoAgreeWithLicenses)
        summary = Summary.AddLine(
          summary,
          OnlineUpdateConfiguration.autoAgreeWithLicenses ? @enabledMsg : @disabledMsg
        )

        summary = Summary.AddHeader(summary, @includeRecommends)
        summary = Summary.AddLine(
          summary,
          OnlineUpdateConfiguration.includeRecommends ? @enabledMsg : @disabledMsg
        )

        summary = Summary.AddHeader(summary, @use_deltarpm)
        summary = Summary.AddLine(
          summary,
          OnlineUpdateConfiguration.use_deltarpm ? @enabledMsg : @disabledMsg
        )
        summary = Summary.AddHeader(summary, @filterByCategory)
        summary = Summary.AddLine(
          summary,
          Builtins.mergestring(OnlineUpdateConfiguration.currentCategories, " ")
        )
      end

      summary
    end




    # ---------------------------------------------------------------------------------------------------------------

    def OUC_configure
      help = getOUCHelp(:autoyast)
      contents = getOUCDialog(:autoyast)


      Wizard.CreateDialog

      # we always need the next button and never the back button
      Wizard.SetContents(@moduleTitle, contents, help, false, true)
      Wizard.SetTitleIcon("yast-online_update")
      Wizard.SetNextButton(:next, Label.FinishButton)

      #OnlineUpdateConfiguration::Read();

      # write settings to the UI
      UI.ChangeWidget(
        Id(:automaticOnlineUpdate),
        :Value,
        OnlineUpdateConfiguration.enableAOU
      )
      UI.ChangeWidget(
        Id(:updateInterval),
        :Value,
        OnlineUpdateConfiguration.updateInterval
      )
      UI.ChangeWidget(
        Id(:skipInteractivePatches),
        :Value,
        OnlineUpdateConfiguration.skipInteractivePatches
      )
      UI.ChangeWidget(
        Id(:autoAgreeWithLicenses),
        :Value,
        OnlineUpdateConfiguration.autoAgreeWithLicenses
      )
      UI.ChangeWidget(
        Id(:includeRecommends),
        :Value,
        OnlineUpdateConfiguration.includeRecommends
      )
      UI.ChangeWidget(
        Id(:use_deltarpm),
        :Value,
        OnlineUpdateConfiguration.use_deltarpm
      )
      UI.ChangeWidget(
        Id(:category),
        :Value,
        Ops.greater_than(
          Builtins.size(OnlineUpdateConfiguration.currentCategories),
          0
        )
      )
      refreshCategoryList(nil)

      UI.RecalcLayout

      ret = :auto
      begin
        ret = Wizard.UserInput

        if ret == :next
          OnlineUpdateConfiguration.updateInterval = Convert.to_symbol(
            UI.QueryWidget(Id(:updateInterval), :Value)
          )
          OnlineUpdateConfiguration.skipInteractivePatches = Convert.to_boolean(
            UI.QueryWidget(Id(:skipInteractivePatches), :Value)
          )
          OnlineUpdateConfiguration.autoAgreeWithLicenses = Convert.to_boolean(
            UI.QueryWidget(Id(:autoAgreeWithLicenses), :Value)
          )
          OnlineUpdateConfiguration.enableAOU = Convert.to_boolean(
            UI.QueryWidget(Id(:automaticOnlineUpdate), :Value)
          )
          OnlineUpdateConfiguration.includeRecommends = Convert.to_boolean(
            UI.QueryWidget(Id(:includeRecommends), :Value)
          )
          OnlineUpdateConfiguration.use_deltarpm = UI.QueryWidget(Id(:use_deltarpm), :Value)
          # reset categories to disable the filter
          catFilter = Convert.to_boolean(UI.QueryWidget(Id(:category), :Value))
          OnlineUpdateConfiguration.currentCategories = [] if !catFilter
          break
        end

        if ret == :catadd || ret == :catdel
          addcat = ""
          if ret == :catadd
            addcat = Builtins.tolower(
              Convert.to_string(UI.QueryWidget(Id(:catcustom), :Value))
            )
            addcat = Builtins.filterchars(
              addcat,
              "abcdefghijklmnopqrstuvwxyz0123456789-_."
            )
            if !Builtins.contains(
                OnlineUpdateConfiguration.currentCategories,
                addcat
              )
              OnlineUpdateConfiguration.currentCategories = Builtins.add(
                OnlineUpdateConfiguration.currentCategories,
                addcat
              )
            end
          end

          if ret == :catdel
            delcat = Convert.to_string(
              UI.QueryWidget(Id(:categories), :CurrentItem)
            )
            OnlineUpdateConfiguration.currentCategories = Builtins.filter(
              OnlineUpdateConfiguration.currentCategories
            ) { |s| s != delcat }
          end

          refreshCategoryList(addcat)
        end
      end until ret == :next || ret == :abort || ret == :cacel || ret == :back

      ret = :next if !Ops.is_symbol?(ret)

      Wizard.CloseDialog
      Convert.to_symbol(ret)
    end
  end
end

Yast::OnlineUpdateConfigurationAutoClient.new.main
