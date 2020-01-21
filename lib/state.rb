# frozen_string_literal: true

require 'singleton'

class State
  include Singleton

  attr_accessor :state

  def self.save
    puts 'Saving state...'
  end
end
