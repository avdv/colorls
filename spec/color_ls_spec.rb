require 'spec_helper'

RSpec.describe ColorLS do
  it 'has a version number' do
    expect(ColorLS::VERSION).not_to be nil
  end

  context '::exit_code' do
    before(:each) {
      ColorLS.instance_variable_set :@exit_code, 0
    }

    it 'is 0 initially' do
      expect(ColorLS.exit_code).to be == 0
    end

    it 'can be set to `1`' do
      ColorLS.exit_code = 1

      expect(ColorLS.exit_code).to be == 1
    end

    it 'it does only increase' do
      ColorLS.exit_code = 2
      ColorLS.exit_code = 1

      expect(ColorLS.exit_code).to be == 2
    end
  end

end
