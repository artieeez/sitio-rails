ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    set_fixture_class school_deactivations: School::Deactivation,
                      school_store_concealments: School::StoreConcealment,
                      trip_deactivations: Trip::Deactivation,
                      trip_store_concealments: Trip::StoreConcealment,
                      passenger_removals: Passenger::Removal,
                      passenger_manual_settlements: Passenger::ManualSettlement
  end
end

class ActionDispatch::IntegrationTest
  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }
  end

  def sign_out
    delete session_url
  end
end
