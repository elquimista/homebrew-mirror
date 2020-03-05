# frozen_string_literal: true

class DownloadNonBottleFiles
  HOMEBREW_CORE_REMOTE = ENV.fetch('HOMEBREW_CORE_REMOTE', 'https://github.com/Homebrew/homebrew-core')
  HOMEBREW_CORE_REPO = File.join(DATA_PATH, 'homebrew-core')
  ARTIFACT_FILES_FILE_PATH = File.join(DATA_PATH, 'non_bottle_files.yml')
  ARTIFACTS_PATH = File.join(DATA_PATH, 'non-bottles')

  attr_reader :files

  def initialize
    @files = load_files_info
  end

  def run
    at_exit do
      save_files_info
      `rm -rf #{File.join(ARTIFACTS_PATH, '**', '*.tmp')}`
    end

    clone_homebrew_core unless Dir.exist?(HOMEBREW_CORE_REPO)

    puts '[Downloading non-bottle files...]'.light_blue
    skipped = false

    Dir["#{HOMEBREW_CORE_REPO}/Formula/*.rb"].each do |file|
      class_matcher = s { q(:class, _, q(:const, :Formula), ___) }
      class_sexp, = class_matcher / RubyParser.new.parse(File.read(file))
      bottle_block_matcher = s { q(:call, nil, :bottle) }
      next if bottle_block_matcher =~ class_sexp

      url_method_matcher = s { q(:call, nil, :url, ___) }
      (_, _, _, *url_args), = url_method_matcher / class_sexp
      next unless url_args.size == 1
      url = url_args.first.value
      next if url.match?(/\.git\Z/)

      pkg_name = File.basename(file, '.rb')
      files[pkg_name] ||= []
      downloaded_files = files[pkg_name].dup

      (print '.'; skipped = true; next) if downloaded_files.include?(url)
      puts if skipped
      skipped = false

      uri = URI(File.dirname(url))
      dirpath = File.join(ARTIFACTS_PATH, uri.hostname, uri.path)
      `mkdir -p #{dirpath}`
      filename = File.basename(url)

      Dir.chdir(dirpath) do
        `rm -rf #{filename}`
        puts "[#{pkg_name}]"
        `wget -O #{filename}.tmp -q --show-progress --progress=bar:force #{url}`
        # TODO: remove empty file if download url returns 404
        `mv #{filename}.tmp #{filename}`
      end
      files[pkg_name] << url
    end

    puts '[Downloading non-bottle files, done.]'.light_blue
  end

  private

  def clone_homebrew_core
    `git clone --depth=1 #{HOMEBREW_CORE_REMOTE} #{HOMEBREW_CORE_REPO}`
  end

  def load_files_info
    if File.exist?(ARTIFACT_FILES_FILE_PATH)
      YAML.load_file(ARTIFACT_FILES_FILE_PATH) || {}
    else
      {}
    end
  end

  def save_files_info
    File.write(ARTIFACT_FILES_FILE_PATH, files.to_yaml)
  end
end
