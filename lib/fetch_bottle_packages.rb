# frozen_string_literal: true

class FetchBottlePackages
  BINTRAY_API_BASE = 'https://bintray.com/api/v1'
  HTML_CRAWLING_PAGE_SIZE = 8

  attr_accessor :packages

  def initialize
    @packages = load_packages_info
  end

  def run
    verify_or_initialize_package_count
    fetch_via_html_crawling
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

  def fetch_via_html_crawling
    url = 'https://bintray.com/homebrew/bottles'
    headers = { content_type: 'application/x-www-form-urlencoded' }
    bar = ProgressBar.new(<<~FORMAT.strip, total: packages['count'])
      Fetching package names (via HTML crawling): :percent (:current/:total):done
    FORMAT
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
