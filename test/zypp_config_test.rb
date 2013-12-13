#!/usr/bin/env rspec

require_relative 'test_helper'

describe ZyppConfig do
  attr_reader :config

  it "provides config value for delta rpms if explicitly activated" do
    ZyppConfig.any_instance.stub(:get_delta_rpm_config_value).and_return('true')
    expect(ZyppConfig.new.use_delta_rpm?).to eq(true)
  end

  it "provides config value for delta rpms if using default settings" do
    ZyppConfig.any_instance.stub(:get_delta_rpm_config_value).and_return(nil)
    expect(ZyppConfig.new.use_delta_rpm?).to eq(true)
  end

  it "provides config value for delta rpms if explicitly deactivated" do
    ZyppConfig.any_instance.stub(:get_delta_rpm_config_value).and_return('false')
    expect(ZyppConfig.new.use_delta_rpm?).to eq(false)
  end

  it "can activate and deactivate use of delta rpms in zypp config" do
    ZyppConfig.any_instance.stub(:get_delta_rpm_config_value)
    ZyppConfig.any_instance.stub(:set_delta_rpm_config_value)
    config = ZyppConfig.new
    expect(config).to receive(:set_delta_rpm_config_value).with(true)
    expect(config.activate_delta_rpm)

    expect(config).to receive(:set_delta_rpm_config_value).with(false)
    expect(config.deactivate_delta_rpm)
  end
end
