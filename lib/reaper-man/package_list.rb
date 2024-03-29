require "multi_json"
require "reaper-man"

module ReaperMan
  # Package list for repository
  class PackageList
    # Package list modification processor
    class Processor
      autoload :Rpm, "reaper-man/package_list/rpm"
      autoload :Deb, "reaper-man/package_list/deb"
      autoload :Gem, "reaper-man/package_list/gem"

      include Utils::Process
      include Utils::Checksum

      def initialize(_ = {})
      end

      # Add a package to the list
      #
      # @param conf [Hash]
      # @param package [String] path to package
      def add(conf, package)
        raise NoMethodError.new "Not implemented"
      end

      # Remove package from the list
      #
      # @param conf [Hash] configuration hash
      # @param package_name [String] name
      # @param version [String]
      def remove(conf, package_name, version = nil)
        raise NoMethodError.new "Not implemented"
      end
    end

    # @return [String] path to list file
    attr_reader :path
    # @return [Hash] configuration
    attr_reader :options
    # @return [Time] package list mtime
    attr_reader :init_mtime
    # @return [Hash] content of package list
    attr_reader :content

    # Create new instance
    #
    # @param path [String] path to package list
    # @param args [Hash] configuration
    def initialize(path, args = {})
      if path.nil? || path.empty?
        raise ArgumentError, "Path is required"
      end
      @path = path
      @options = args.dup
      @content = Smash.new
      init_list!
    end

    # Add package to package list file
    #
    # @param package [Array<String>] path to package file
    def add_package(package)
      [package_handler(File.extname(package).tr(".", "")).add(content, package)].flatten.compact
    end

    # Remove package from the package list file
    #
    # @param package [String] name of package
    # @param version [String] version of file
    def remove_package(package, version = nil)
      ext = File.extname(package).tr(".", "")
      if ext.empty?
        ext = %w(deb) # rpm)
      else
        ext = [ext]
      end
      ext.each do |ext_name|
        package_handler(ext_name).remove(content, package, version)
      end
    end

    # @return [String] serialized content
    def serialize
      MultiJson.dump(content)
    end

    # Write contents to package list file
    #
    # @return [Integer] number of bytes written
    def write!
      new_file = !File.exists?(path)
      File.open(path, File::CREAT | File::RDWR) do |file|
        file.flock(File::LOCK_EX)
        if !new_file && init_mtime != file.mtime
          file.rewind
          content.deep_merge!(
            MultiJson.load(
              file.read
            )
          )
          file.rewind
        end
        pos = file.write MultiJson.dump(content, :pretty => true)
        file.truncate(pos)
      end
    end

    private

    # @return [Processor] processor for give package type
    def package_handler(pkg_ext)
      Processor.const_get(pkg_ext.capitalize).new(options)
    end

    # Initialize the package list file
    #
    # @return [Hash] loaded file contents
    def init_list!
      write! unless File.exist?(path)
      @init_mtime = File.mtime(path)
      content.deep_merge!(
        MultiJson.load(
          File.open(path, "r") do |file|
            file.flock(File::LOCK_SH)
            file.read
          end
        )
      )
    end
  end
end
