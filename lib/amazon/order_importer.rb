module Amazon
  class OrderImporter
    @@css_paths = YAML.load_file('./config/css_paths.yml')['order']
    class << self
      def import(node)
        attrs = {}
        @@css_paths.reject { |k,v| !v }.each_pair { |k,p| attrs[k.to_sym] = node.css(p)[0].content.strip }
        attrs[:total] = currency_to_number(attrs[:total])
        order_id = attrs.delete(:order_id)
        order = Amazon::Order.find_or_initialize_by(order_id: order_id)
        order.update_attributes(attrs)
        order
      end
      def currency_to_number(currency)
        currency.to_s.gsub(/[$,]/,'').to_f
      end
    end
  end
end
