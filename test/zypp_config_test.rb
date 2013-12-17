#!/usr/bin/env rspec

require_relative 'test_helper'

describe ZyppConfig do
  describe "#use_deltarpm?" do
    it "returns true if explicitly activated" do
      ZyppConfig.any_instance.stub(:get_delta_rpm_config_value).and_return('true')
      expect(ZyppConfig.new.use_deltarpm?).to eq(true)

      ZyppConfig.any_instance.stub(:get_delta_rpm_config_value).and_return('yes')
      expect(ZyppConfig.new.use_deltarpm?).to eq(true)

      ZyppConfig.any_instance.stub(:get_delta_rpm_config_value).and_return('1')
      expect(ZyppConfig.new.use_deltarpm?).to eq(true)
    end

    it "returns true if using default configuration" do
      ZyppConfig.any_instance.stub(:get_delta_rpm_config_value).and_return(nil)
      expect(ZyppConfig.new.use_deltarpm?).to eq(true)
    end

    it "returns false if explicitly deactivated" do
      ZyppConfig.any_instance.stub(:get_delta_rpm_config_value).and_return('false')
      expect(ZyppConfig.new.use_deltarpm?).to eq(false)

      ZyppConfig.any_instance.stub(:get_delta_rpm_config_value).and_return('no')
      expect(ZyppConfig.new.use_deltarpm?).to eq(false)

      ZyppConfig.any_instance.stub(:get_delta_rpm_config_value).and_return('0')
      expect(ZyppConfig.new.use_deltarpm?).to eq(false)
    end
  end

  describe "#activate_deltarpm" do
    it "activates delta rpm option in zypp config" do
      ZyppConfig.any_instance.stub(:get_delta_rpm_config_value)
      ZyppConfig.any_instance.stub(:set_delta_rpm_config_value)
      config = ZyppConfig.new
      expect(config).to receive(:set_delta_rpm_config_value).with(true)
      expect(config.activate_deltarpm)
    end
  end

  describe "#deactivate_deltarpm" do
    it "deactivates delta rpm option in zypp config" do
      ZyppConfig.any_instance.stub(:get_delta_rpm_config_value)
      ZyppConfig.any_instance.stub(:set_delta_rpm_config_value)
      config = ZyppConfig.new
      expect(config).to receive(:set_delta_rpm_config_value).with(false)
      expect(config.deactivate_deltarpm)
    end
  end
end
