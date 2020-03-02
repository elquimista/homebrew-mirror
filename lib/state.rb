# frozen_string_literal: true

require 'singleton'

class State
  include Singleton

  STATE_FILE_PATH = File.join(DATA_PATH, 'state.yml')

  def self.save
    File.write(STATE_FILE_PATH, data.to_yaml)
    puts 'Saving state, done.'
  end

  def self.data
    instance.data
  end

  def data
    @data ||= if File.exist?(STATE_FILE_PATH)
      YAML.load_file(STATE_FILE_PATH) || {}
    else
      {}
    end
  end
end
