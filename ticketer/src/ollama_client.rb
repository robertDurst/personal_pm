PROMPT_PATH = File.join(File.dirname(__FILE__), 'prompts', 'jira_ticket_prompt.txt')

class OllamaClient
  BASE_URL = 'http://localhost:11434/api'.freeze

  def self.check_ollama_running
    uri = URI("#{BASE_URL}/tags")
    begin
      response = Net::HTTP.get_response(uri)
      response.code == '200'
    rescue Errno::ECONNREFUSED, Errno::ECONNRESET, Net::OpenTimeout
      false
    end
  end

  def self.list_models
    uri = URI("#{BASE_URL}/tags")
    begin
      response = Net::HTTP.get_response(uri)
      if response.code == '200'
        models = JSON.parse(response.body)['models']
        models.map { |model| model['name'] }
      else
        puts "Error fetching models: #{response.code} #{response.message}"
        []
      end
    rescue StandardError => e
      puts "Error fetching models: #{e.message}"
      []
    end
  end

  def self.generate_ticket(model, description, additional_context = '')
    prompt = File.read(PROMPT_PATH).gsub('{{description}}', description).gsub('{{additional_context}}',
                                                                              additional_context)

    uri = URI("#{BASE_URL}/generate")
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri)
    request.content_type = 'application/json'
    request.body = {
      model: model,
      prompt: prompt,
      stream: false
    }.to_json

    begin
      response = http.request(request)
      if response.code == '200'
        result = JSON.parse(response.body)['response']

        # Try to parse the JSON from the response
        begin
          # Find JSON content (might be surrounded by markdown code blocks)
          json_text = if result.include?('```json')
                        result.split('```json')[1].split('```')[0].strip
                      elsif result.include?('```')
                        result.split('```')[1].split('```')[0].strip
                      else
                        result
                      end

          JSON.parse(json_text)
        rescue JSON::ParserError
          puts 'Warning: Could not parse JSON from model response. Returning raw text.'
          { 'raw_response' => result }
        end
      else
        puts "Error: #{response.code} - #{response.body}"
        nil
      end
    rescue StandardError => e
      puts "Error generating ticket: #{e.message}"
      nil
    end
  end
end
