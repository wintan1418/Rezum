class AtsCheckerJob < ApplicationJob
  queue_as :default

  RESULT_TTL = 30.minutes.to_i

  def perform(token, resume_text)
    raw = AtsCheckerService.new.score(resume_text)
    results = AtsScoreParserService.new(raw).parse
    self.class.write_result(token, results)
  rescue StandardError => e
    Rails.logger.error "ATS checker job failed: #{e.message}"
    self.class.write_result(token, { error: "Something went wrong analyzing your resume. Please try again." })
  end

  # Results are shared between web and worker processes via Sidekiq's Redis —
  # the one store both are guaranteed to see in production. When Redis is
  # unreachable (local dev/test without a Redis server), fall back to
  # Rails.cache so the flow still works in-process.
  def self.write_result(token, payload)
    Sidekiq.redis { |r| r.set(redis_key(token), payload.to_json, ex: RESULT_TTL) }
  rescue StandardError => e
    Rails.logger.warn "ATS result store falling back to Rails.cache: #{e.message}"
    Rails.cache.write(redis_key(token), payload.to_json, expires_in: RESULT_TTL)
  end

  def self.read_result(token)
    raw = begin
      Sidekiq.redis { |r| r.get(redis_key(token)) }
    rescue StandardError
      Rails.cache.read(redis_key(token))
    end
    raw && JSON.parse(raw, symbolize_names: true)
  end

  def self.redis_key(token)
    "ats_check:#{token}"
  end
end
