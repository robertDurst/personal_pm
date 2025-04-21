require 'rspec'
require_relative './spec_helper'
require 'net/http'
require 'json'
require_relative '../src/ollama_client'

describe OllamaClient do
  describe '.check_ollama_running' do
    it 'returns true if the server is running' do
      stub_request(:get, 'http://localhost:11434/api/tags').to_return(status: 200)
      expect(OllamaClient.check_ollama_running).to be true
    end

    it 'returns false if the server is not running' do
      stub_request(:get, 'http://localhost:11434/api/tags').to_raise(Errno::ECONNREFUSED)
      expect(OllamaClient.check_ollama_running).to be false
    end
  end

  describe '.list_models' do
    it 'returns a list of model names if the server responds successfully' do
      response_body = { models: [{ name: 'model1' }, { name: 'model2' }] }.to_json
      stub_request(:get, 'http://localhost:11434/api/tags').to_return(status: 200, body: response_body)
      expect(OllamaClient.list_models).to eq(%w[model1 model2])
    end

    it 'returns an empty array if the server responds with an error' do
      stub_request(:get, 'http://localhost:11434/api/tags').to_return(status: 500)
      expect(OllamaClient.list_models).to eq([])
    end

    it 'returns an empty array if an exception occurs' do
      stub_request(:get, 'http://localhost:11434/api/tags').to_raise(StandardError)
      expect(OllamaClient.list_models).to eq([])
    end
  end

  describe '.generate_ticket' do
    let(:model) { 'test_model' }
    let(:description) { 'Test description' }
    let(:additional_context) { 'Additional context' }
    let(:prompt_path) { File.join(File.dirname(__FILE__), '../src/prompts/jira_ticket_prompt.txt') }
    let(:actual_prompt_path) { File.expand_path('../src/prompts/jira_ticket_prompt.txt', File.dirname(__FILE__)) }

    before do
      allow(File).to receive(:read).with(actual_prompt_path).and_return("Description: {{description}}\nContext: {{additional_context}}")
    end

    it 'returns parsed ticket data if the response contains valid JSON' do
      response_body = { response: '{"key":"value"}' }.to_json
      stub_request(:post, 'http://localhost:11434/api/generate').to_return(status: 200, body: response_body)
      expect(OllamaClient.generate_ticket(model, description, additional_context)).to eq({ 'key' => 'value' })
    end

    it 'returns raw response if JSON parsing fails' do
      response_body = { response: 'Invalid JSON' }.to_json
      stub_request(:post, 'http://localhost:11434/api/generate').to_return(status: 200, body: response_body)
      expect(OllamaClient.generate_ticket(model, description,
                                          additional_context)).to eq({ 'raw_response' => 'Invalid JSON' })
    end

    it 'returns nil if the server responds with an error' do
      stub_request(:post, 'http://localhost:11434/api/generate').to_return(status: 500)
      expect(OllamaClient.generate_ticket(model, description, additional_context)).to be_nil
    end

    it 'returns nil if an exception occurs' do
      stub_request(:post, 'http://localhost:11434/api/generate').to_raise(StandardError)
      expect(OllamaClient.generate_ticket(model, description, additional_context)).to be_nil
    end
  end
end
