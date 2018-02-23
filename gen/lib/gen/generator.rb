require 'gen'
require 'fileutils'
require 'pathname'

module Gen
  class Generator
    def self.run(project_name)
      new(project_name).run
    end

    TEMPLATE_ROOT = File.expand_path('gen/template', Gen::ROOT)

    VALID_PROJECT_NAME = /\A[a-z][a-z0-9]*\z/
    private_constant :VALID_PROJECT_NAME

    # false  -> delete file
    # string -> rename file before applying template substitutions
    VENDOR_TRANSLATIONS = {
      'Gemfile'            => false,
      'exe/__app__-gems'   => false,
      'exe/__app__-vendor' => 'exe/__app__',
    }.freeze
    private_constant :VENDOR_TRANSLATIONS

    BUNDLER_TRANSLATIONS = {
      'bin'                => false,
      'bin/update-deps'    => false,
      'exe/__app__-gems'   => 'exe/__app__',
      'exe/__app__-vendor' => false,
    }.freeze
    private_constant :BUNDLER_TRANSLATIONS

    def initialize(project_name)
      raise(
        CLI::Kit::Abort,
        "project name must match {{bold:#{VALID_PROJECT_NAME}}} (but can be changed later)"
      ) unless project_name =~ VALID_PROJECT_NAME
      @project_name = project_name
      @title_case = @project_name[0].upcase + @project_name[1..-1]
    end

    def run
      vendor = ask_vendor?
      create_project_dir
      if vendor
        copy_files(translations: VENDOR_TRANSLATIONS)
      else
        copy_files(translations: BUNDLER_TRANSLATIONS)
      end
    end

    private

    def ask_vendor?
      vendor = nil
      CLI::UI::Frame.open('Configuration') do
        vendor = CLI::UI.ask('How would you like the application to consume {{command:cli-kit}} and {{command:cli-ui}}?') do |c|
          c.option('Vendor (faster execution, more difficult to update deps)') { 'vendor' }
          c.option('Bundler (slower execution, easer dep management)') { 'bundler' }
        end
      end
      vendor == 'vendor'
    end

    def create_project_dir
      info(create: '')
      FileUtils.mkdir(@project_name)
    rescue Errno::EEXIST
      error("directory already exists: #{@project_name}")
    end

    def copy_files(translations:)
      each_template_file do |source_name|
        target_name = translations.fetch(source_name, source_name)
        next if target_name == false
        target_name = apply_template_variables(target_name)

        source = File.join(TEMPLATE_ROOT, source_name)
        target = File.join(@project_name, target_name)

        info(create: target_name)

        if Dir.exist?(source)
          FileUtils.mkdir(target)
        else
          content = apply_template_variables(File.read(source))
          File.write(target, content)
          File.chmod(File.stat(source).mode, target)
        end
      end
    end

    def each_template_file
      return enum_for(:each_template_file) unless block_given?

      root = Pathname.new(TEMPLATE_ROOT)
      Dir.glob("#{TEMPLATE_ROOT}/**/*").each do |f|
        el = Pathname.new(f)
        yield(el.relative_path_from(root).to_s)
      end
    end

    def apply_template_variables(s)
      s.gsub(/__app__/, @project_name).gsub(/__App__/, @title_case)
    end

    def info(create:)
      puts(CLI::UI.fmt("\t{{bold:{{blue:create}}\t#{create}}}"))
    end

    def error(msg)
      raise(CLI::Kit::Abort, msg)
    end
  end
end
