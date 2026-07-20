class Trip::ConcealExpiredInStoreJob < ApplicationJob
  queue_as :low_priority

  def perform = Trip.conceal_expired_in_store_now
end
