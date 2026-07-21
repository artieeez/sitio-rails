require "test_helper"

class Wix::ProcessEventJobTest < ActiveJob::TestCase
  test "perform delegates to event#process_now" do
    event = wix_events(:pending)

    Wix::ProcessEventJob.perform_now(event)

    assert event.reload.processed?
  end

  test "marks the event failed once retries are exhausted" do
    event = wix_events(:pending)
    original_method = Wix::Event.instance_method(:process_now)
    Wix::Event.define_method(:process_now) { raise "boom" }

    perform_enqueued_jobs { Wix::ProcessEventJob.perform_later(event) }

    event.reload
    assert event.failed?
    assert_equal "boom", event.last_error
  ensure
    Wix::Event.define_method(:process_now, original_method)
  end
end
