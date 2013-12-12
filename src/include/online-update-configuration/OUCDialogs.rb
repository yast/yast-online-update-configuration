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
  module OnlineUpdateConfigurationOUCDialogsInclude
    def initialize_online_update_configuration_OUCDialogs(include_target)
      #textdomain "registration";
      textdomain "online-update-configuration"

      Yast.import "OnlineUpdateConfiguration"

      # module title
      @moduleTitle = _("Online Update Configuration")
      # translators: (default), meaning: "Current Update Repository: http://xyz/  (default)"
      @defaultMark = _("(default)")
      # translators: (none), meaning "Current Update Repository: (none)"
      @noRepo = _("(none)")

      # frame title
      @updateRepository = _("Update Repository")
      # frame title
      @automaticOnlineUpdate = _("Automatic Online Update")

      # translators: "Set Default" meaning:  Set the Update Repository to the default one
      @setDefaultButtonLabel = _("Set Default")
      # translators: a short button label called "Advanced"
      @advancedMenuButtonLabel = _("Advanced")

      # for category filter
      @filterByCategory = _("Filter by Category")
      # for category filter //translators: means: categories of patches
      @patchCategories = _("Patch Categories")

      @enabledMsg = _("enabled")
      @disabledMsg = _("disabled")

      @editSoftwareRepositories = _("Edit Software Repositories")
      @registerForSupport = _("Register for support and get update repository")
      @sendDataToSmolt = _("Send hardware information to the smolt project")
      @interval = _("Interval")
      @skipInteractivePatches = _("Skip Interactive Patches")
      @autoAgreeWithLicenses = _("Agree with Licenses")
      @includeRecommends = _("Include Recommended Packages")
      @use_delta_rpm = _("Use delta rpms")
      @currentUpdateRepo = _("Current Update Repository:")
      @needToRegister = _(
        "In order to add the default update repository\nyou have to register this product."
      )
      @runRegistrationNow = _("Do you want to perform the registration now?")

      @help_title = Builtins.sformat("<p><b>%1</b></p>", @moduleTitle)
      @help_para1 = Builtins.sformat(
        _("<p>In <b>%1</b> the current update repository is shown.</p>"),
        @updateRepository
      )
      @help_para2 = Builtins.sformat(
        _("<p>Press <b>%1</b> to use the default update repository.</p>"),
        @setDefaultButtonLabel
      )
      @help_para3 = Builtins.sformat(
        _("<p>Find related actions in the <b>%1</b> menu.</p>"),
        @advancedMenuButtonLabel
      )
      @help_para4 = Builtins.sformat(
        _("<p>In <b>%1</b> set up the automatic online update.</p>"),
        @automaticOnlineUpdate
      )
      @help_para5 = Builtins.sformat(
        _(
          "<p>Select an update interval and specify if interactive patches should be ignored and if licenses should be automatically agreed with.</p>"
        )
      )
      @help_para6 = Builtins.sformat(
        _(
          "<p>All packages that are recommended by an updated package will be installed when <b>%1</b> is enabled.</p>"
        ),
        @includeRecommends
      )
      @help_para7 = Builtins.sformat(
        _(
          "<p>Category filter for patches can be configured in the section <b>%1</b>. Only patches of the listed categories will be installed. Others will be skipped.</p>"
        ),
        @patchCategories
      )
    end

    def getOUCHelp(type)
      if type == :autoyast
        return Ops.add(
          Ops.add(
            Ops.add(Ops.add(@help_title, @help_para4), @help_para5),
            @help_para6
          ),
          @help_para7
        )
      else
        # disabled as the setting of the default update repo is not possible
        #return help_title + help_para1 + help_para2 + help_para3 + help_para4 + help_para5 + help_para6 + help_para7;
        return Ops.add(
          Ops.add(
            Ops.add(Ops.add(@help_title, @help_para4), @help_para5),
            @help_para6
          ),
          @help_para7
        )
      end
      ""
    end




    def getOUCDialog(type)
      expertMenu =
        #  , `item(`id(`register),    registerForSupport )
        #  , `item(`id(`smolt),       sendDataToSmolt )
        [Item(Id(:repoManager), @editSoftwareRepositories)]

      updateIntervals = Builtins.maplist(OnlineUpdateConfiguration.Intervals) do |intid, i|
        Item(Id(intid), Ops.get(i, :trans, "none"))
      end

      upRepo = Frame(
        @updateRepository,
        HBox(
          HStretch(),
          VBox(
            Left(Label(@currentUpdateRepo)),
            Left(Label(Id(:currentRepoURL), "")),
            HBox(
              PushButton(
                Id(:restoreDefault),
                Opt(:disabled),
                @setDefaultButtonLabel
              ),
              MenuButton(@advancedMenuButtonLabel, expertMenu)
            )
          ),
          HStretch()
        )
      )

      sortedCatKeys = []
      sortedCatKeys = Builtins.maplist(
        OnlineUpdateConfiguration.defaultCategories
      ) { |s, t| s }
      sortedCatKeys = Builtins.sort(Builtins.toset(sortedCatKeys)) do |a, b|
        Ops.greater_than(a, b)
      end
      allCategories = Builtins.maplist(sortedCatKeys) do |s|
        Ops.get(OnlineUpdateConfiguration.defaultCategories, s, Item())
      end

      autoOnlineUp = HVSquash(
        VBox(
          CheckBoxFrame(
            Id(:automaticOnlineUpdate),
            @automaticOnlineUpdate,
            false,
            HBox(
              HSpacing(2),
              VBox(
                Left(ComboBox(Id(:updateInterval), @interval, updateIntervals)),
                VSpacing(0.2),
                Left(
                  CheckBox(
                    Id(:skipInteractivePatches),
                    @skipInteractivePatches,
                    OnlineUpdateConfiguration.skipInteractivePatches == true ? true : false
                  )
                ),
                VSpacing(0.2),
                Left(
                  CheckBox(
                    Id(:autoAgreeWithLicenses),
                    @autoAgreeWithLicenses,
                    OnlineUpdateConfiguration.autoAgreeWithLicenses == true ? true : false
                  )
                ),
                VSpacing(0.2),
                Left(
                  CheckBox(
                    Id(:includeRecommends),
                    @includeRecommends,
                    OnlineUpdateConfiguration.includeRecommends == true ? true : false
                  )
                ),
                VSpacing(0.2),
                Left(
                  CheckBox(
                    Id(:use_delta_rpm),
                    @use_delta_rpm,
                    OnlineUpdateConfiguration.use_delta_rpm
                  )
                ),
                VSpacing(0.8),
                CheckBoxFrame(
                  Id(:category),
                  @filterByCategory,
                  false,
                  HBox(
                    HSpacing(2),
                    VBox(
                      SelectionBox(Id(:categories), @patchCategories, []),
                      HBox(
                        MinWidth(
                          15,
                          ComboBox(
                            Id(:catcustom),
                            Opt(:editable),
                            "",
                            allCategories
                          )
                        ),
                        PushButton(Id(:catadd), Label.AddButton),
                        HSpacing(4),
                        PushButton(Id(:catdel), Label.DeleteButton)
                      )
                    )
                  )
                ),
                VSpacing(0.8)
              ),
              HSpacing(2)
            )
          ),
          Right(MenuButton(@advancedMenuButtonLabel, expertMenu)),
          VStretch()
        )
      )


      contents = nil

      if type == :autoyast
        contents = VBox(VSpacing(1.5), autoOnlineUp, VStretch(), VSpacing(1.5))
      else
        #contents = `HVSquash( `VBox(
        #             `VSpacing(1.5),  upRepo,
        #             `VSpacing(1.5),  autoOnlineUp, `VStretch(),  `VSpacing(1.5)
        #            ));

        # do not show the update repo restore section
        # repos do not identify themselves yet as update repos, and products do not define their update repo ID
        # can be reactivated when bnc#449842 is fixed and fully supported
        contents = VBox(VSpacing(1.5), autoOnlineUp, VStretch(), VSpacing(1.5))
      end

      deep_copy(contents)
    end


    def refreshCategoryList(selected)
      OnlineUpdateConfiguration.currentCategories = Builtins.toset(
        OnlineUpdateConfiguration.currentCategories
      )
      OnlineUpdateConfiguration.currentCategories = Builtins.sort(
        OnlineUpdateConfiguration.currentCategories
      ) do |a, b|
        Ops.less_than(a, b)
      end
      newcat = Builtins.maplist(OnlineUpdateConfiguration.currentCategories) do |onecat|
        onecat = Builtins.filterchars(
          onecat,
          "abcdefghijklmnopqrstuvwxyz0123456789-_."
        )
        Ops.get(OnlineUpdateConfiguration.defaultCategories, onecat) do
          Item(Id(onecat), onecat)
        end
      end
      UI.ChangeWidget(Id(:categories), :Items, newcat)

      if selected != nil && selected != ""
        UI.ChangeWidget(Id(:categories), :CurrentItem, selected)
      end

      nil
    end
  end
end
