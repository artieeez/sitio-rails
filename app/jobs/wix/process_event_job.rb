class Wix::ProcessEventJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 5 do |job, error|
    job.arguments.first&.mark_failed(error)
  end

  def perform(event) = event.process_now
end
