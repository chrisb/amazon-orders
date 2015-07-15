module Amazon
  class Shipment < ActiveRecord::Base
    self.primary_key = :shipment_id

    has_many :shipment_orders, class_name: 'Amazon::ShipmentOrder'
    has_many :orders, through: :shipment_orders, class_name: 'Amazon::Order'

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
