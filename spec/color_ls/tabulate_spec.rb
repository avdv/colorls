require 'spec_helper'

# class HasDimension < RSpec::Matchers::BaseMatcher
#   def initialize(dims)
#     @dims = dims
#   end

#   # @api private
#   # @return [String]
#   def description
#     "has dimensions #{@dims}"
#   end

#   def matches?(actual)
#     @actual = actual
#     #comparable? && compare
#     puts "got #{actual}, check #{@dims}"
#     0 ... @dims.length do |i|
#       return false unless @actual.size == i
#     end
#     true
#   rescue ArgumentError
#     false
#   end
# end

RSpec.describe ColorLS::Tabulate do
  #def have_dimension(*dims)
  #  HasDimension(dims)
  #end

  subject { described_class.new(array) }

  context 'with horizontal layout' do
    let(:array) { ['c' * 20] + ['a' * 5] * 10 }

    it 'should be on a single column if one item is too large' do
      expect(subject.layout(21).size).to eq(1)
    end

    it 'should be two columns if one item is too large' do
      expect(subject.layout(21).size).to eq(1)
    end

  end
end

