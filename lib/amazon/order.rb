module Amazon
  class Order < ActiveRecord::Base
    self.primary_key = :order_id

    validates :total, presence: true, numericality: true
    validates :delivered, inclusion: { in: [true, false] }
    validates :shipment_status, presence: true
    # validates :ship_to, presence: true
    # validates :shipping_address, presence: true

    before_validation :set_delivered_status

    def set_delivered_status
      self.delivered = shipment_status.downcase.include? 'delivered'
    end

  end
end
