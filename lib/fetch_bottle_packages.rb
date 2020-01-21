# frozen_string_literal: true

require 'base64'
require 'json'
require 'yaml'
require_relative 'state'

class FetchBottlePackages
  class ProgressBarDoneFormatter
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

  BINTRAY_API_BASE = 'https://bintray.com/api/v1'
  HTML_CRAWLING_PAGE_SIZE = 8

  attr_accessor :packages

  def initialize
    @packages = load_packages_info
  end

  def run
    verify_or_initialize_package_count
    if bintray_api_auth.present?
      fetch_via_api
    else
      fetch_via_html_crawling
    end
  end

  private

  def verify_or_initialize_package_count
    unless packages['count'] == package_count
      unless packages['count'].nil?
        puts 'Package count mismatch found!'.light_magenta
        puts 'Fetching package names is starting over...'
      end

      puts "Total package count: #{package_count}"
      packages.merge! 'count' => package_count, 'offset' => 0, 'names' => []
      save_packages_info
    end
  end

  def package_count
    @package_count ||= begin
      url = "#{BINTRAY_API_BASE}/repos/homebrew/bottles"
      response = RestClient.get(url)
      JSON.parse(response.body)['package_count']
    end
  end

  def fetch_via_api
    # NOTE: Although using APIs is more reliable than crawling html contents,
    # Bintray's REST API imposes rate limits to this specific endpoint, unless
    # the authenticated user is the owner of the repository (i.e. homebrew).
    # 300 queries a day, and 1440 per month. As of Jan 2020, there are ~6400
    # packages deployed on homebrew bintray repository, and the max page size
    # is 50, so 128 queries are easily consumed by single script invocation.
    # Plus, it requires script users to have their own Bintray accounts (because
    # this endpoint requires API key) and this is probably an inconvenience.
    raise 'Not Implemented'
    # url = "#{BINTRAY_API_BASE}/repos/homebrew/bottles/packages"
    # headers = { authorization: bintray_api_auth }
    # RestClient.get(url, headers.merge(start_pos: 0))
  end

  def fetch_via_html_crawling
    url = 'https://bintray.com/homebrew/bottles'
    headers = { content_type: 'application/x-www-form-urlencoded' }
    bar = TTY::ProgressBar.new(
      'Fetching package names (via HTML crawling): :percent (:current/:total):done',
      total: packages['count']
    )
    bar.use ProgressBarDoneFormatter
    bar.advance packages['offset']

    while packages['offset'] < packages['count']
      payload = { offset: packages['offset'] }
      response = RestClient.post(url, payload, headers)
      doc = Nokogiri::HTML.parse(response.body)
      doc.css('#block-packages .package-name > a').each do |link|
        packages['names'] << link.content.strip
        bar.advance
      end
      packages['offset'] += HTML_CRAWLING_PAGE_SIZE
      save_packages_info
    end
  end

  def bintray_api_auth
    username = ENV['BINTRAY_API_USERNAME']
    password = ENV['BINTRAY_API_KEY']
    return nil if username.blank? || password.blank?
    ['Bearer', Base64.strict_encode64("#{username}:#{password}")].join(' ')
  end

  def packages_file_path
    File.join(__dir__, '..', 'data', 'bottle_packages.yml')
  end

  def load_packages_info
    if File.exist?(packages_file_path)
      YAML.load_file(packages_file_path) || {}
    else
      {}
    end
  end

  def save_packages_info
    File.write(packages_file_path, packages.to_yaml)
  end
end
