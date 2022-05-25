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
# File:    modules/OnlineUpdateConfiguration.ycp
# Package: Online Update Configuration
# Summary: Online Update Configuration
# Authors: J. Daniel Schmidt <jdsn@suse.de>
#
# $Id: OnlineUpdateConfiguration.ycp 1 2008-09-10 09:45:05Z jdsn $
require "yast"
require "online-update-configuration/zypp_config"

module Yast
  class OnlineUpdateConfigurationClass < Module
    attr_reader :zypp_config

    def main
      Yast.import "Pkg"

      Yast.import "Package"
      Yast.import "URL"

      textdomain "online-update-configuration"

      @zypp_config = ZyppConfig.new

      @enableAOU = false
      @skipInteractivePatches = true
      @autoAgreeWithLicenses = false
      @includeRecommends = false
      @use_deltarpm = zypp_config.use_deltarpm?
      @updateInterval = :weekly
      @currentCategories = []
      @OUCmodified = false


      @onlineUpdateScript = "/usr/lib/YaST2/bin/online_update"

      @cronFileName = "opensuse.org-online_update"
      @cronMonthlyFile = Ops.add("/etc/cron.monthly/", @cronFileName)
      @cronWeeklyFile = Ops.add("/etc/cron.weekly/", @cronFileName)
      @cronDailyFile = Ops.add("/etc/cron.daily/", @cronFileName)

      @currentUpdateRepo = ""
      @defaultUpdateRepo = ""
      @allUpdateRepos = []
      @defaultRegistrationURL = ""

      # cache the base product details
      @baseProductDetail = {}

      @Intervals = {
        :daily   => { :name => "daily", :trans => _("daily") },
        :weekly  => { :name => "weekly", :trans => _("weekly") },
        :monthly => { :name => "monthly", :trans => _("monthly") }
      }

      @defaultCategories = {
        #translators: this name is a (technical) category for an update package
        "yast"        => Item(
          Id("yast"),
          _("Packagemanager and YaST")
        ),
        #translators: this name is a (technical) category for an update package
        "security"    => Item(
          Id("security"),
          _("Security")
        ),
        #translators: this name is a (technical) category for an update package
        "recommended" => Item(
          Id("recommended"),
          _("Recommended")
        ),
        #translators: this name is a (technical) category for an update package
        "optional"    => Item(
          Id("optional"),
          _("Optional")
        ),
        #translators: this name is a (technical) category for an update package: Document, meaning Documentation
        "document"    => Item(
          Id("document"),
          _("Document")
        ),
        #translators: this name is a (technical) category for an update package
        "other"       => Item(
          Id("other"),
          _("Other")
        )
      }
    end

    # fetchBaseProductDetails
    # get the details of the base product to find its default update Source or registration server
    # the found base product will be saved in the cache variable  baseProductDetail
    #
    # @return true if a base product is found, else false
    def fetchBaseProductDetails
      Builtins.y2milestone("Searching base product details.")

      # fetch product details about installed products
      productDetail = Pkg.ResolvableProperties("", :product, "")
      @baseProductDetail = {}

      #FIXME START
      #FIXME: 1) pkg-bindings return only addon products for openSUSE (bnc#449844)
      #FIXME: 2) the product definition does not contain update URLS (bnc#449842)
      #FIXME: If either of these remain unfixed the following two lines need to be uncommented,
      #FIXME: otherwise restoring of the default update repo is only possible via NCC registration
      # productDetail[0, "category"]="base";
      # productDetail[0, "update_urls"] = ["http://download.opensuse.org/update/11.2/"];
      #FIXME END

      Builtins.y2debug("All installed products are: %1", productDetail)
      Builtins.y2debug("Now looking for the base product")

      # filter the map to find the one any only base product
      productDetail = Builtins.filter(productDetail) do |oneProduct|
        Ops.get_string(oneProduct, "category", "unknown") == "base"
      end

      Builtins.y2debug("All installed base products are: %1", productDetail)
      if Ops.less_than(Builtins.size(productDetail), 1)
        Builtins.y2error("Could not find any base product.")
        @baseProductDetail = {}
        return false
      elsif Ops.greater_than(Builtins.size(productDetail), 1)
        Builtins.y2error(
          "Found more than one base product. This is a severe problem as there may only be one base product."
        )
        Builtins.y2error(
          "This system seems to be broken. However the first found product will be used."
        )
      else
        Builtins.y2milestone("Found exactly one base product.")
      end

      @baseProductDetail = Ops.get(productDetail, 0, {})
      Builtins.y2milestone("Found a base product: %1", @baseProductDetail)

      true
    end

    # compareUpdateURLs
    # compare two URLs - only the scheme, hostname and path will be compared, a trailing slash will be ignored
    # @return true if urls match
    def compareUpdateURLs(url1, url2, allowEmpty)
      Builtins.y2debug("Comparing two urls.")
      return false if url1 == "" && url2 == "" && !allowEmpty

      url1map = URL.Parse(url1)
      url2map = URL.Parse(url2)

      # removing trailing slash
      if Builtins.regexpmatch(Ops.get_string(url1map, "path", ""), "/$")
        Ops.set(
          url1map,
          "path",
          Builtins.regexpsub(
            Ops.get_string(url1map, "path", ""),
            "(.*)/$",
            "\\1"
          )
        )
      end
      if Builtins.regexpmatch(Ops.get_string(url2map, "path", ""), "/$")
        Ops.set(
          url2map,
          "path",
          Builtins.regexpsub(
            Ops.get_string(url2map, "path", ""),
            "(.*)/$",
            "\\1"
          )
        )
      end

      if Builtins.tolower(Ops.get_string(url1map, "scheme", "X")) ==
          Builtins.tolower(Ops.get_string(url2map, "scheme", "Y")) &&
          Builtins.tolower(Ops.get_string(url1map, "host", "X")) ==
            Builtins.tolower(Ops.get_string(url2map, "host", "Y")) &&
          Ops.get_string(url1map, "path", "X") ==
            Ops.get_string(url2map, "path", "Y")
        return true
      end

      false
    end


    # fetchBaseProductURLs
    # fetches the default update repo URL and the registration server URL and saves them in the global variables
    #
    # @return true if successfull
    def fetchBaseProductURLs
      defUp = ""
      defReg = ""

      if @defaultUpdateRepo == nil || @defaultUpdateRepo == ""
        Builtins.y2milestone("Looking for default update repo.")
        fetchBaseProductDetails
      end

      if @baseProductDetail == nil || @baseProductDetail == {}
        Builtins.y2error(
          "Could not find any details about the base product and thus no default update repo."
        )
        return false
      else
        # handle default update repository
        updateURLs = Ops.get_list(@baseProductDetail, "update_urls", [])
        @allUpdateRepos = deep_copy(updateURLs)

        if Ops.less_than(Builtins.size(updateURLs), 1)
          Builtins.y2error(
            "Base product does not provide a default update repository."
          )
          defUp = ""
        elsif Builtins.size(updateURLs) == 1
          Builtins.y2milestone("Found exactly one default update URL.")
          defUp = Ops.get(updateURLs, 0, "")
        else
          Builtins.y2milestone(
            "Found multiple default update repositories. Will pick one as default."
          )
          # first looking for opensuse.org update repos
          filteredUpdateURLs = Builtins.filter(updateURLs) do |oneURL|
            Builtins.regexpmatch(oneURL, ".opensuse.org")
          end

          if Ops.less_than(Builtins.size(filteredUpdateURLs), 1)
            filteredUpdateURLs = Builtins.filter(updateURLs) do |oneURL|
              Builtins.regexpmatch(oneURL, ".novell.com")
            end
          end

          if Ops.less_than(Builtins.size(filteredUpdateURLs), 1)
            # no opensuse.org or novell.com update repo found
            Builtins.y2milestone("Will use the first found update repository.")
            defUp = Ops.get(updateURLs, 0, "")
          elsif Builtins.size(filteredUpdateURLs) == 1
            Builtins.y2milestone(
              "Will use default opensuse.org resp. novell.com update repository."
            )
            defUp = Ops.get(filteredUpdateURLs, 0, "")
          else
            Builtins.y2milestone(
              "After filtering still multiple cadidates remain as default update repository."
            )
            Builtins.y2milestone(
              "Will now use the first found update repository."
            )
            defUp = Ops.get(filteredUpdateURLs, 0, "")
          end
        end

        # handle default registration server
        registerURLs = Ops.get_list(@baseProductDetail, "register_urls", [])
        if Ops.less_than(Builtins.size(registerURLs), 1)
          Builtins.y2error("No default registration URL found.")
          defReg = ""
        elsif Builtins.size(registerURLs) == 1
          Builtins.y2milestone("Found exactly one registration URL.")
          defReg = Ops.get(registerURLs, 0, "")
        else
          Builtins.y2milestone(
            "Found multiple registration URLs. Will pick one as default."
          )
          # first looking for novell.com registration URLs
          filteredRegisterURLs = Builtins.filter(registerURLs) do |oneURL|
            Builtins.regexpmatch(oneURL, ".novell.com")
          end

          if Ops.less_than(Builtins.size(filteredRegisterURLs), 1)
            filteredRegisterURLs = Builtins.filter(registerURLs) do |oneURL|
              Builtins.regexpmatch(oneURL, ".opensuse.org")
            end
          end

          if Ops.less_than(Builtins.size(filteredRegisterURLs), 1)
            # no opensuse.org or novell.com update repo found
            Builtins.y2milestone("Will use the first found registration URL.")
            defReg = Ops.get(registerURLs, 0, "")
          elsif Builtins.size(filteredRegisterURLs) == 1
            Builtins.y2milestone(
              "Will use default novell.com resp. opensuse.org registration URL."
            )
            defReg = Ops.get(filteredRegisterURLs, 0, "")
          else
            Builtins.y2milestone(
              "After filtering still multiple cadidates remain as default registration URL."
            )
            Builtins.y2milestone(
              "Will now use the first found registration URL."
            )
            defReg = Ops.get(filteredRegisterURLs, 0, "")
          end
        end
      end

      @defaultUpdateRepo = defUp
      @defaultRegistrationURL = defReg
      logUpdateRepoMap = URL.Parse(@defaultUpdateRepo)
      if Ops.get_string(logUpdateRepoMap, "pass", "") != nil &&
          Ops.get_string(logUpdateRepoMap, "pass", "") != ""
        Ops.set(logUpdateRepoMap, "pass", "--a-password-is-set--")
      end
      logUpdateRepo = URL.Build(logUpdateRepoMap)

      Builtins.y2milestone(
        "Found default update repository is: %1",
        logUpdateRepo
      )
      Builtins.y2milestone(
        "Using this default registration URL: %1",
        @defaultRegistrationURL
      )
      Builtins.y2milestone(
        "This registration URL will not be written to the system. The registration module itself will offer to change the default registration URL. Here the URL is used just to find out if this product can be registered."
      )

      true
    end

    # fetchCurrentUpdateRepoURL
    # returns the currentUpdateRepoURL or and updates the global variable that caches this value
    def fetchCurrentUpdateRepoURL
      curUp = ""

      if Ops.less_than(Builtins.size(@allUpdateRepos), 1)
        Builtins.y2error(
          "No current update repos found to compare the default update repo with."
        )
        curUp = ""
      else
        allCurrentRepos = Pkg.SourceGetCurrent(true)
        if Ops.less_than(Builtins.size(allCurrentRepos), 1)
          Builtins.y2milestone("No current sources found.")
          curUp = ""
        else
          foundUpdateRepo = []

          Builtins.foreach(allCurrentRepos) do |repoID|
            repoURL = Pkg.SourceURL(repoID)
            Builtins.foreach(@allUpdateRepos) do |upRepo|
              if compareUpdateURLs(repoURL, upRepo, false)
                foundUpdateRepo = Builtins.add(foundUpdateRepo, repoURL)
              end
            end
          end

          if Ops.less_than(Builtins.size(foundUpdateRepo), 1)
            Builtins.y2milestone("Could not find any update repo in the system")
          elsif Builtins.size(foundUpdateRepo) == 1
            Builtins.y2milestone("Found exactly one update repo.")
            curUp = Ops.get(foundUpdateRepo, 0, "")
            # found an update repo in the system that is provided by the product as well - so it is the default
            @defaultUpdateRepo = curUp
          else
            Builtins.y2milestone(
              "Found multiple update repos. Will only use the first one."
            )
            curUp = Ops.get(foundUpdateRepo, 0, "")
            # found an update repo in the system that is provided by the product as well - so it is the default
            @defaultUpdateRepo = curUp
          end
        end
      end

      @currentUpdateRepo = curUp
      Builtins.y2milestone("Current update repo is: %1", @currentUpdateRepo)
      curUp
    end



    def setUpdateRepo(updateRepo)
      Builtins.y2milestone(
        "User wants to set the default update repo to: %1",
        updateRepo
      )

      # create map for new source
      newSrcMap = {
        "enabled"     => true,
        "autorefresh" => true,
        "name"        => "Default-Update-Repository",
        "alias"       => "Default-Update-Repository",
        "base_urls"   => [updateRepo],
        "priority"    => 20
      }

      Builtins.y2milestone("Adding new update repository.")
      newSrcID = Pkg.RepositoryAdd(newSrcMap)
      if newSrcID != nil
        Builtins.y2milestone(
          "Successfully added the default update repository to the system."
        )
        @currentUpdateRepo = updateRepo
      else
        Builtins.y2error(
          "Could not add the default update repository to the system."
        )
      end

      Builtins.y2milestone("Saving all source changes to the system.")
      Pkg.SourceSaveAll

      true
    end

    def intervalSymbolToString(intervalSym, strType)
      i = Ops.get(@Intervals, intervalSym, {})
      Ops.get(i, strType, "none")
    end

    def intervalStringToSymbol(intervalStr)
      result = :none
      Builtins.foreach(@Intervals) do |sym, i|
        result = sym if Ops.get(i, :name, "none") == intervalStr
        nil
      end
      result
    end

    # remove all online update cronjobs
    #
    def removeOnlineUpdateCronjobs
      SCR.Execute(path(".target.remove"), @cronMonthlyFile)
      SCR.Execute(path(".target.remove"), @cronWeeklyFile)
      SCR.Execute(path(".target.remove"), @cronDailyFile)

      nil
    end

    # setup cronjob for an automatic online update
    # @param interval [Symbol] for the interval `daily, `weekly, `monthly
    # @return true if successful
    def setOnlineUpdateCronjob(interval)
      cronSel = ""
      if interval == :monthly
        cronSel = @cronMonthlyFile
      elsif interval == :weekly
        cronSel = @cronWeeklyFile
      elsif interval == :daily
        cronSel = @cronDailyFile
      end

      removeOnlineUpdateCronjobs

      if Convert.to_boolean(
          SCR.Execute(path(".target.symlink"), @onlineUpdateScript, cronSel)
        )
        Builtins.y2milestone("Setting up online update cron job at %1", cronSel)
        return true
      else
        Builtins.y2error(
          "Could not create online update cron job at %1",
          cronSel
        )
        return false
      end

      true
    end




    # Read()
    def Read
      # just for documentation: defaultUpdateRepo for 11.1 should be "http://download.opensuse.org/update/11.1/"

      if fetchBaseProductDetails
        Builtins.y2milestone("Fetched base product detail information")
      else
        Builtins.y2error("Could not fetch base product details information.")
      end

      # read base URLs from the base product
      fetchBaseProductURLs
      # this will update the default update repo as well - so do it once here
      foo = fetchCurrentUpdateRepoURL

      interM = Convert.to_integer(
        SCR.Read(path(".target.size"), @cronMonthlyFile)
      )
      interW = Convert.to_integer(
        SCR.Read(path(".target.size"), @cronWeeklyFile)
      )
      interD = Convert.to_integer(
        SCR.Read(path(".target.size"), @cronDailyFile)
      )

      if Ops.greater_or_equal(interD, 0)
        @updateInterval = :daily
      elsif Ops.greater_or_equal(interW, 0)
        @updateInterval = :weekly
      elsif Ops.greater_or_equal(interM, 0)
        @updateInterval = :monthly
      else
        @updateInterval = :weekly
      end

      # enableAOU is not read from sysconfig! this is only to deactivate it temporarily
      # only the fact that a cronjob exists makes this setting true
      @enableAOU = Ops.greater_or_equal(interD, 0) ||
        Ops.greater_or_equal(interW, 0) ||
        Ops.greater_or_equal(interM, 0)
      @skipInteractivePatches = Convert.to_string(
        SCR.Read(
          path(
            ".sysconfig.automatic_online_update.AOU_SKIP_INTERACTIVE_PATCHES"
          )
        )
      ) == "true" ? true : false
      @autoAgreeWithLicenses = Convert.to_string(
        SCR.Read(
          path(
            ".sysconfig.automatic_online_update.AOU_AUTO_AGREE_WITH_LICENSES"
          )
        )
      ) == "true" ? true : false
      @includeRecommends = Convert.to_string(
        SCR.Read(
          path(".sysconfig.automatic_online_update.AOU_INCLUDE_RECOMMENDS")
        )
      ) == "true" ? true : false
      patchCategories = Convert.to_string(
        SCR.Read(
          path(".sysconfig.automatic_online_update.AOU_PATCH_CATEGORIES")
        )
      )

      @currentCategories = Builtins.splitstring(patchCategories, " ")
      @currentCategories = Builtins.filter(@currentCategories) do |s|
        s != nil && s != ""
      end

      nil
    end


    # Import()
    def Import(settings)
      settings = deep_copy(settings)
      @enableAOU = false
      @skipInteractivePatches = true
      @updateInterval = :weekly

      @enableAOU = Ops.get_boolean(
        settings,
        "enable_automatic_online_update",
        @enableAOU
      )
      @skipInteractivePatches = Ops.get_boolean(
        settings,
        "skip_interactive_patches",
        @skipInteractivePatches
      )
      @autoAgreeWithLicenses = Ops.get_boolean(
        settings,
        "auto_agree_with_licenses",
        @autoAgreeWithLicenses
      )
      @includeRecommends = Ops.get_boolean(
        settings,
        "include_recommends",
        @includeRecommends
      )
      @use_deltarpm = settings.fetch('use_deltarpm', @use_deltarpm)

      @currentCategories = get_category_filter(settings["category_filter"])

      getInterval = Ops.get_string(settings, "update_interval", "")

      @enableAOU = false if @enableAOU == nil
      @updateInterval = intervalStringToSymbol(getInterval)
      # fall back to weekly in error case
      @updateInterval = :weekly if @updateInterval == :none

      true
    end

    # Write()
    def Write
      SCR.Write(
        path(".sysconfig.automatic_online_update.AOU_ENABLE_CRONJOB"),
        @enableAOU == true ? "true" : "false"
      )
      SCR.Write(
        path(".sysconfig.automatic_online_update.AOU_SKIP_INTERACTIVE_PATCHES"),
        @skipInteractivePatches == true ? "true" : "false"
      )
      SCR.Write(
        path(".sysconfig.automatic_online_update.AOU_AUTO_AGREE_WITH_LICENSES"),
        @autoAgreeWithLicenses == true ? "true" : "false"
      )
      SCR.Write(
        path(".sysconfig.automatic_online_update.AOU_INCLUDE_RECOMMENDS"),
        @includeRecommends == true ? "true" : "false"
      )
      @use_deltarpm ? zypp_config.activate_deltarpm : zypp_config.deactivate_deltarpm
      catConf = ""
      if Ops.greater_than(Builtins.size(@currentCategories), 0)
        catConf = Builtins.mergestring(@currentCategories, " ")
      end
      SCR.Write(
        path(".sysconfig.automatic_online_update.AOU_PATCH_CATEGORIES"),
        catConf
      )

      if @enableAOU
        Builtins.y2milestone(
          "Enabling automatic online update with interval: %1",
          @updateInterval
        )
        return setOnlineUpdateCronjob(@updateInterval)
      else
        Builtins.y2milestone("Automatic online update is disabled.")
        removeOnlineUpdateCronjobs
        return true
      end

      true
    end



    # AutoYaST interface function: Export()
    # @return [Hash] with the settings
    def Export
      return {} if !@enableAOU

      {
        "enable_automatic_online_update" => @enableAOU,
        "skip_interactive_patches"       => @skipInteractivePatches,
        "auto_agree_with_licenses"       => @autoAgreeWithLicenses,
        "include_recommends"             => @includeRecommends,
        "use_deltarpm"                  => @use_deltarpm,
        "update_interval"                => intervalSymbolToString(
          @updateInterval,
          :name
        ),
        "category_filter"                => @currentCategories
      }
    end

    publish :variable => :enableAOU, :type => "boolean"
    publish :variable => :skipInteractivePatches, :type => "boolean"
    publish :variable => :autoAgreeWithLicenses, :type => "boolean"
    publish :variable => :includeRecommends, :type => "boolean"
    publish :variable => :use_deltarpm, :type => "boolean"
    publish :variable => :updateInterval, :type => "symbol"
    publish :variable => :currentCategories, :type => "list <string>"
    publish :variable => :OUCmodified, :type => "boolean"
    publish :variable => :currentUpdateRepo, :type => "string"
    publish :variable => :defaultUpdateRepo, :type => "string"
    publish :variable => :allUpdateRepos, :type => "list <string>"
    publish :variable => :defaultRegistrationURL, :type => "string"
    publish :variable => :Intervals, :type => "map <symbol, map <symbol, string>>"
    publish :variable => :defaultCategories, :type => "map <string, term>"
    publish :function => :compareUpdateURLs, :type => "boolean (string, string, boolean)"
    publish :function => :fetchBaseProductURLs, :type => "boolean ()"
    publish :function => :fetchCurrentUpdateRepoURL, :type => "string ()"
    publish :function => :setUpdateRepo, :type => "boolean (string)"
    publish :function => :intervalSymbolToString, :type => "string (symbol, symbol)"
    publish :function => :intervalStringToSymbol, :type => "symbol (string)"
    publish :function => :setOnlineUpdateCronjob, :type => "boolean (symbol)"
    publish :function => :Read, :type => "void ()"
    publish :function => :Import, :type => "boolean (map)"
    publish :function => :Write, :type => "boolean ()"
    publish :function => :Export, :type => "map ()"

  private

    def get_category_filter(category_filter)
      return category_filter if category_filter.is_a?(Array)

      return category_filter.fetch("category", []) if category_filter.is_a?(Hash)

      []
    end

  end

  OnlineUpdateConfiguration = OnlineUpdateConfigurationClass.new
  OnlineUpdateConfiguration.main
end
