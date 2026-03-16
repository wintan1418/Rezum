class GeneratePitchDeckJob < ApplicationJob
  queue_as :default
  retry_on PitchDeckAiService::GenerationError, wait: 5.seconds, attempts: 2

  def perform(pitch_deck_id)
    pitch_deck = PitchDeck.find(pitch_deck_id)
    return if pitch_deck.completed?

    pitch_deck.mark_generating!

    # Broadcast generating state
    broadcast_status(pitch_deck, "generating")

    service = PitchDeckAiService.new(pitch_deck)
    service.generate_all_slides!

    pitch_deck.mark_completed!
    broadcast_status(pitch_deck, "completed")
  rescue PitchDeckAiService::GenerationError => e
    handle_failure(pitch_deck, e)
    raise if executions < 2
  rescue => e
    handle_failure(pitch_deck, e)
    Rails.logger.error "PitchDeck generation error: #{e.class}: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}"
  end

  private

  def handle_failure(pitch_deck, error)
    pitch_deck.mark_failed!(error.message)

    # Refund credits if charged
    if pitch_deck.credits_charged > 0
      pitch_deck.user.add_credits(pitch_deck.credits_charged)
      pitch_deck.update!(credits_charged: 0)
    end

    broadcast_status(pitch_deck, "failed")
  end

  def broadcast_status(pitch_deck, status)
    Turbo::StreamsChannel.broadcast_replace_to(
      "pitch_deck_#{pitch_deck.id}",
      target: "pitch_deck_status",
      partial: "pitch_decks/status",
      locals: { pitch_deck: pitch_deck, status: status }
    )
  end
end
