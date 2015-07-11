module Amazon
  class Order < ActiveRecord::Base
    self.primary_key = :order_id

    has_many :shipments

    # validates :total, presence: true, numericality: { greater_than: 0 }
    validates :amount_paid, numericality: { greater_than_or_equal_to: 0 }

    before_save :set_completion

    def set_completion
      self.completed = shipments.count == shipments.delivered.count
    end

  end
end
