#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'
require 'optparse'
require_relative 'ollama_client'

BASE_URL = 'http://localhost:11434/api'.freeze

def print_pretty_ticket(ticket)
  puts "\n=== Generated Jira Ticket ===\n"
  puts "Summary: #{ticket['summary'] || 'N/A'}"
  puts "\nDescription:\n#{ticket['description'] || 'N/A'}"
  puts "\nAcceptance Criteria:"

  criteria = ticket['acceptance_criteria']
  if criteria.is_a?(Array)
    criteria.each_with_index do |criterion, index|
      puts "  #{index + 1}. #{criterion}"
    end
  else
    puts "  #{criteria}"
  end

  puts "\nStory Points: #{ticket['story_points'] || 'N/A'}"
  puts "Priority: #{ticket['priority'] || 'N/A'}"
  puts "\n============================="
end

# Parse command line options
options = {
  model: 'llama3',
  output: 'pretty'
}

parser = OptionParser.new do |opts|
  opts.banner = 'Usage: jira-ticket-generator.rb [options]'

  opts.on('--list-models', 'List available models') do
    options[:list_models] = true
  end

  opts.on('--model MODEL', 'Model to use for ticket generation') do |model|
    options[:model] = model
  end

  opts.on('--description DESCRIPTION', 'Brief description of the ticket to generate') do |description|
    options[:description] = description
  end

  opts.on('--context CONTEXT', 'Additional context for ticket generation') do |context|
    options[:context] = context
  end

  opts.on('--output FORMAT', %w[pretty json], 'Output format (pretty or json)') do |format|
    options[:output] = format
  end

  opts.on('-h', '--help', 'Show this help message') do
    puts opts
    exit
  end
end

begin
  parser.parse!
rescue OptionParser::InvalidOption => e
  puts e.message
  puts parser
  exit 1
end

# Check if Ollama is running
unless check_ollama_running
  puts 'Error: Ollama is not running. Please start Ollama first.'
  exit 1
end

# List models if requested
if options[:list_models]
  models = list_models
  puts 'Available models:'
  models.each do |model|
    puts "- #{model}"
  end
  exit 0
end

# Check if description is provided
if options[:description].nil?
  puts 'Error: --description is required for ticket generation'
  puts parser
  exit 1
end

# Generate ticket
ticket = generate_ticket(options[:model], options[:description], options[:context] || '')

if ticket
  if options[:output] == 'json'
    puts JSON.pretty_generate(ticket)
  else
    print_pretty_ticket(ticket)
  end
end
