# frozen_string_literal: true

class LearningPathBuilder
  CLASSIFICATIONS = %w[identified not_identified uncertain].freeze

  # Catalogue order is the fixed starter sequence, independent of input order.
  ACTIVITIES = {
    "Programming language" => {
      title: "Build a small program that validates user input",
      instruction: "Using a programming language of your choice, validate user input as nonblank and within a defined length limit. Demonstrate valid, blank, and over-limit inputs.",
      completion_evidence: "Source code and examples showing the results for valid, blank, and over-limit inputs."
    }.freeze,
    "Git" => {
      title: "Track changes in a practice repository",
      instruction: "Create a branch in a practice repository, commit a small program, make and commit a change, then inspect the diff and working-tree status.",
      completion_evidence: "The branch name, commits, a diff explaining the change, and a clean working-tree status."
    }.freeze,
    "SQL" => {
      title: "Query related records",
      instruction: "In a disposable practice database, create two related tables with synthetic records. Write a join query and a query finding records without a related entry.",
      completion_evidence: "SQL queries and their expected results using the synthetic records."
    }.freeze,
    "HTTP/API concepts" => {
      title: "Explore valid and invalid API requests",
      instruction: "Send a valid JSON request and an invalid request to a local practice API. Explain the method, URL, headers, body, response status, and response content.",
      completion_evidence: "Documented requests, responses, statuses, and explanations of why the outcomes differ."
    }.freeze,
    "Automated testing" => {
      title: "Test input-validation behavior",
      instruction: "Using an appropriate testing framework for your chosen language, test valid, blank, maximum-length, and over-limit inputs in a practice program.",
      completion_evidence: "Automated test files and passing results covering all four input-validation cases."
    }.freeze
  }.freeze

  INTEGRATED_ACTIVITY = {
    category: "Integrated practice",
    title: "Build a small backend feature",
    instruction: "Build a local practice API endpoint that validates input, persists related records, and handles an invalid request. Track changes with Git and add automated tests using your chosen stack.",
    completion_evidence: "Source code, Git commits, example success and error responses, and passing automated test results."
  }.freeze

  def self.call(classifications:)
    unless classifications.is_a?(Hash) && classifications.keys.all? { |key| key.is_a?(String) } &&
        classifications.keys.sort == ACTIVITIES.keys.sort &&
        classifications.values.all? { |value| CLASSIFICATIONS.include?(value) }
      raise ArgumentError, "Expected exactly five approved categories with supported classifications"
    end

    steps = []
    ACTIVITIES.each do |category, activity|
      classification = classifications.fetch(category)
      next if classification == "identified"

      step = activity.merge(category: category, order: steps.length + 1)
      if classification == "uncertain"
        step[:title] = "Clarify your experience: #{activity[:title]}"
        step[:instruction] = "Describe your prior experience with this category, then demonstrate it through this practice exercise: #{activity[:instruction]}"
        step[:completion_evidence] = "A short explanation of prior experience, plus #{activity[:completion_evidence]}"
      end
      steps << step
    end
    steps << INTEGRATED_ACTIVITY.merge(order: 1) if steps.empty?

    { method: "curated", catalogue_version: "1", steps: steps, next_action: steps.first.dup }
  end
end
