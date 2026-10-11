require "rails_helper"
require "net/http"
require "json"
require "stringio"

RSpec.describe GeminiSkillGapProvider do
  let(:key) { "SYNTHETIC_GEMINI_KEY_8A" }
  let(:goal_description) { "Become a backend developer SYNTHETIC_GOAL_8A" }
  let(:skills_description) { "Ruby, SQL, Git SYNTHETIC_SKILLS_8A" }
  let(:categories) { [ "Programming language", "SQL", "Git", "HTTP/API concepts", "Automated testing" ] }
  let(:values) { [ "identified", "not_identified", "uncertain" ] }
  let(:classifications) { categories.zip([ "identified", "identified", "identified", "uncertain", "not_identified" ]).to_h }
  let(:http) { double("offline HTTP transport") }
  let(:status) { "200" }
  let(:body) { envelope(JSON.generate(classifications)) }
  let(:log_output) { StringIO.new }

  def envelope(text, finish_reason = "STOP")
    JSON.generate("candidates" => [{ "finishReason" => finish_reason, "content" => { "parts" => [{ "text" => text }] } }])
  end

  def classify(**extra)
    described_class.classify(goal_description: goal_description, current_skills_description: skills_description, **extra)
  end

  def expect_private_error(class_name)
    expect { classify }.to raise_error do |error|
      expect(error.class.name).to eq("GeminiSkillGapProvider::#{class_name}")
      [ key, goal_description, skills_description, "SYNTHETIC_RAW_8A" ].compact.reject(&:empty?).each do |sensitive|
        expect(error.message).not_to include(sensitive)
        expect(log_output.string).not_to include(sensitive)
      end
      expect(error.message).not_to include(body) unless body.empty?
    end
  end

  before do
    # Equivalent transport injection seam: replace Net::HTTP construction, not
    # the provider. No original HTTP constructor/start method can reach a socket.
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:[]).with("GEMINI_API_KEY").and_return(key)
    allow(ENV).to receive(:fetch).with("GEMINI_API_KEY", any_args).and_return(key)
    allow(ENV).to receive(:[]).with("GEMINI_MODEL").and_return("gemini-3.5-flash-lite")
    allow(ENV).to receive(:fetch).with("GEMINI_MODEL", any_args).and_return("gemini-3.5-flash-lite")
    allow(Net::HTTP).to receive(:new).and_return(http)
    allow(Net::HTTP).to receive(:start).and_raise("External HTTP forbidden")
    %i[use_ssl= verify_mode= open_timeout= read_timeout= write_timeout= max_retries=].each do |setter|
      allow(http).to receive(setter)
    end
    allow(http).to receive(:start).and_yield(http)
    allow(http).to receive(:request) do |request, &block|
      @request = request
      response_class = Net::HTTPResponse::CODE_TO_OBJ.fetch(status)
      response = response_class.new("1.1", status, "Synthetic status")
      allow(response).to receive(:read_body) do |&reader|
        body.bytes.each_slice(1024) { |bytes| reader.call(bytes.pack("C*")) }
      end
      block.call(response)
      response
    end
    allow(Rails).to receive(:logger).and_return(ActiveSupport::Logger.new(log_output))
  end

  it "returns exactly the validated category/classification map without sensitive logging" do
    expect(classify).to eq(classifications)
    expect(http).to have_received(:request).once
    [ key, goal_description, skills_description ].each { |text| expect(log_output.string).not_to include(text) }
  end

  it "constructs a fixed HTTPS POST with header authentication and supplied descriptions" do
    classify
    expect(Net::HTTP).to have_received(:new).with("generativelanguage.googleapis.com", 443, nil).once
    expect(@request).to be_a(Net::HTTP::Post)
    expect(@request.path).to eq("/v1beta/models/gemini-3.5-flash-lite:generateContent")
    expect(@request.path).not_to include(key)
    expect(@request["x-goog-api-key"]).to eq(key)
    expect(@request["Content-Type"]).to eq("application/json")
    payload = JSON.parse(@request.body)
    text = payload.fetch("contents").flat_map { |content| content.fetch("parts") }.map { |part| part.fetch("text") }.join
    expect(text).to include(goal_description, skills_description)
  end

  it "requests the fixed structured schema and bounded output" do
    classify
    config = JSON.parse(@request.body).fetch("generationConfig")
    expect(config.fetch("responseMimeType")).to eq("application/json")
    schema = config.fetch("responseSchema")
    expect(schema.fetch("type").downcase).to eq("object")
    expect(schema.fetch("required").sort).to eq(categories.sort)
    expect(schema.fetch("properties").keys.sort).to eq(categories.sort)
    schema.fetch("properties").each_value do |property|
      expect(property.fetch("type").downcase).to eq("string")
      expect(property.fetch("enum").sort).to eq(values.sort)
    end
    expect(config.fetch("maxOutputTokens")).to be_between(1, 1024)
    expect(config.fetch("candidateCount", 1)).to eq(1)
  end

  it "enables verified TLS, short timeouts, and zero automatic retries" do
    classify
    expect(http).to have_received(:use_ssl=).with(true)
    expect(http).to have_received(:verify_mode=).with(OpenSSL::SSL::VERIFY_PEER)
    expect(http).to have_received(:open_timeout=).with(3)
    expect(http).to have_received(:read_timeout=).with(30)
    expect(http).to have_received(:max_retries=).with(0)
  end

  [ nil, "", " \t\n" ].each do |missing|
    context "with API key #{missing.inspect}" do
      let(:key) { missing }
      it "fails safely before creating transport" do
        expect_private_error("Unavailable")
        expect(Net::HTTP).not_to have_received(:new)
      end
    end
  end

  # Configuration/authentication/quota/HTTP failures are unavailable (503).
  %w[400 401 403 404 429 500 502 503].each do |code|
    context "with HTTP #{code}" do
      let(:status) { code }
      let(:body) { "SYNTHETIC_RAW_8A #{key} #{goal_description} #{skills_description}" }
      it "raises a private Unavailable error after one attempt" do
        expect_private_error("Unavailable")
        expect(http).to have_received(:request).once
      end
    end
  end

  [ Net::OpenTimeout, Net::ReadTimeout ].each do |error_class|
    it "converts #{error_class} to private unavailability without retrying" do
      allow(http).to receive(:request).and_raise(error_class, "SYNTHETIC_RAW_8A #{key} #{skills_description}")
      expect_private_error("Unavailable")
      expect(http).to have_received(:request).once
    end
  end

  # InvalidResponse is the typed boundary mapped to HTTP 502 by the controller.
  invalid_cases = %w[invalid_json duplicate_envelope duplicate_category missing_category unexpected_category
    invalid_classification null_classification empty_candidates blocked refusal truncated missing_finish
    empty_text missing_content non_object oversized]
  invalid_cases.each do |label|
    context "with #{label}" do
      let(:body) do
        case label
        when "invalid_json" then "SYNTHETIC_RAW_8A #{key} #{skills_description}"
        when "duplicate_envelope" then '{"candidates":[],"candidates":[]}'
        when "duplicate_category" then envelope(JSON.generate(classifications).sub(/\}\z/, ',"SQL":"uncertain"}'))
        when "missing_category" then envelope(JSON.generate(classifications.except("SQL")))
        when "unexpected_category" then envelope(JSON.generate(classifications.merge("Deployment" => "identified")))
        when "invalid_classification" then envelope(JSON.generate(classifications.merge("SQL" => "expert")))
        when "null_classification" then envelope(JSON.generate(classifications.merge("SQL" => nil)))
        when "empty_candidates" then JSON.generate("candidates" => [])
        when "blocked" then JSON.generate("promptFeedback" => { "blockReason" => "SAFETY" })
        when "refusal" then envelope("SYNTHETIC_RAW_8A", "SAFETY")
        when "truncated" then envelope(JSON.generate(classifications), "MAX_TOKENS")
        when "missing_finish" then JSON.generate("candidates" => [{ "content" => { "parts" => [{ "text" => JSON.generate(classifications) }] } }])
        when "empty_text" then envelope(" \n")
        when "missing_content" then JSON.generate("candidates" => [{ "finishReason" => "STOP" }])
        when "non_object" then envelope("[]")
        when "oversized" then envelope(JSON.generate(classifications)) + " " * (64 * 1024)
        end
      end
      it "raises a private InvalidResponse rather than returning an assessment" do
        expect_private_error("InvalidResponse")
      end
    end
  end

  it "does not accept client-selected endpoint or model keywords" do
    expect {
      classify(endpoint: "https://synthetic.invalid", model: "client-selected-model")
    }.to raise_error(ArgumentError)
    expect(Net::HTTP).not_to have_received(:new)
  end

  describe "response-part metadata" do
    # Modify the same successful envelope; metadata is not classification data.
    let(:metadata_marker) { "SYNTHETIC_METADATA_8H" }

    {
      "thoughtSignature" => "U1lOVEhFVElDX01FVEFEQVRBXzhI",
      "partMetadata" => { "synthetic_marker" => "SYNTHETIC_METADATA_8H" }
    }.each do |field, metadata|
      context "with documented #{field}" do
        let(:body) do
          parsed = JSON.parse(envelope(JSON.generate(classifications)))
          parsed.fetch("candidates").first.fetch("content").fetch("parts").first[field] = metadata
          JSON.generate(parsed)
        end

        it "returns only validated classifications and does not expose metadata" do
          expect(classify).to eq(classifications)
          expect(log_output.string).not_to include(metadata_marker, "U1lOVEhFVElDX01FVEFEQVRBXzhI")
          expect(http).to have_received(:request).once
        end
      end
    end

    [ "functionCall", "executableCode", "functionCall with text", "executableCode with text", "thought-only", "unknown field" ].each do |label|
      context "with #{label}" do
        let(:body) do
          parsed = JSON.parse(envelope(JSON.generate(classifications)))
          parts = parsed.fetch("candidates").first.fetch("content").fetch("parts")
          part = case label
          when "functionCall" then { "functionCall" => { "name" => "synthetic_tool", "args" => {} } }
          when "executableCode" then { "executableCode" => { "language" => "PYTHON", "code" => "pass" } }
          when "functionCall with text"
            { "text" => JSON.generate(classifications), "functionCall" => { "name" => "synthetic_tool", "args" => {} } }
          when "executableCode with text"
            { "text" => JSON.generate(classifications), "executableCode" => { "language" => "PYTHON", "code" => "pass" } }
          when "thought-only" then { "text" => JSON.generate(classifications), "thought" => true }
          when "unknown field" then { "text" => JSON.generate(classifications), "unapprovedField" => metadata_marker }
          end
          parts.replace([ part ])
          JSON.generate(parsed)
        end

        it "rejects non-assessment content with a private InvalidResponse" do
          expect_private_error("InvalidResponse")
          expect(log_output.string).not_to include(metadata_marker)
        end
      end
    end
  end
end
