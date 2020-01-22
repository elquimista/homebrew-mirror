# frozen_string_literal: true

class FetchBottlePackages
  HTML_CRAWLING_PAGE_SIZE = 8

  attr_accessor :packages

  def initialize
    @packages = load_packages_info
  end

  def run
    puts '[Fetching bottle packages...]'.light_blue
    validate_or_initialize_package_count
    fetch_via_html_crawling
    puts '[Fetching bottle packages, done.]'.light_blue
  end

  private

  def validate_or_initialize_package_count
    if packages['count'].blank?
      bar = ProgressBar.new('Initializing local cache:done', total: 2)
      bar.advance
      packages.merge! 'count' => package_count, 'offset' => 0, 'names' => []
      save_packages_info
      bar.advance
    else
      bar = ProgressBar.new('Validating local cache:done', total: 2)
      bar.advance; package_count; bar.advance
      unless packages['count'] == package_count
        bar = ProgressBar.new(<<~FORMAT.strip, total: 2)
          #{'Total package counts mismatch.'.light_magenta} Invalidating local cache:done
        FORMAT
        bar.advance
        packages.merge! 'count' => package_count, 'offset' => 0, 'names' => []
        save_packages_info
        bar.advance
      end
    end

    puts "Total packages: #{package_count}"
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
