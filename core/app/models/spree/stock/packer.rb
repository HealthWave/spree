module Spree
  module Stock
    class Packer
      attr_reader :stock_location, :order, :splitters

      def initialize(stock_location, order, splitters=[Splitter::Base])
        @stock_location = stock_location
        @order = order
        @splitters = splitters
      end

      def packages
        if splitters.empty?
          [default_package]
        else
          build_splitter.split [default_package]
        end
      end

      def default_package
        package = Package.new(stock_location, order)
        order.line_items.each do |line_item|
          stock_item = stock_location.stock_item(line_item.variant)
          if stock_item && stock_item.should_track_inventory?
            next unless stock_location.stock_item(line_item.variant)

            on_hand, backordered = stock_location.fill_status(line_item.variant, line_item.quantity)
            package.add line_item, on_hand, :on_hand if on_hand > 0
            package.add line_item, backordered, :backordered if backordered > 0
          else
            # TODO - until Distributor is pulled into this fork from hw_admin
            # there is no way to determine the correct course of action IF there was no stock
            # item for the variant. This test passes here but does not work in the new Distributor aware
            # world.
            #
            # To make it actually work for realz is to consult the Distributor's default inventory tracking flag.
            # This is done in the Packer customizations in hw_admin :(
            package.add line_item, line_item.quantity, :on_hand unless Spree::Config.track_inventory_levels
          end
        end
        package
      end

      private
      def build_splitter
        splitter = nil
        splitters.reverse.each do |klass|
          splitter = klass.new(self, splitter)
        end
        splitter
      end
    end
  end
end
