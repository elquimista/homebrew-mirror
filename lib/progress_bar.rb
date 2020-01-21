# frozen_string_literal: true

class ProgressBar < TTY::ProgressBar
  class DoneFormatter
    def initialize(progress)
      @progress = progress
    end

    def matches?(value)
      value.to_s =~ /:\bdone\b/
    end

    def format(value)
      transformed = @progress.current == @progress.total ? ', done.' : ''
      value.gsub(/:\bdone\b/, transformed)
    end
  end

  def initialize(*)
    super
    use DoneFormatter
  end
end
