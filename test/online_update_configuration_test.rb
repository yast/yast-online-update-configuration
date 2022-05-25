# Copyright (c) [2022] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require_relative "test_helper"

Yast.import "OnlineUpdateConfiguration"

describe Yast::OnlineUpdateConfiguration do
  before { subject.main }

  let(:profile) do
  {
      "enable_automatic_online_update" => true,
      "skip_interactive_patches"       => false,
      "auto_agree_with_licenses"       => true,
      "use_deltarpm"                   => true,
      "include_recommends"             => false,
      "update_interval"                => "daily",
      "category_filter"                => { "category" => ["security"] }
    }
  end

  describe "#Import" do

    it "imports online update settings" do
      subject.Import(profile)
      expect(subject.enableAOU).to eq(true)
      expect(subject.skipInteractivePatches).to eq(false)
      expect(subject.autoAgreeWithLicenses).to eq(true)
      expect(subject.use_deltarpm).to eq(true)
      expect(subject.includeRecommends).to eq(false)
      expect(subject.updateInterval).to eq(:daily)
      expect(subject.currentCategories).to eq(["security"])
    end
  end

  describe "#Export" do
    it "exports online update settings" do
      subject.Import(profile)
      expect(subject.Export).to eq(profile)
    end
  end
end
