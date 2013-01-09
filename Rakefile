specdir = File.join([File.dirname(__FILE__), "spec"])

require 'rake'
begin
  require 'rspec/core/rake_task'
rescue LoadError
end

def safe_system *args
  raise RuntimeError, "Failed: #{args.join(' ')}" unless system *args
end

def check_build_env
  raise "Not all environment variables have been set. Missing #{{"'DESTDIR'" => ENV["DESTDIR"], "'MCLIBDIR'" => ENV["MCLIBDIR"], "'MCBINDIR'" => ENV["MCBINDIR"], "'TARGETDIR'" => ENV["TARGETDIR"]}.reject{|k,v| v != nil}.keys.join(", ")}" unless ENV["DESTDIR"] && ENV["MCLIBDIR"] && ENV["MCBINDIR"] && ENV["TARGETDIR"]
  raise "DESTDIR - '#{ENV["DESTDIR"]}' is not a directory" unless File.directory?(ENV["DESTDIR"])
  raise "MCLIBDIR - '#{ENV["MCLIBDIR"]}' is not a directory" unless File.directory?(ENV["MCLIBDIR"])
  raise "MCBINDIR - '#{ENV["MCBINDIR"]}' is not a directory" unless File.directory?(ENV["MCBINDIR"])
  raise "TARGETDIR - '#{ENV["TARGETDIR"]}' is not a directory" unless File.directory?(ENV["TARGETDIR"])
end

def build_package(path)
  require 'yaml'
  options = []

  if File.directory?(path)
    buildops = File.join(path, "buildops.yaml")
    buildops = YAML.load_file(buildops) if File.exists?(buildops)

    return unless buildops["build"]

    libdir   = ENV["LIBDIR"] || buildops["mclibdir"]
    mcname   = ENV["MCNAME"] || buildops["mcname"]
    sign     = ENV["SIGN"]   || buildops["sign"]

    options << "--pluginpath=#{libdir}" if libdir
    options << "--mcname=#{mcname}" if mcname
    options << "--sign" if sign

    options << "--dependency=\"#{buildops["dependencies"].join(" ")}\"" if buildops["dependencies"]

    safe_system("ruby -I #{File.join(ENV["MCLIBDIR"], "lib").shellescape} #{File.join(ENV["MCBINDIR"], "mco").shellescape} plugin package -v #{path.shellescape} #{options.join(" ")}")
    move_artifacts
  end
end

def move_artifacts
  rpms = FileList["*.rpm"]
  debs = FileList["*.deb","*.orig.tar.gz","*.debian.tar.gz","*.diff.gz","*.dsc","*.changes"]
  [debs,rpms].each do |pkgs|
    unless pkgs.empty?
      safe_system("mv #{pkgs} #{ENV["DESTDIR"]}") unless File.expand_path(ENV["DESTDIR"]) == Dir.pwd
    end
  end
end

desc "Build packages for specified plugin in target directory"
task :buildplugin do
  check_build_env
  build_package(ENV["TARGETDIR"])
end

desc "Build packages for all plugins in target directory"
task :build do
  check_build_env
  packages = Dir.glob(File.join(ENV["TARGETDIR"], "*"))

  packages.each do |package|
    if File.directory?(File.expand_path(package))
      build_package(File.expand_path(package))
    end
  end
end

if defined?(RSpec::Core::RakeTask)
  desc "Run agent and application tests"
  RSpec::Core::RakeTask.new(:test) do |t|
    require "#{specdir}/spec_helper.rb"
    if ENV["TARGETDIR"]
      t.pattern = "#{File.expand_path(ENV["TARGETDIR"])}/spec/**/*_spec.rb"
    else
      t.pattern = 'spec/**/*_spec.rb'
    end

    tmp_load_path = $LOAD_PATH.map { |f| f.shellescape }.join(" -I ")
    t.rspec_opts = tmp_load_path + " " + File.read("#{specdir}/spec.opts").chomp
  end
end

task :default => :test
