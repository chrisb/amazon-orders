module Amazon
  class Shipment < ActiveRecord::Base
    belongs_to :order

    validates :order_id, presence: true
    validates :order, presence: true
    validates :delivered, inclusion: { in: [true, false] }
    validates :shipment_status, presence: true
    # validates :ship_to, presence: true
    # validates :shipping_address, presence: true

    scope :delivered, -> { where delivered: true }

    before_validation :set_delivered_status

    def set_delivered_status
      self.delivered = shipment_status.downcase.include?('delivered')
      true
    end

  end
end
