class PitchDeckAiService
  class GenerationError < StandardError; end

  SLIDE_GENERATORS = {
    "cover" => :generate_cover,
    "problem" => :generate_problem,
    "solution" => :generate_solution,
    "why_now" => :generate_why_now,
    "market" => :generate_market,
    "product" => :generate_product,
    "business_model" => :generate_business_model,
    "traction" => :generate_traction,
    "competition" => :generate_competition,
    "team" => :generate_team,
    "financials" => :generate_financials,
    "ask" => :generate_ask
  }.freeze

  def initialize(pitch_deck)
    @deck = pitch_deck
    @inputs = pitch_deck.inputs.with_indifferent_access
    @client = OpenAI::Client.new(access_token: openai_key)
  end

  def generate_all_slides!
    PitchDeck::SLIDE_TYPES.each_with_index do |slide_type, position|
      content = send(SLIDE_GENERATORS[slide_type])
      @deck.slides.find_or_initialize_by(slide_type: slide_type).update!(
        position: position,
        title: content[:title],
        content: content[:body],
        speaker_notes: content[:speaker_notes]
      )
    end
  end

  def regenerate_slide!(slide_type)
    content = send(SLIDE_GENERATORS[slide_type])
    slide = @deck.slides.find_by!(slide_type: slide_type)
    slide.update!(
      title: content[:title],
      content: content[:body],
      speaker_notes: content[:speaker_notes]
    )
    slide
  end

  private

  def openai_key
    ENV["OPENAI_API_KEY"] || Rails.application.credentials.dig(:openai, :api_key)
  end

  def business_context
    <<~CTX
      Company: #{@deck.company_name}
      Tagline: #{@deck.tagline}
      Industry: #{@deck.industry}
      Stage: #{@deck.stage}
      Funding Ask: #{@deck.funding_ask}

      Problem: #{@inputs[:problem_description]}
      Solution: #{@inputs[:solution_description]}
      Why Now: #{@inputs[:why_now]}
      Target Market: #{@inputs[:target_market]}
      Market Size Estimate: #{@inputs[:market_size_estimate]}
      Revenue Model: #{@inputs[:revenue_model]}
      Pricing: #{@inputs[:pricing]}
      Current Traction: #{@inputs[:traction]}
      Key Metrics: #{@inputs[:key_metrics]}
      Milestones: #{@inputs[:milestones]}
      Team: #{@inputs[:team_members]}
      Competitors: #{@inputs[:competitors]}
      Differentiators: #{@inputs[:differentiators]}
      Current Revenue: #{@inputs[:current_revenue]}
      Projected Revenue: #{@inputs[:projected_revenue]}
      Use of Funds: #{@inputs[:use_of_funds]}
    CTX
  end

  def ai_generate(system_prompt, user_prompt)
    response = @client.chat(
      parameters: {
        model: "gpt-4o",
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: user_prompt }
        ],
        response_format: { type: "json_object" },
        temperature: 0.7,
        max_tokens: 2000
      }
    )

    raw = response.dig("choices", 0, "message", "content")
    raise GenerationError, "Empty AI response" if raw.blank?

    JSON.parse(raw).with_indifferent_access
  rescue JSON::ParserError => e
    raise GenerationError, "Failed to parse AI response: #{e.message}"
  rescue Faraday::Error => e
    raise GenerationError, "AI API error: #{e.message}"
  end

  # ─── Slide Generators ───────────────────────────────────────

  def generate_cover
    result = ai_generate(
      "You are an expert pitch deck designer. Generate a compelling cover slide. Return JSON with: title, subtitle, tagline, one_liner (a powerful one-sentence company description).",
      "Create a cover slide for this company:\n\n#{business_context}"
    )
    { title: @deck.company_name, body: result, speaker_notes: "Welcome investors. #{result[:one_liner]}" }
  end

  def generate_problem
    result = ai_generate(
      <<~PROMPT,
        You are a world-class pitch deck consultant who has helped raise over $1B in funding.
        Generate a Problem slide. Return JSON with:
        - headline: A punchy 5-8 word problem statement
        - description: 2-3 sentences describing the pain point vividly
        - pain_points: Array of 3 specific pain points (each with "title" and "detail")
        - data_point: A compelling statistic that proves this problem is real (with "stat" and "source")
        - who_suffers: Who specifically has this problem
        Make it emotional and data-driven. Investors should FEEL the problem.
      PROMPT
      "Create the Problem slide:\n\n#{business_context}"
    )
    { title: result[:headline] || "The Problem", body: result, speaker_notes: result[:description] }
  end

  def generate_solution
    result = ai_generate(
      <<~PROMPT,
        You are a world-class pitch deck consultant. Generate a Solution slide. Return JSON with:
        - headline: A clear 5-8 word solution statement
        - description: 2-3 sentences on how the product solves the problem
        - key_benefits: Array of 3 benefits (each with "title", "description", and "icon" — icon should be one of: shield, zap, target, chart, users, clock)
        - before_after: Object with "before" (how it is now) and "after" (how it will be)
        - value_proposition: One powerful sentence
        The solution should directly address each pain point from the Problem slide.
      PROMPT
      "Create the Solution slide:\n\n#{business_context}"
    )
    { title: result[:headline] || "Our Solution", body: result, speaker_notes: result[:value_proposition] }
  end

  def generate_why_now
    result = ai_generate(
      <<~PROMPT,
        You are a world-class pitch deck consultant. Generate a "Why Now" slide. Return JSON with:
        - headline: 5-8 words on market timing
        - description: 2-3 sentences on why this is the right moment
        - trends: Array of 3 market trends (each with "trend", "detail", and "impact")
        - catalyst: The single biggest reason this couldn't have worked 5 years ago
        Create urgency. Make inaction feel risky.
      PROMPT
      "Create the Why Now slide:\n\n#{business_context}"
    )
    { title: result[:headline] || "Why Now", body: result, speaker_notes: result[:description] }
  end

  def generate_market
    result = ai_generate(
      <<~PROMPT,
        You are a world-class pitch deck consultant with deep market research expertise.
        Generate a Market Size slide. Return JSON with:
        - headline: 5-8 words
        - tam: Object with "value" (e.g. "$50B"), "description" (Total Addressable Market explanation)
        - sam: Object with "value", "description" (Serviceable Addressable Market)
        - som: Object with "value", "description" (Serviceable Obtainable Market — realistic 3-year target)
        - growth_rate: Annual market growth rate with source
        - description: 1-2 sentences summarizing the opportunity
        Use both top-down AND bottom-up reasoning. Be realistic — inflated numbers lose credibility.
      PROMPT
      "Create the Market Size slide:\n\n#{business_context}"
    )
    { title: result[:headline] || "Market Opportunity", body: result, speaker_notes: "#{result[:tam]&.dig(:value)} total market, targeting #{result[:som]&.dig(:value)} in 3 years." }
  end

  def generate_product
    result = ai_generate(
      <<~PROMPT,
        You are a world-class pitch deck consultant. Generate a Product slide. Return JSON with:
        - headline: 5-8 words
        - description: 2-3 sentences on what the product does
        - features: Array of 4 key features (each with "title", "description")
        - how_it_works: Array of 3 steps describing the user journey (each with "step", "title", "description")
        - unique_advantage: One sentence on what's technically unique
        Show, don't tell. Focus on the user experience.
      PROMPT
      "Create the Product slide:\n\n#{business_context}"
    )
    { title: result[:headline] || "The Product", body: result, speaker_notes: result[:unique_advantage] }
  end

  def generate_business_model
    result = ai_generate(
      <<~PROMPT,
        You are a world-class pitch deck consultant with deep finance expertise.
        Generate a Business Model slide. Return JSON with:
        - headline: 5-8 words
        - description: 2-3 sentences on how the company makes money
        - revenue_streams: Array of revenue streams (each with "stream", "description", "percentage" of total revenue)
        - unit_economics: Object with "cac" (customer acquisition cost), "ltv" (lifetime value), "ltv_cac_ratio", "payback_months"
        - pricing_model: Brief description of pricing strategy
        Investors care about unit economics. Make LTV/CAC ratio compelling.
      PROMPT
      "Create the Business Model slide:\n\n#{business_context}"
    )
    { title: result[:headline] || "Business Model", body: result, speaker_notes: "Unit economics: #{result[:unit_economics]&.dig(:ltv_cac_ratio)} LTV/CAC ratio." }
  end

  def generate_traction
    result = ai_generate(
      <<~PROMPT,
        You are a world-class pitch deck consultant. Generate a Traction slide. Return JSON with:
        - headline: 5-8 words highlighting the strongest metric
        - description: 2-3 sentences on current momentum
        - metrics: Array of 4 key metrics (each with "label", "value", "growth" — e.g. "+25% MoM")
        - milestones: Array of 3-4 key milestones achieved (each with "date", "milestone")
        - social_proof: Any notable customers, partnerships, press mentions
        If pre-revenue, focus on user growth, waitlist, LOIs, partnerships. Never fake numbers.
      PROMPT
      "Create the Traction slide:\n\n#{business_context}"
    )
    { title: result[:headline] || "Traction", body: result, speaker_notes: result[:description] }
  end

  def generate_competition
    result = ai_generate(
      <<~PROMPT,
        You are a world-class pitch deck consultant. Generate a Competition slide. Return JSON with:
        - headline: 5-8 words
        - description: 1-2 sentences on competitive landscape
        - competitors: Array of 3-4 competitors (each with "name", "description", "strengths", "weaknesses")
        - differentiators: Array of 3 key differentiators that set this company apart
        - positioning: Object with "x_axis" (label), "y_axis" (label) for a 2x2 matrix, and "position" (which quadrant: "top_right" ideally)
        Never say "we have no competition." Show you understand the landscape and why you win.
      PROMPT
      "Create the Competition slide:\n\n#{business_context}"
    )
    { title: result[:headline] || "Competitive Landscape", body: result, speaker_notes: "Our key differentiator: #{result[:differentiators]&.first}" }
  end

  def generate_team
    result = ai_generate(
      <<~PROMPT,
        You are a world-class pitch deck consultant. Generate a Team slide. Return JSON with:
        - headline: 5-8 words
        - description: 1-2 sentences on why this team wins
        - members: Array of team members (each with "name", "role", "bio" — 1-2 sentences of relevant experience, "linkedin" — leave blank)
        - advisors: Array of advisors if mentioned (each with "name", "expertise")
        - team_strength: One sentence on the team's unfair advantage
        Highlight domain expertise and relevant experience. Why is THIS team uniquely positioned?
      PROMPT
      "Create the Team slide:\n\n#{business_context}"
    )
    { title: result[:headline] || "The Team", body: result, speaker_notes: result[:team_strength] }
  end

  def generate_financials
    result = ai_generate(
      <<~PROMPT,
        You are a world-class pitch deck consultant with CFO-level finance expertise.
        Generate a Financials slide. Return JSON with:
        - headline: 5-8 words
        - description: 1-2 sentences on financial trajectory
        - projections: Array of 3 years, each with "year" (e.g. "Year 1"), "revenue", "expenses", "net_income", "customers"
        - key_assumptions: Array of 3 key assumptions driving the projections
        - gross_margin: Expected gross margin percentage
        - break_even: When the company expects to break even
        Be realistic. Overly optimistic projections destroy credibility. Show a clear path to profitability.
      PROMPT
      "Create the Financials slide:\n\n#{business_context}"
    )
    { title: result[:headline] || "Financial Projections", body: result, speaker_notes: "Break-even: #{result[:break_even]}. Gross margin: #{result[:gross_margin]}." }
  end

  def generate_ask
    result = ai_generate(
      <<~PROMPT,
        You are a world-class pitch deck consultant. Generate the Ask/Use of Funds slide. Return JSON with:
        - headline: 5-8 words (e.g. "Raising $X to [milestone]")
        - amount: The funding amount
        - description: 1-2 sentences on what this funding enables
        - use_of_funds: Array of fund allocations (each with "category", "percentage", "description")
        - milestones: Array of 3 milestones this funding will achieve (each with "timeframe", "milestone")
        - runway: How many months of runway this provides
        Map every dollar to a milestone. Show investors exactly what their money buys.
      PROMPT
      "Create the Ask slide:\n\n#{business_context}"
    )
    { title: result[:headline] || "The Ask", body: result, speaker_notes: "We're raising #{result[:amount]} with #{result[:runway]} months runway." }
  end
end
