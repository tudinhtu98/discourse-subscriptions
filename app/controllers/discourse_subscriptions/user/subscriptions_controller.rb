# frozen_string_literal: true

module DiscourseSubscriptions
  module User
    class SubscriptionsController < ::ApplicationController
      include DiscourseSubscriptions::Stripe
      include DiscourseSubscriptions::Group
      before_action :set_api_key
      requires_login

      def index
        begin
          customer = Customer.where(user_id: current_user.id)
          customer_ids = customer.map { |c| c.id } if customer
          subscription_ids = Subscription.where("customer_id in (?)", customer_ids).pluck(:external_id) if customer_ids

          subscriptions = []

          if subscription_ids
            plans = ::Stripe::Price.list(
              expand: ['data.product'],
              limit: 100
            )

            customers = ::Stripe::Customer.list(
              email: current_user.email,
              expand: ['data.subscriptions']
            )

            subscriptions = customers[:data].map do |sub_customer|
              sub_customer[:subscriptions][:data]
            end.flatten(1)

            subscriptions = subscriptions.select { |sub| subscription_ids.include?(sub[:id]) }

            subscriptions.map! do |subscription|
              plan = plans[:data].find { |p| p[:id] == subscription[:items][:data][0][:price][:id] }
              subscription.to_h.except!(:plan)
              subscription.to_h.merge(plan: plan, product: plan[:product].to_h.slice(:id, :name))
            end
          end

          render_json_dump subscriptions

        rescue ::Stripe::InvalidRequestError => e
          render_json_error e.message
        end
      end

      def destroy
        # we cancel but don't remove until the end of the period
        # full removal is done via webhooks
        begin
          subscription = ::Stripe::Subscription.update(params[:id], { cancel_at_period_end: true, })

          if subscription
            render_json_dump subscription
          else
            render_json_error I18n.t('discourse_subscriptions.customer_not_found')
          end

        rescue ::Stripe::InvalidRequestError => e
          render_json_error e.message
        end
      end
    end
  end
end
