module Amazon
  class ShipmentOrder < ActiveRecord::Base
    belongs_to :shipment, class_name: 'Amazon::Shipment'
    belongs_to :order,    class_name: 'Amazon::Order'
    validates :shipment_id, presence: true
    validates :order_id, presence: true
  end
end
