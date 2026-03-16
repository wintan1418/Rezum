class PitchDecksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_pitch_deck, only: [:show, :edit, :update, :regenerate_slide, :download, :destroy]
  before_action :check_pitch_deck_access!, only: [:create]

  def index
    @pitch_decks = PitchDeck.where(user: current_user).recent
  end

  def new
    @pitch_deck = PitchDeck.new
  end

  def create
    @pitch_deck = PitchDeck.new(pitch_deck_params)
    @pitch_deck.user = current_user
    @pitch_deck.inputs = build_inputs

    if @pitch_deck.save
      charge_credits!
      GeneratePitchDeckJob.perform_later(@pitch_deck.id)
      redirect_to @pitch_deck, notice: "Generating your pitch deck. This takes about 60 seconds..."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @slides = @pitch_deck.ordered_slides
  end

  def edit
    @slide = @pitch_deck.slides.find(params[:slide_id]) if params[:slide_id]
  end

  def update
    if params[:slide_id]
      slide = @pitch_deck.slides.find(params[:slide_id])
      slide.update!(slide_params)
      redirect_to pitch_deck_path(@pitch_deck, slide: slide.slide_type), notice: "Slide updated."
    elsif @pitch_deck.update(pitch_deck_params)
      redirect_to @pitch_deck, notice: "Pitch deck updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def regenerate_slide
    slide_type = params[:slide_type]
    unless PitchDeck::SLIDE_TYPES.include?(slide_type)
      return redirect_to @pitch_deck, alert: "Invalid slide type."
    end

    service = PitchDeckAiService.new(@pitch_deck)
    service.regenerate_slide!(slide_type)
    redirect_to pitch_deck_path(@pitch_deck, slide: slide_type), notice: "Slide regenerated."
  rescue PitchDeckAiService::GenerationError => e
    redirect_to @pitch_deck, alert: "Failed to regenerate: #{e.message}"
  end

  def download
    format = params[:format_type] || "pptx"
    service = PitchDeckExportService.new(@pitch_deck)

    case format
    when "pptx"
      file = service.to_pptx
      send_file file.path,
        filename: "#{@pitch_deck.company_name.parameterize}-pitch-deck.pptx",
        type: "application/vnd.openxmlformats-officedocument.presentationml.presentation"
    else
      redirect_to @pitch_deck, alert: "Unsupported format."
    end
  end

  def destroy
    @pitch_deck.destroy
    redirect_to pitch_decks_path, notice: "Pitch deck deleted."
  end

  private

  def set_pitch_deck
    @pitch_deck = PitchDeck.find(params[:id])
  end

  def pitch_deck_params
    params.require(:pitch_deck).permit(:company_name, :tagline, :industry, :stage, :funding_ask, :template, :color_scheme)
  end

  def slide_params
    params.require(:pitch_deck_slide).permit(:title, :speaker_notes, :visible, content: {})
  end

  def build_inputs
    params.require(:pitch_deck).permit(
      :problem_description, :solution_description, :why_now,
      :target_market, :market_size_estimate, :revenue_model, :pricing,
      :traction, :key_metrics, :milestones,
      :team_members, :competitors, :differentiators,
      :current_revenue, :projected_revenue, :use_of_funds
    ).to_h
  end

  def check_pitch_deck_access!
    return if current_user.has_premium_subscription?
    return if current_user.credits_remaining >= PitchDeck::CREDITS_COST

    redirect_to billing_index_path, alert: "You need #{PitchDeck::CREDITS_COST} credits or a Premium subscription to generate a pitch deck."
  end

  def charge_credits!
    return if current_user.has_premium_subscription?

    PitchDeck::CREDITS_COST.times { current_user.deduct_credit! }
    @pitch_deck.update!(credits_charged: PitchDeck::CREDITS_COST)
  end
end
