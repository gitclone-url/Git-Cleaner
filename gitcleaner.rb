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
        # Initialize a new GitRepository instance
        # @param url [String] The Git repository URL
        # @param username [String] The Git username
        # @param password [String] The Git password
        def initialize(url, username, password)
            @url = url.sub(%r{^https://(\S+@)?}, '')
            @auth_url = "https://#{username}:#{password}@#{@url}"
            @repo_type = detect_repo_type
            puts "Detected repository type: #{@repo_type}"
        end
        
        def clean
            Dir.mktmpdir('git') do |temp_dir|
                Dir.chdir(temp_dir) do
                    system("git clone #{@auth_url}") or raise Error, "Failed to clone repository"
                    sleep 1
                    repo_dir = File.basename(@url, '.git')
                    Dir.chdir(repo_dir) do
                        system('git fetch --all > /dev/null 2>&1')
                        sleep 1

                        branches = get_branches
                        branches.each { |branch| clean_branch(branch) }
                    end
                end
            end
        end

        private

        # Detect the type of Git repository
        # @return [Symbol] The repository type (:github or :gist)
        def detect_repo_type
            if @url.include?('gist.github.com')
                :gist
            elsif @url.include?('github.com')
                :github
            else
                raise Error, "Unsupported repository type"
            end
        end

        # Get the list of branches to clean
        # @return [Array<String>] The list of branches
        def get_branches
            if @repo_type == :github
                branches = `git branch -r | grep -v '\\->' | sed 's/origin\\///'`.split
                puts "\nAvailable branches: #{branches.join(', ')}"
                print "Enter the branch you wish to clean (leave empty for all branches): "
                branch_input = gets.chomp
                branch_input.empty? ? branches : [branch_input]
            else
                default_branch = `git rev-parse --abbrev-ref HEAD`.chomp
                puts "\nWorking on the default branch: #{default_branch}"
                [default_branch]
            end
        end

        # Clean up branches 
        # @param branch [String] The branch to clean
        def clean_branch(branch)
            system("git checkout #{branch} > /dev/null 2>&1")
            orphan_branch = "#{branch}-orphan"
            system("git checkout --orphan #{orphan_branch}")
            sleep 1
            system("git add -A > /dev/null 2>&1")

            print "\nEnter commit message (leave empty to allow empty commit): "
            commit_msg = gets.chomp
            if commit_msg.empty?
                system('git commit --allow-empty-message -m ""')
            else
                system("git commit -m '#{commit_msg}' --signoff")
            end

            system("git branch -D #{branch}")
            system("git branch -m #{orphan_branch} #{branch}")
            sleep 1

            loop do
                print "\nDo you want to force push or push with lease? (force/lease): "
                push_preference = gets.chomp.downcase
                case push_preference
                when 'force'
                    system("git push --force origin #{branch}")
                    break
                when 'lease'
                    system("git push --force-with-lease origin #{branch}")
                    break
                else
                    puts "Invalid input. Please enter 'force' or 'lease'."
                end
            end

            system('git gc --aggressive --prune=all')
            sleep 1
        end
    end
end

GitCleaner::CLI.new.run
