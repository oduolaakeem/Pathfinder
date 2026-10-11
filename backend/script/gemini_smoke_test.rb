# frozen_string_literal: true

require "net/http"
require "json"

# Standalone, synthetic connectivity check. Run only with explicit approval.
module GeminiSmokeTest
  CATEGORIES = [ "Programming language", "SQL", "Git", "HTTP/API concepts", "Automated testing" ].freeze
  CLASSIFICATIONS = [ "identified", "not_identified", "uncertain" ].freeze
  MAX_RESPONSE_BYTES = 64 * 1024

  class Failure < StandardError; end

  # Reject duplicate JSON keys rather than silently overwriting them.
  class UniqueObject < Hash
    def []=(key, value)
      raise Failure, "invalid_response" if key?(key)
      super
    end
  end

  def self.run
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    status = nil
    model = ENV.fetch("GEMINI_MODEL", "gemini-3.5-flash-lite")
    # Never echo arbitrary environment content as a model identifier.
    unless model.match?(/\Agemini-[a-z0-9.-]{1,80}\z/)
      model = "invalid"
      raise Failure, "configuration"
    end
    raise Failure, "opt_in_required" unless ARGV == [ "--live" ]
    key = ENV["GEMINI_API_KEY"]
    raise Failure, "missing_api_key" if key.nil? || key.strip.empty?

    schema = {
      type: "OBJECT",
      properties: CATEGORIES.to_h { |category| [ category, { type: "STRING", enum: CLASSIFICATIONS } ] },
      required: CATEGORIES,
      propertyOrdering: CATEGORIES
    }
    payload = {
      contents: [ { role: "user", parts: [ { text: <<~PROMPT } ] } ],
        Classify evidence of current skills for each category in the response schema.
        Use identified for explicit evidence, not_identified for no evidence, and uncertain for ambiguous evidence.
        This is a description-based assessment, not proof of proficiency. Return only the requested JSON.
        Career goal: Become a backend developer.
        Current skills: Ruby, SQL, Git; built a small Rails application.
      PROMPT
      generationConfig: {
        responseMimeType: "application/json",
        responseSchema: schema,
        maxOutputTokens: 1024,
        candidateCount: 1
      }
    }
    uri = URI("https://generativelanguage.googleapis.com/v1beta/models/#{model}:generateContent")
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["x-goog-api-key"] = key
    request.body = JSON.generate(payload)

    # Disable implicit environment proxies and debug output; never follow redirects.
    http = Net::HTTP.new(uri.host, uri.port, nil)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    http.open_timeout = 3
    http.read_timeout = 30
    http.write_timeout = 5
    http.max_retries = 0
    body = +""
    http.start do |connection|
      connection.request(request) do |response|
        status = response.code
        raise Failure, "http_error" unless response.is_a?(Net::HTTPSuccess)
        response.read_body do |chunk|
          raise Failure, "response_too_large" if body.bytesize + chunk.bytesize > MAX_RESPONSE_BYTES
          body << chunk
        end
      end
    end

    envelope = JSON.parse(body, object_class: UniqueObject)
    raise Failure, "invalid_response" unless envelope.is_a?(Hash)
    feedback = envelope["promptFeedback"]
    raise Failure, "provider_refusal" if feedback.is_a?(Hash) && feedback.key?("blockReason")
    candidates = envelope["candidates"]
    raise Failure, "invalid_response" unless candidates.is_a?(Array) && candidates.length == 1
    candidate = candidates.first
    raise Failure, "invalid_response" unless candidate.is_a?(Hash)
    raise Failure, "incomplete_response" unless candidate["finishReason"] == "STOP"
    ratings = candidate["safetyRatings"]
    if ratings.is_a?(Array) && ratings.any? { |rating| rating.is_a?(Hash) && rating["blocked"] == true }
      raise Failure, "provider_refusal"
    end
    content = candidate["content"]
    parts = content["parts"] if content.is_a?(Hash)
    raise Failure, "invalid_response" unless parts.is_a?(Array) && !parts.empty?
    unless parts.all? { |part| part.is_a?(Hash) && part["text"].is_a?(String) && !part["thought"] }
      raise Failure, "invalid_response"
    end
    text = parts.map { |part| part["text"] }.join
    raise Failure, "empty_response" if text.strip.empty?
    result = JSON.parse(text, object_class: UniqueObject)
    unless result.is_a?(Hash) && result.keys.sort == CATEGORIES.sort &&
        result.values.all? { |value| CLASSIFICATIONS.include?(value) }
      raise Failure, "invalid_classification"
    end
    report("PASS", status, model, started)
    0
  rescue Failure => error
    report("FAIL", status, model, started, error.message)
    1
  rescue JSON::ParserError
    report("FAIL", status, model, started, "invalid_json")
    1
  rescue Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout
    report("FAIL", status, model, started, "timeout")
    1
  rescue StandardError
    # Do not expose exceptions: they can contain headers or provider content.
    report("FAIL", status, model, started, "transport_or_configuration")
    1
  end

  def self.report(outcome, status, model, started, category = nil)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    puts [ outcome, ("HTTP=#{status}" if status), "model=#{model}", format("elapsed=%.2fs", elapsed), category ].compact.join(" ")
  end
end

exit GeminiSmokeTest.run if $PROGRAM_NAME == __FILE__
