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
  class OnlineUpdateConfigurationClient < Client
    def main
      Yast.import "Pkg"
      Yast.import "UI"
      textdomain "online-update-configuration"

      Yast.import "OnlineUpdateConfiguration"
      Yast.import "Wizard"
      Yast.import "Popup"
      Yast.import "Label"
      Yast.import "URL"
      Yast.import "Mode"
      Yast.import "SourceManager"
      Yast.import "PackageCallbacks"
      Yast.import "CommandLine"
      Yast.import "Installation"

      Yast.include self, "online-update-configuration/OUCDialogs.rb"

      # support basic command-line output (bnc#439050)
      @wfm_args = WFM.Args
      Builtins.y2milestone("ARGS: %1", @wfm_args)
      if Ops.greater_than(Builtins.size(@wfm_args), 0) &&
          (Builtins.contains(@wfm_args, "help") ||
            Builtins.contains(@wfm_args, "longhelp") ||
            Builtins.contains(@wfm_args, "xmlhelp"))
        @cmdhelp = _("Online Update Configuration Module Help")
        Mode.SetUI("commandline")
        # TRANSLATORS: commandline help
        CommandLine.Run(
          { "id" => "online_update_configuration", "help" => @cmdhelp }
        )
        Builtins.y2milestone(
          "Online Update Configuration was called with help parameter."
        )
        return :auto
      end

      @ui = UI.GetDisplayInfo
      @textmode = Ops.get_boolean(@ui, "TextMode", false)

      @help = getOUCHelp(:default)
      @contents = getOUCDialog(:default)

      # ---------------------------------------------------------------------------------------------------------------

      Pkg.SourceStartManager(true)
      @targetRootDir = Mode.normal ? "/" : Installation.destdir
      Pkg.TargetInit(@targetRootDir, false) # (bnc#449844)

      # check if we are in installation workflow or running independently -  use OKDialog (bnc#440568)
      Wizard.OpenOKDialog if Mode.normal

      # we always need the next button and never the back button
      Wizard.SetContents(@moduleTitle, @contents, @help, false, true)

      if Mode.normal
        Wizard.SetDesktopTitleAndIcon("online_update_configuration")
      else
        Wizard.SetTitleIcon("yast-online_update")
      end

      # -------------------------------- PROGRAM LOGIC START -----------------------------------------------------------

      OnlineUpdateConfiguration.Read

      #    if (false) // for testing only
      #    {
      #        OnlineUpdateConfiguration::currentUpdateRepo = "";
      #    }

      @replaceUpdateRepoString = OnlineUpdateConfiguration.currentUpdateRepo


      if OnlineUpdateConfiguration.compareUpdateURLs(
          OnlineUpdateConfiguration.currentUpdateRepo,
          OnlineUpdateConfiguration.defaultUpdateRepo,
          false
        )
        @replaceUpdateRepoString = Ops.add(
          Ops.add(OnlineUpdateConfiguration.currentUpdateRepo, "   "),
          @defaultMark
        )
        UI.ChangeWidget(Id(:restoreDefault), :Enabled, false)
      else
        @replaceUpdateRepoString = @noRepo if @replaceUpdateRepoString == ""

        @hasUpRepo = OnlineUpdateConfiguration.defaultUpdateRepo != "" &&
          OnlineUpdateConfiguration.defaultUpdateRepo != nil
        UI.ChangeWidget(Id(:restoreDefault), :Enabled, @hasUpRepo)
      end

      # write data to the UI
      UI.ChangeWidget(Id(:currentRepoURL), :Value, @replaceUpdateRepoString)
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
        Id(:category),
        :Value,
        Ops.greater_than(
          Builtins.size(OnlineUpdateConfiguration.currentCategories),
          0
        )
      )
      refreshCategoryList(nil)

      UI.RecalcLayout
      #UI::RedrawScreen();

      @ret = :auto
      begin
        @ret = Wizard.UserInput

        if @ret == :next || @ret == :ok
          OnlineUpdateConfiguration.updateInterval = Convert.to_symbol(
            UI.QueryWidget(Id(:updateInterval), :Value)
          )
          OnlineUpdateConfiguration.skipInteractivePatches = Convert.to_boolean(
            UI.QueryWidget(Id(:skipInteractivePatches), :Value)
          )
          OnlineUpdateConfiguration.autoAgreeWithLicenses = Convert.to_boolean(
            UI.QueryWidget(Id(:autoAgreeWithLicenses), :Value)
          )
          OnlineUpdateConfiguration.includeRecommends = Convert.to_boolean(
            UI.QueryWidget(Id(:includeRecommends), :Value)
          )
          OnlineUpdateConfiguration.enableAOU = Convert.to_boolean(
            UI.QueryWidget(Id(:automaticOnlineUpdate), :Value)
          )
          # reset categories to disable the filter
          @catFilter = Convert.to_boolean(UI.QueryWidget(Id(:category), :Value))
          OnlineUpdateConfiguration.currentCategories = [] if !@catFilter

          Builtins.y2milestone("Writing online update configuration settings.")
          OnlineUpdateConfiguration.Write
          @ret = :next
        end

        if @ret == :restoreDefault
          if OnlineUpdateConfiguration.defaultUpdateRepo == nil ||
              OnlineUpdateConfiguration.defaultUpdateRepo == ""
            Builtins.y2milestone(
              "No default update repo could be found in the products metadata."
            )

            if OnlineUpdateConfiguration.defaultRegistrationURL == nil ||
                OnlineUpdateConfiguration.defaultRegistrationURL == ""
              Builtins.y2error(
                "No registration server set in product metadata. No update server can be setup automatically."
              )
            else
              Builtins.y2milestone(
                "Registration is needed to get an update source."
              )

              if Popup.YesNo(
                  Ops.add(Ops.add(@needToRegister, "\n\n"), @runRegistrationNow)
                )
                Builtins.y2milestone(
                  "User wants to run the registration in order to setup the default update repository."
                )
                # trigger registration
                @ret = :register
              else
                Builtins.y2milestone(
                  "User selected not to run the registration in order to setup the default update repository."
                )
              end
            end
          else
            Builtins.y2milestone(
              "User selected to set the default update repository: %1",
              OnlineUpdateConfiguration.defaultUpdateRepo
            )
            OnlineUpdateConfiguration.setUpdateRepo(
              OnlineUpdateConfiguration.defaultUpdateRepo
            )
          end
        end

        if @ret == :repoManager
          # inst_source was renamed to repositories (bnc#828139)
          WFM.call("repositories")
        end

        if @ret == :register
          if WFM.ClientExists("inst_suse_register")
            WFM.call("inst_suse_register")
          else
            Popup.Error(
              _("The registration module is not available.") + "\n" +
                _("Please install yast2-registration and try again.")
            )
          end
        end


        # update values in UI
        # after a registration call refetch the current update repo url
        if @ret == :restoreDefault || @ret == :register
          Builtins.y2milestone("Refetching current updateRepoURL.")
          @replaceUpdateRepoString = OnlineUpdateConfiguration.fetchCurrentUpdateRepoURL(
          )

          @mark = ""
          if OnlineUpdateConfiguration.compareUpdateURLs(
              @replaceUpdateRepoString,
              OnlineUpdateConfiguration.defaultUpdateRepo,
              false
            )
            @mark = Ops.add("   ", @defaultMark)
            UI.ChangeWidget(Id(:restoreDefault), :Enabled, false)
          end
          Builtins.y2milestone(
            "Current updateRepoURL is: %1",
            @replaceUpdateRepoString
          )
          UI.ChangeWidget(
            Id(:currentRepoURL),
            :Value,
            Ops.add(@replaceUpdateRepoString, @mark)
          )

          UI.RecalcLayout
        end

        if @ret == :catadd || @ret == :catdel
          @addcat = ""
          if @ret == :catadd
            @addcat = Builtins.tolower(
              Convert.to_string(UI.QueryWidget(Id(:catcustom), :Value))
            )
            @addcat = Builtins.filterchars(
              @addcat,
              "abcdefghijklmnopqrstuvwxyz0123456789-_."
            )
            if !Builtins.contains(
                OnlineUpdateConfiguration.currentCategories,
                @addcat
              )
              OnlineUpdateConfiguration.currentCategories = Builtins.add(
                OnlineUpdateConfiguration.currentCategories,
                @addcat
              )
            end
          end

          if @ret == :catdel
            @delcat = Convert.to_string(
              UI.QueryWidget(Id(:categories), :CurrentItem)
            )
            OnlineUpdateConfiguration.currentCategories = Builtins.filter(
              OnlineUpdateConfiguration.currentCategories
            ) { |s| s != @delcat }
          end

          refreshCategoryList(@addcat)
        end


        if @ret == :back || @ret == :abort || @ret == :cancel
          if Popup.ReallyAbort(true)
            break
          else
            @ret = :continue
          end
        end
      end until @ret == :ok || @ret == :next || @ret == :abort || @ret == :cancel ||
        @ret == :back

      # do not finish sources if we were told not to do so (bnc#828132)
      Pkg.SourceFinishAll if !Builtins.contains(@wfm_args, :no_source_finish)

      @ret = :next if !Ops.is_symbol?(@ret)

      Wizard.CloseDialog
      Convert.to_symbol(@ret)
    end
  end
end

Yast::OnlineUpdateConfigurationClient.new.main
