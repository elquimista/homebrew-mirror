# frozen_string_literal: true

class DownloadBottleFiles
  BOTTLE_FILES_FILE_PATH = File.join(DATA_PATH, 'bottle_files.yml')
  BOTTLES_PATH = File.join(DATA_PATH, 'bottles')

  attr_reader :packages
  attr_reader :files

  def initialize(options)
    os = options.fetch(:os, 'catalina')
    @os_pattern = Regexp.new("\\b(?<os>#{os.split(',').join('|')}).bottle.")
    @packages = YAML.load_file(BOTTLE_PACKAGES_FILE_PATH)
    @files = load_files_info
  end

  def run
    at_exit do
      save_files_info
      `rm -rf #{File.join(BOTTLES_PATH, '**', '*.tmp')}`
    end

    puts '[Downloading bottle files...]'.light_blue
    while State.data['bottle_files_offset'] < packages['count']
      pkg_name = packages['names'][State.data['bottle_files_offset']]
      url = "#{BINTRAY_API_BASE}/packages/homebrew/bottles/#{pkg_name}/files"
      response = RestClient.get(url)
      json = JSON.parse(response.body)
      files[pkg_name] ||= []
      downloaded_files = files[pkg_name].dup
      skipped = false

      json.each do |item|
        (print 'S'; skipped = true; next) unless matches = item['name'].match(@os_pattern)
        (print '.'; skipped = true; next) if downloaded_files.include?(item['name'])

        puts if skipped
        skipped = false

        bottles_os_path = File.join(BOTTLES_PATH, matches[:os])
        `mkdir -p #{bottles_os_path}`
        Dir.chdir(bottles_os_path) do
          `rm -rf #{item['name']}`
          `wget -O #{item['name']}.tmp -q --show-progress --progress=bar:force https://homebrew.bintray.com/bottles/#{item['path']}`
          `mv #{item['name']}.tmp #{item['name']}`
          `tar rf #{pkg_name}.tar #{item['name']}`
          `rm #{item['name']}`
        end
        files[pkg_name] << item['name']
      end

      State.data['bottle_files_offset'] += 1
    end

    State.data['bottle_files_offset'] = 0
    puts '[Downloading bottle files, done.]'.light_blue
  end

  private

  def load_files_info
    if File.exist?(BOTTLE_FILES_FILE_PATH)
      YAML.load_file(BOTTLE_FILES_FILE_PATH) || {}
    else
      {}
    end
  end

  def save_files_info
    File.write(BOTTLE_FILES_FILE_PATH, files.to_yaml)
  end
end
