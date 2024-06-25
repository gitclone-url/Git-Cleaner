#!/usr/bin/env ruby

require 'dotenv'
require 'fileutils'
require 'tmpdir'
require 'uri'
require 'optparse'

module GitCleaner
  class Error < StandardError; end

  class CLI
    def initialize
      @options = {}
      parse_options
      load_environment
    end

    def run
      GitRepository.new(@options[:url], @options[:username], @options[:password]).clean
    rescue Error => e
      puts "Error: #{e.message}"
      exit 1
    end

    private

    def parse_options
      OptionParser.new do |opts|
        opts.banner = "Usage: gitcleaner [options]"
        opts.on("-u", "--url URL", "Git repository URL") { |url| @options[:url] = url }
        opts.on("--username USERNAME", "Git username") { |username| @options[:username] = username }
        opts.on("--password PASSWORD", "Git password") { |password| @options[:password] = password }
      end.parse!
    end

    def load_environment
      Dotenv.load('.env')
      @options[:url] ||= ENV['GITURL']
      @options[:username] ||= ENV['USERNAME']
      @options[:password] ||= ENV['PASSWORD']

      raise Error, "Git URL is required" unless @options[:url]
      raise Error, "Username is required" unless @options[:username]
      raise Error, "Password is required" unless @options[:password]
    end
  end

  class GitRepository
    def initialize(url, username, password)
      @url = url.sub(%r{^https://[^@]*@}, '')
      @auth_url = "https://#{username}:#{password}@#{@url}"
      @repo_type = @url.include?('github.com') ? :github : (@url.include?('gist.github.com') ? :gist : :unknown)
    end

    def clean
      Dir.mktmpdir('git') do |temp_dir|
        Dir.chdir(temp_dir) do
          system("git clone #{@auth_url}") or raise Error, "Failed to clone repository"
          Dir.chdir(File.basename(@url, '.git'))
          system('git fetch --all')

          branches = get_branches
          branches.each do |branch|
            system("git checkout #{branch}")
            system('git add -A')

            print "Enter commit message (leave empty to allow empty commit): "
            commit_msg = gets.chomp
            if commit_msg.empty?
              system('git commit --allow-empty-message -m ""')
            else
              system("git commit -m '#{commit_msg}' --signoff")
            end

            system("git branch -D #{branch}")
            system("git branch -m #{branch}")

            print "Do you want to force push or push with lease? (force/lease): "
            push_preference = gets.chomp.downcase
            case push_preference
            when 'force'
              system("git push --force origin #{branch}")
            when 'lease'
              system("git push --force-with-lease origin #{branch}")
            else
              raise Error, "Invalid input. Exiting."
            end

            system('git gc --aggressive --prune=all')
          end
        end
      end
    end

    private

    def get_branches
      if @repo_type == :github
        branches = `git branch -r | grep -v '\->' | sed 's/origin\///'`.split
        puts "Available branches: #{branches.join(', ')}"
        print "Enter the branch you wish to clean (leave empty for all branches): "
        branch_input = gets.chomp
        branch_input.empty? ? branches : [branch_input]
      else
        default_branch = `git rev-parse --abbrev-ref HEAD`.chomp
        puts "Detected a gist. Working on the default branch: #{default_branch}"
        [default_branch]
      end
    end
  end
end

GitCleaner::CLI.new.run
